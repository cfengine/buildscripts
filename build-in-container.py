#!/usr/bin/env python3
"""Container-based CFEngine package builder.

Builds CFEngine packages inside Docker containers using the existing build
scripts. Each build runs in a fresh ephemeral container.
"""

import argparse
import hashlib
import logging
import subprocess
import sys
from pathlib import Path

log = logging.getLogger("build-in-container")

PLATFORMS = {
    "ubuntu-20": {
        "base_image": "ubuntu:20.04",
        "dockerfile": "Dockerfile.debian",
        "extra_build_args": {"NCURSES_PKGS": "libncurses5 libncurses5-dev"},
    },
    "ubuntu-22": {
        "base_image": "ubuntu:22.04",
        "dockerfile": "Dockerfile.debian",
        "extra_build_args": {},
    },
    "ubuntu-24": {
        "base_image": "ubuntu:24.04",
        "dockerfile": "Dockerfile.debian",
        "extra_build_args": {},
    },
    "debian-11": {
        "base_image": "debian:11",
        "dockerfile": "Dockerfile.debian",
        "extra_build_args": {},
    },
    "debian-12": {
        "base_image": "debian:12",
        "dockerfile": "Dockerfile.debian",
        "extra_build_args": {},
    },
}

def detect_source_dir():
    """Find the root directory containing all repos (parent of buildscripts/)."""
    script_dir = Path(__file__).resolve().parent
    # The script lives in buildscripts/, so the source dir is one level up
    source_dir = script_dir.parent
    if not (source_dir / "buildscripts").is_dir():
        log.error(f"Cannot find buildscripts/ in {source_dir}")
        sys.exit(1)
    return source_dir


def dockerfile_hash(dockerfile_path):
    """Compute SHA256 hash of a Dockerfile."""
    return hashlib.sha256(dockerfile_path.read_bytes()).hexdigest()


def image_needs_rebuild(image_tag, current_hash):
    """Check if the Docker image needs rebuilding based on Dockerfile hash."""
    result = subprocess.run(
        [
            "docker",
            "inspect",
            "--format",
            '{{index .Config.Labels "dockerfile-hash"}}',
            image_tag,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return True  # Image doesn't exist
    stored_hash = result.stdout.strip()
    return stored_hash != current_hash


def build_image(platform_name, platform_config, script_dir, rebuild=False):
    """Build the Docker image for the given platform."""
    image_tag = f"cfengine-builder-{platform_name}"
    dockerfile_name = platform_config["dockerfile"]
    dockerfile_path = script_dir / "container" / dockerfile_name
    current_hash = dockerfile_hash(dockerfile_path)

    if not rebuild and not image_needs_rebuild(image_tag, current_hash):
        log.info(f"Docker image {image_tag} is up to date.")
        return image_tag

    log.info(f"Building Docker image {image_tag}...")
    cmd = [
        "docker",
        "build",
        "-f",
        str(dockerfile_path),
        "--build-arg",
        f"BASE_IMAGE={platform_config['base_image']}",
        "--label",
        f"dockerfile-hash={current_hash}",
        "-t",
        image_tag,
    ]

    for key, value in platform_config.get("extra_build_args", {}).items():
        cmd.extend(["--build-arg", f"{key}={value}"])

    if rebuild:
        cmd.append("--no-cache")

    cmd.extend(["--network", "host"])

    # Build context is the container/ directory
    cmd.append(str(script_dir / "container"))

    result = subprocess.run(cmd)
    if result.returncode != 0:
        log.error("Docker image build failed.")
        sys.exit(1)

    return image_tag


def run_container(args, image_tag, source_dir, script_dir):
    """Run the build inside a Docker container."""
    output_dir = Path(args.output_dir).resolve()
    cache_dir = Path(args.cache_dir).resolve()

    # Pre-create host directories so Docker doesn't create them as root
    output_dir.mkdir(parents=True, exist_ok=True)
    cache_dir.mkdir(parents=True, exist_ok=True)

    cmd = ["docker", "run", "--rm", "--network", "host"]

    if args.shell:
        cmd.extend(["-it"])

    # Mounts
    cmd.extend(
        [
            "-v",
            f"{source_dir}:/srv/source:ro",
            "-v",
            f"{cache_dir}:/home/builder/.cache/buildscripts_cache",
            "-v",
            f"{output_dir}:/output",
        ]
    )

    # Environment variables
    # JOB_BASE_NAME is used by deps-packaging/pkg-cache to derive the cache
    # label. Format: "label=<value>". Without it, all platforms share NO_LABEL.
    cache_label = f"label=container_{args.platform}"
    cmd.extend(
        [
            "-e",
            f"PROJECT={args.project}",
            "-e",
            f"BUILD_TYPE={args.build_type}",
            "-e",
            f"EXPLICIT_ROLE={args.role}",
            "-e",
            f"BUILD_NUMBER={args.build_number}",
            "-e",
            f"JOB_BASE_NAME={cache_label}",
            "-e",
            "CACHE_IS_ONLY_LOCAL=yes",
        ]
    )

    if args.version:
        cmd.extend(["-e", f"EXPLICIT_VERSION={args.version}"])

    cmd.append(image_tag)

    if args.shell:
        cmd.append("/bin/bash")
    else:
        cmd.append(str(Path("/srv/source/buildscripts/build-in-container-inner.sh")))

    result = subprocess.run(cmd)
    return result.returncode


# Custom action so --list-platforms can exit early without triggering
# argparse's required-argument validation (same mechanism as --help).
class ListPlatformsAction(argparse.Action):

    def __call__(self, parser, namespace, values, option_string=None):
        print("Available platforms:")
        for name, config in PLATFORMS.items():
            print(f"  {name:15s}  ({config['base_image']})")
        parser.exit()


def main():
    parser = argparse.ArgumentParser(
        description="Build CFEngine packages in Docker containers."
    )
    parser.add_argument(
        "--platform",
        required=True,
        choices=list(PLATFORMS.keys()),
        help="Target platform",
    )
    parser.add_argument(
        "--project",
        required=True,
        choices=["community", "nova"],
        help="CFEngine edition",
    )
    parser.add_argument(
        "--role",
        required=True,
        choices=["agent", "hub"],
        help="Component to build",
    )
    parser.add_argument(
        "--build-type",
        dest="build_type",
        required=True,
        choices=["DEBUG", "RELEASE"],
        help="Build type",
    )
    parser.add_argument(
        "--source-dir",
        help="Root directory containing repos (default: parent of buildscripts/)",
    )
    parser.add_argument(
        "--output-dir",
        default="./output",
        help="Output directory for packages (default: ./output)",
    )
    parser.add_argument(
        "--cache-dir",
        default=str(Path.home() / ".cache" / "cfengine" / "buildscripts"),
        help="Dependency cache directory",
    )
    parser.add_argument(
        "--rebuild-image",
        action="store_true",
        help="Force rebuild of Docker image (--no-cache)",
    )
    parser.add_argument(
        "--shell",
        action="store_true",
        help="Drop into container shell for debugging",
    )
    parser.add_argument(
        "--list-platforms",
        action=ListPlatformsAction,
        nargs=0,
        help="List available platforms and exit",
    )
    parser.add_argument(
        "--build-number",
        default="1",
        help="Build number for package versioning (default: 1)",
    )
    parser.add_argument(
        "--version",
        help="Override version string",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
    )

    # Detect source directory
    if args.source_dir:
        source_dir = Path(args.source_dir).resolve()
    else:
        source_dir = detect_source_dir()

    script_dir = source_dir / "buildscripts"

    if args.platform not in PLATFORMS:
        log.error(f"Unknown platform '{args.platform}'")
        sys.exit(1)

    platform_config = PLATFORMS[args.platform]

    # Build Docker image
    image_tag = build_image(
        args.platform, platform_config, script_dir, rebuild=args.rebuild_image
    )

    if not args.shell:
        log.info(
            f"Building {args.project} {args.role} for {args.platform} ({args.build_type})..."
        )

    # Run the container
    rc = run_container(args, image_tag, source_dir, script_dir)

    if rc != 0:
        log.error(f"Build failed (exit code {rc}).")
        sys.exit(rc)

    if not args.shell:
        output_dir = Path(args.output_dir).resolve()
        packages = (
            list(output_dir.glob("*.deb"))
            + list(output_dir.glob("*.rpm"))
            + list(output_dir.glob("*.pkg.tar.gz"))
        )
        if packages:
            log.info("Output packages:")
            for p in sorted(packages):
                log.info(f"  {p}")
        else:
            log.warning("No packages found in output directory.")


if __name__ == "__main__":
    main()
