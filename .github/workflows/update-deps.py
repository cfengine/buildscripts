import os
import re
import time
import json
import hashlib
import argparse
import requests
import urllib.request
import logging as log
from itertools import batched
import subprocess

DEPS_PACKAGING = "deps-packaging"


def run_command(cmd: list):
    try:
        log.debug(f"Running command '{" ".join(cmd)}'")
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError:
        log.error(f"Command '{" ".join(cmd)}' failed")
        return False
    return True


def git_commit(root, msg):
    return run_command(["git", "-C", root, "add", "-u"]) and run_command(
        [
            "git",
            "-C",
            root,
            "commit",
            f"--message={msg}",
        ],
    )


def parse_args():
    parser = argparse.ArgumentParser(description="CFEngine dependency updater")
    parser.add_argument(
        "--debug",
        action="store_true",
        help="enable debug log messages",
    )
    parser.add_argument(
        "--bump",
        default="minor",
        choices=["major", "minor", "patch"],
        help="whether to bump version major, minor or patch",
    )
    parser.add_argument(
        "--skip",
        nargs=2,
        action="extend",
        default=[],
        metavar=("PACKAGE", "VERSION"),
        help="skip updates for specific version of a package (e.g., --skip librsync 2.3.4)",
    )
    parser.add_argument(
        "--root", default=".", help="specify build scripts root directory"
    )

    return parser.parse_args()


def determine_old_version(root, pkg_name):
    distfile = os.path.join(root, DEPS_PACKAGING, pkg_name, "distfiles")
    with open(distfile, "r") as f:
        data = f.read().strip().split()
    filename = data[-1]

    match = re.search(
        r"[\-_]([0-9]+[\.\-][0-9]+([\.\-][0-9]+)?)(\.tar|\.tgz|-rel|-src)", filename
    )
    if match:
        version = match.group(1)
        log.debug(f"Extracted version number '{version}' from '{filename}'")
        return version

    log.error(f"Failed to extract version number from '{filename}'")
    return None


def get_available_versions(proj_id):
    url = f"https://release-monitoring.org/api/v2/versions/?project_id={proj_id}"

    versions_cache = "/tmp/update-deps-cache.json"
    if os.path.exists(versions_cache):
        with open(versions_cache, "r") as f:
            cache = json.load(f)
    else:
        cache = {}

    now = time.time()
    one_hour = 3600
    if (url in cache) and (cache[url]["timestamp"] + one_hour) > now:
        log.debug(f"Retrieving '{url}' from cache '{versions_cache}'")
        return cache[url]["response"]

    data = requests.get(url).json()
    versions = list(
        filter(
            lambda x: re.fullmatch(r"[0-9]+[\.\-_][0-9]+([\.\-_][0-9]+)?", x),
            data["stable_versions"],
        )
    )

    cache[url] = {}
    cache[url]["response"] = versions
    cache[url]["timestamp"] = now

    log.debug(f"Updating cache '{versions_cache}' with response from '{url}'")
    with open(versions_cache, "w") as f:
        json.dump(cache, f, indent=2)

    return versions


def select_new_version(
    package_name,
    bump_version,
    skip_versions,
    old_version,
    available_versions,
):
    assert len(skip_versions) % 2 == 0  # Is guaranteed by the argument parser

    old_split = old_version.replace("-", ".").replace("_", ".").split(".")
    for new_version in available_versions:
        new_split = new_version.replace("-", ".").replace("_", ".").split(".")

        do_skip = False
        for skip_package, skip_version in batched(skip_versions, 2):
            skip_split = skip_version.replace("-", ".").replace("_", ".").split(".")
            if (skip_package == package_name) and (skip_split == new_split):
                do_skip = True
        if do_skip:
            log.info(f"Skipping version {new_version} for package {package_name}")
            continue

        if package_name == "php" and bump_version == "minor":
            """For php, a bump in what is normally considered the minor version,
            can contain breaking changes. So for minor package updates, we will
            only bump the last number."""
            bump_version = "patch"

        if bump_version == "major":
            return new_version
        if bump_version == "minor" and old_split[:1] == new_split[:1]:
            return new_version
        if bump_version == "patch" and old_split[:2] == new_split[:2]:
            return new_version
    return None  # Didn't find a suitable version


def replace_string_in_file(filename, old, new):
    if not os.path.exists(filename):
        return

    with open(filename, "r") as f:
        contents = f.read()

    if old not in contents:
        """This handles an exception for libexpat, where the version number is a
        part of the contents of the source file, but the version number is
        separated by underscores. We don't explicitly test that we are currently
        working with the package libexpat and the source file, because this may
        be the case for other packages as well in the future."""
        old = old.replace(".", "_")
        new = new.replace(".", "_")

    with open(filename, "w") as f:
        f.write(contents.replace(old, new))


def update_version_numbers(root, pkg_name, old_version, new_version):
    filenames = [
        os.path.join(root, DEPS_PACKAGING, pkg_name, f"cfbuild-{pkg_name}.spec"),
        os.path.join(root, DEPS_PACKAGING, pkg_name, f"cfbuild-{pkg_name}-aix.spec"),
        os.path.join(root, DEPS_PACKAGING, pkg_name, "distfiles"),
        os.path.join(root, DEPS_PACKAGING, pkg_name, "source"),
    ]
    for filename in filenames:
        if filename.endswith(os.path.join("libxml2", "source")):
            # Special case for libxml2: The patch number is left out from the
            # URL of the source file
            old_version = ".".join(old_version.split(".")[:-1])
            new_version = ".".join(new_version.split(".")[:-1])
        log.debug(f"Replacing '{old_version}' with '{new_version}' in '{filename}'")
        replace_string_in_file(filename, old_version, new_version)


def update_distfiles_digest(root, pkg_name):
    with open(os.path.join(root, DEPS_PACKAGING, pkg_name, "source"), "r") as f:
        source = f.read().strip()

    filename = os.path.join(root, DEPS_PACKAGING, pkg_name, "distfiles")
    with open(filename, "r") as f:
        content = f.read().strip().split()
    old_digest = content[0]
    tarball = content[-1]

    if not os.path.exists(os.path.join("/tmp", tarball)):
        url = f"{source}/{tarball}"
        urllib.request.urlretrieve(url, os.path.join("/tmp", tarball))

    sha = hashlib.sha256()
    with open(os.path.join("/tmp", tarball), "rb") as f:
        sha.update(f.read())
    new_digest = sha.digest().hex()

    replace_string_in_file(filename, old_digest, new_digest)


def update_deps(root, bump, skip):
    with open(os.path.join(root, DEPS_PACKAGING, "release-monitoring.json"), "r") as f:
        release_monitoring = json.load(f)

    for pkg_name, proj_id in release_monitoring.items():
        old_version = determine_old_version(root, pkg_name)
        if not old_version:
            log.error(f"Failed to determine old version of package {pkg_name}")
            exit(1)

        available_versions = get_available_versions(proj_id)
        new_version = select_new_version(
            pkg_name, bump, skip, old_version, available_versions
        )
        if not new_version:
            log.error(f"Could not find a suitable new version for package {pkg_name}")
            exit(1)

        if pkg_name == "openldap":
            """Special case for openldap: release-monitoring takes version
            number from git repo, which uses underscores as separators, but
            later we download a file with dots as separators."""
            new_version = new_version.replace("_", ".")

        if old_version == new_version:
            log.debug(
                f"Package {pkg_name} is already the newest version ({old_version} == {new_version})"
            )
            continue
        log.info(f"Updating {pkg_name} from version {old_version} to {new_version}...")

        update_version_numbers(root, pkg_name, old_version, new_version)
        update_distfiles_digest(root, pkg_name)

        if not git_commit(
            root,
            f"Updated dependency '{pkg_name}' from version {old_version} to {new_version}",
        ):
            log.error(f"Failed to commit changes after updating package '{pkg_name}'")
            exit(1)


def main():
    args = parse_args()
    loglevel = "DEBUG" if args.debug else "INFO"
    log.basicConfig(
        format="[%(filename)s:%(lineno)d][%(levelname)s]: %(message)s", level=loglevel
    )

    update_deps(args.root, args.bump, args.skip)


if __name__ == "__main__":
    main()
