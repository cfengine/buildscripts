import os
import re
import time
import json
import hashlib
import argparse
import requests
import urllib.request
import logging as log

DEPS_PACKAGING = "deps-packaging"


def parse_args():
    parser = argparse.ArgumentParser(description="CFEngine dependency updater")
    parser.add_argument(
        "--debug",
        action="store_true",
        help="enable debug log messages",
    )
    parser.add_argument(
        "--update",
        default="minor",
        choices=["major", "minor", "patch"],
        help="whether to do major, minor or patch updates",
    )
    return parser.parse_args()


def determine_old_version(pkg_name):
    distfile = os.path.join(DEPS_PACKAGING, pkg_name, "distfiles")
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
    update_type,
    old_version,
    available_versions,
):
    old_split = old_version.replace("-", ".").replace("_", ".").split(".")
    for new_version in available_versions:
        new_split = new_version.replace("-", ".").replace("_", ".").split(".")
        if update_type == "major":
            return new_version
        if update_type == "minor" and old_split[:1] == new_split[:1]:
            return new_version
        if update_type == "patch" and old_split[:2] == new_split[:2]:
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


def update_version_numbers(pkg_name, old_version, new_version):
    filenames = [
        os.path.join(DEPS_PACKAGING, pkg_name, f"cfbuild-{pkg_name}.spec"),
        os.path.join(DEPS_PACKAGING, pkg_name, f"cfbuild-{pkg_name}-aix.spec"),
        os.path.join(DEPS_PACKAGING, pkg_name, "distfiles"),
        os.path.join(DEPS_PACKAGING, pkg_name, "source"),
    ]
    for filename in filenames:
        replace_string_in_file(filename, old_version, new_version)


def update_distfiles_digest(pkg_name):
    with open(os.path.join(DEPS_PACKAGING, pkg_name, "source"), "r") as f:
        source = f.read().strip()

    filename = os.path.join(DEPS_PACKAGING, pkg_name, "distfiles")
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


def main():
    args = parse_args()
    loglevel = "DEBUG" if args.debug else "INFO"
    log.basicConfig(
        format="[%(filename)s:%(lineno)d][%(levelname)s]: %(message)s", level=loglevel
    )

    with open(os.path.join(DEPS_PACKAGING, "release-monitoring.json"), "r") as f:
        release_monitoring = json.load(f)

    commit_message = ["Updated dependencies\n\n"]
    for pkg_name, proj_id in release_monitoring.items():
        old_version = determine_old_version(pkg_name)
        if not old_version:
            log.error(f"Failed to determine old version of package {pkg_name}")
            exit(1)

        available_versions = get_available_versions(proj_id)
        new_version = select_new_version(args.update, old_version, available_versions)
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

        update_version_numbers(pkg_name, old_version, new_version)
        update_distfiles_digest(pkg_name)

        commit_message.append(f"- Updated dependency '{pkg_name}' from version {old_version} to {new_version}\n")

    with open("/tmp/commit-message.txt", "w") as f:
        f.writelines(commit_message)

if __name__ == "__main__":
    main()
