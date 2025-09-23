import argparse
import collections
import json
import logging as log
import os
import re
import subprocess
import sys

ACTIVE_BRANCHES = ["3.21.x", "3.24.x", "master"]

HUMAN_NAME = {
    "diffutils": "diffutils",
    "libacl": "libacl",
    "libattr": "libattr",
    "libcurl": "libcurl",
    "libgnurx": "libgnurx",
    "libiconv": "libiconv",
    "libxml2": "libxml2",
    "libyaml": "LibYAML",
    "lmdb": "LMDB",
    "openldap": "OpenLDAP",
    "openssl": "OpenSSL",
    "pcre": "PCRE",
    "pcre2": "PCRE2",
    "pthreads-w32": "pthreads-w32",
    "sasl2": "SASL2",
    "zlib": "zlib",
    "librsync": "librsync",
    "leech": "leech",
    "apache": "Apache",
    "apr": "APR",
    "apr-util": "apr-util",
    "git": "Git",
    "libexpat": "libexpat",
    "php": "PHP",
    "postgresql": "PostgreSQL",
    "nghttp2": "nghttp2",
    "rsync": "rsync",
    "lcov": "LCOV",
    "libcurl-hub": "libcurl-hub",
}
HOME_URL = {
    "diffutils": "https://ftpmirror.gnu.org/diffutils/",
    "libacl": "https://download.savannah.gnu.org/releases/acl/",
    "libattr": "https://download.savannah.gnu.org/releases/attr",
    "libcurl": "https://curl.se/download.html",
    "libgnurx": "https://www.gnu.org/software/rx/rx.html",
    "libiconv": "https://ftp.gnu.org/gnu/libiconv/",
    "libxml2": "https://gitlab.gnome.org/GNOME/libxml2",
    "libyaml": "https://pyyaml.org/wiki/LibYAML",
    "lmdb": "https://github.com/LMDB/lmdb/",
    "openldap": "https://www.openldap.org/software/download/OpenLDAP/openldap-release/",
    "openssl": "https://openssl.org/",
    "pcre": "https://www.pcre.org/",
    "pcre2": "https://github.com/PCRE2Project/pcre2/releases/",
    "pthreads-w32": "https://sourceware.org/pub/pthreads-win32/",
    "sasl2": "https://www.cyrusimap.org/sasl/",
    "zlib": "https://www.zlib.net/",
    "librsync": "https://github.com/librsync/librsync/releases",
    "leech": "https://github.com/larsewi/leech/releases",
    "apache": "https://httpd.apache.org/",
    "apr": "https://apr.apache.org/",
    "apr-util": "https://apr.apache.org/",
    "git": "https://www.kernel.org/pub/software/scm/git/",
    "libexpat": "https://libexpat.github.io/",
    "php": "https://php.net/",
    "postgresql": "https://www.postgresql.org/",
    "nghttp2": "https://nghttp2.org/",
    "rsync": "https://download.samba.org/pub/rsync/",
    "lcov": "https://github.com/linux-test-project/lcov/",
    "libcurl-hub": "https://curl.se/download.html",
}


def write_json_file(filepath, data):
    with open(filepath, "w") as file:
        json.dump(data, file)


def is_whitespace(s: str):
    """Returns whether `s` contains only whitespace (`True` also for the empty string)"""
    return len(s) == 0 or s.isspace()


class GitRepo:
    """Class responsible for working with locally checked-out repository"""

    def __init__(
        self,
        repo_path,
        repo_owner,
        repo_name,
        checkout_ref=None,
        log_info=True,
    ):
        """
        Creates an instance of the class for a Git repository in a given path, cloning from GitHub if the path doesn't exist, then configures it and optionally checks out a requested ref (branch or tag). Arguments:
        * `repo_path`: local filesystem path of the Git repository, or of the GitHub repository to clone
        * `repo_owner`: name of owner of the GitHub repository to clone
        * `repo_name`: name of GitHub repository to clone
        * `checkout_ref`: optional name of ref to checkout. If not provided, a ref from previous work might be left checked out.
        """
        self.repo_path = repo_path

        repo_url = "https://github.com/{}/{}.git".format(repo_owner, repo_name)

        # set up a logger to intercept command output to logging.INFO instead of displaying it
        if log_info:
            LOGGING_LEVEL = log.INFO
        else:
            LOGGING_LEVEL = log.WARNING
        self.run_logger = log.getLogger("output_run_to_logging")
        # do not duplicate logs with the root logger:
        self.run_logger.propagate = False
        self.run_logger.setLevel(LOGGING_LEVEL)
        handler = log.StreamHandler()
        # do not terminate logs with a newline, as the output already has newlines:
        handler.terminator = ""
        handler.setLevel(LOGGING_LEVEL)
        log_format = log.Formatter("%(asctime)s %(levelname)s: %(message)s")
        handler.setFormatter(log_format)
        self.run_logger.addHandler(handler)

        if not os.path.exists(repo_path):
            self.run_command("clone", "--no-checkout", repo_url, repo_path)
        if checkout_ref is not None:
            self.checkout(checkout_ref)

    def run_command(self, *command, **kwargs):
        """Runs a git command in the Git repository. Syntactically this function tries to be as close to `subprocess.run` as possible, just adding `"git"` with some extra parameters at the beginning."""
        git_command = [
            "git",
            "-C",
            self.repo_path,
            "-c",
            "advice.detachedHead=false",
        ]
        git_command.extend(command)
        if "check" not in kwargs:
            kwargs["check"] = True
        if "capture_output" in kwargs:
            kwargs["stdout"] = subprocess.PIPE
            kwargs["stderr"] = subprocess.PIPE
            del kwargs["capture_output"]
        if command[0] == "clone":
            # we can't `cd` to target folder when it does not exist yet,
            # so delete `-C self.repo_path` arguments from git command line
            del git_command[1]
            del git_command[1]
        kwargs["universal_newlines"] = True
        log.debug("running command: {}".format(" ".join(git_command)))

        # run the command, passing the output to logging.INFO instead of displaying
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        result = subprocess.run(git_command, **kwargs)
        if not is_whitespace(result.stdout):
            self.run_logger.info(result.stdout)
        if not is_whitespace(result.stderr):
            self.run_logger.info(result.stderr)

        return result

    def checkout(self, ref, remote="origin", new=False):
        """Checkout given ref (branch or tag), optionally creating the ref as a branch.
        Note that it's an error to create-and-checkout branch which already exists.
        """
        if new:
            # create new branch
            self.run_command("checkout", "-b", ref)
        else:
            # first, ensure that we're aware of target ref
            self.run_command("fetch", remote, ref)
            # switch to the ref
            self.run_command("checkout", ref)
            # ensure we're on the tip of ref
            self.run_command("reset", "--hard", "FETCH_HEAD")
        self.run_command("submodule", "update", "--init")

    def get_file(self, relpath):
        """Returns contents of a file as a single string"""
        path = os.path.join(self.repo_path, relpath)
        with open(path) as f:
            return f.read()

    def put_file(self, relpath, data, add=True):
        """Overwrites file with data, optionally running `git add {relpath}` afterwards"""
        path = os.path.join(self.repo_path, relpath)
        with open(path, "w") as f:
            f.write(data)
        if add:
            self.run_command("add", relpath)

    def commit(self, message):
        """Creates commit with message, if there are changes."""
        status_result = self.run_command("status", "--porcelain")
        is_empty = is_whitespace(status_result.stdout)
        if not is_empty:
            self.run_command("commit", "-m", message)

    def is_git_branch(self, ref):
        """Returns whether `ref` is an existing branch in the Git repository."""
        try:
            self.run_command("show-ref", "--verify", "refs/heads/" + ref)
        except subprocess.CalledProcessError:
            return False
        return True


def pretty(data):
    return json.dumps(data, indent=2)


class DepsReader:
    """
    Currently it's working only with cfengine/buildscripts repo, as described at
    https://github.com/mendersoftware/infra/blob/master/files/buildcache/release-scripts/RELEASE_PROCESS.org#minor-dependencies-update
    """

    def __init__(self, repo_path=None, log_info=True):
        # prepare repo
        REPO_OWNER = "cfengine"
        REPO_NAME = "buildscripts"
        if repo_path is None:
            repo_path = "."
        self.buildscripts_repo = GitRepo(
            repo_path,
            REPO_OWNER,
            REPO_NAME,
            "master",
            log_info=log_info,
        )

    def deps_list(self, ref="master"):
        """Returns a sorted list of dependencies for given ref, for example: `["lcov", "libgnurx", "pthreads-w32"]`.
        Assumes the proper ref is checked out by `self.buildscripts_repo`.
        """
        # TODO: get value of $EMBEDDED_DB from file
        embedded_db = "lmdb"
        if ref == "3.7.x":
            options_file = self.buildscripts_repo.get_file(
                "build-scripts/install-dependencies"
            )
        else:
            options_file = self.buildscripts_repo.get_file(
                "build-scripts/compile-options"
            )
        options_lines = options_file.splitlines()
        if ref == "3.7.x":
            filtered_lines = (
                x for x in options_lines if re.match(r'\s*DEPS=".*\$DEPS', x)
            )
            only_deps = (re.sub("\\$?DEPS", "", x) for x in filtered_lines)
            only_deps = (re.sub('[=";]', "", x) for x in only_deps)
            only_deps = (x.strip() for x in only_deps)
        else:
            filtered_lines = (x for x in options_lines if "var_append DEPS" in x)
            only_deps = (re.sub('.*DEPS "(.*)".*', "\\1", x) for x in filtered_lines)
        # currently only_deps is generator of space-separated deps,
        # i.e. each item can contain several items, like this:
        # list(only_deps) = ["lcov", "pthreads-w32 libgnurx"]
        # to "flattern" it we first join using spaces and then split on spaces
        # in the middle we also do some clean-ups
        only_deps = (
            " ".join(only_deps)
            .replace("$EMBEDDED_DB", embedded_db)
            .replace("libgcc ", "")
            .split(" ")
        )
        # now only_deps looks like this: ["lcov", "pthreads-w32", "libgnurx"]
        log.debug(pretty(only_deps))
        only_deps = sorted(only_deps)
        return only_deps

    def extract_version_from_filename(self, dep, filename):
        if dep == "openssl":
            # On different branches we use openssl from different sources
            # (this will be cleaned up soon). When downloading from GitHub,
            # filename is OpenSSL_1_1_1.tar.gz, where 1_1_1 is version.
            # When downloading from openssl website, filename for same version
            # is openssl-1.1.1.tar.gz, and version is 1.1.1.
            # We first check for website-style version, and if it doesn't match
            # then we fallback to github-style version. If neither version is
            # found - match.group(1) will raise an exception.
            match = re.search("-([0-9a-z.]*).tar", filename)
            if not match:
                match = re.search("_([0-9a-z_]*).tar", filename)
            version = match.group(1)
        elif dep == "pthreads-w32":
            version = re.search("w32-([0-9-]*)-rel", filename).group(1)
        else:
            version = re.search(r"[-_]([0-9.]*)[\.-]", filename).group(1)
        return version

    def get_current_version(self, dep):
        """Returns the current version of dependency `dep`."""
        dist_file_path = "deps-packaging/{}/distfiles".format(dep)
        dist_file = self.buildscripts_repo.get_file(dist_file_path)
        dist_file = dist_file.strip()
        old_filename = re.sub(".* ", "", dist_file)
        old_version = self.extract_version_from_filename(dep, old_filename)
        return old_version

    def deps_versions(self, ref):
        """Returns a dictionary of dependencies and versions for a ref:
        ```
        {
            "dep1": "version",
            "dep2": "version",
            ...
        }
        ```
        The ref is checked out during the execution of this function.
        """
        self.buildscripts_repo.checkout(ref)
        # also support checking out refs that are not necessarily branches, such as tags
        if self.buildscripts_repo.is_git_branch(ref):
            self.buildscripts_repo.run_command("pull")

        deps_versions = {}
        deps_list = self.deps_list(ref)
        for dep in deps_list:
            deps_versions[dep] = self.get_current_version(dep)
        return deps_versions

    def deps_dict(self, refs):
        """Returns a 2D dictionary of dependencies and versions from all refs: `deps_dict[dep][ref] = version`, as well as a dictionary of widths of each column (ref)."""

        deps_dict = {}
        ref_column_widths = {}

        for ref in refs:
            ref_column_widths[ref] = len(ref)
            deps_versions = self.deps_versions(ref)

            for dep in deps_versions:
                if not dep in deps_dict:
                    deps_dict[dep] = collections.defaultdict(lambda: "-")
                deps_dict[dep][ref] = deps_versions[dep]
                ref_column_widths[ref] = max(
                    ref_column_widths[ref], len(deps_versions[dep])
                )

        return deps_dict, ref_column_widths

    def updated_deps_markdown_table(self, refs):
        """Code from bot-tom's `depstable` that processes the README table directly, returning the updated README. The updated README will not contain dependencies that were not in the README beforehand, and will not automatically remove dependencies that no longer exist."""
        updated_hub_table_lines = []
        updated_agent_table_lines = []

        deps_dict, ref_column_widths = self.deps_dict(refs)

        self.buildscripts_repo.checkout("master")
        readme_file = self.buildscripts_repo.get_file("README.md")
        readme_lines = readme_file.split("\n")
        has_notes = False  # flag to say that we're in a table that has "Notes" column
        in_hub = False  # flag that we're in Hub section
        for i, line in enumerate(readme_lines):
            if " Hub " in line:
                in_hub = True
            if not line.startswith("| "):
                continue
            if line.startswith("| CFEngine version "):
                has_notes = "Notes" in line
                # Desired output row: ['CFEngine version', refs..., 'Notes']
                # Also note that list addition is concatenation: [1] + [2] == [1, 2]
                row = (
                    ["CFEngine version"]
                    + [ref for ref in refs]
                    + (["Notes"] if has_notes else [])
                )
                # Width of source columns
                column_widths = [len(x) for x in line.split("|")]
                # Note that first and last column widths are zero, since line
                # begins and ends with '|'. We're actually interested in widths
                # of first column (with words "CFEngine version" in it) and,
                # possibly, last ("Notes", which is now second-to-last).
                # Between them are ref column widths, calculated earlier.
                # Also we substract 2 to remove column "padding".
                column_widths = (
                    [column_widths[1] - 2]
                    + [ref_column_widths[ref] for ref in refs]  # "CFEngine version"
                    + (
                        [column_widths[-2] - 2] if has_notes else []
                    )  # "Notes", if exists
                )
                line = (
                    "| "
                    + (
                        " | ".join(
                            (val.ljust(width) for val, width in zip(row, column_widths))
                        )
                    )
                    + " |"
                )
            elif line.startswith("| :-"):
                line = (
                    "| "
                    + (" | ".join((":" + "-" * (width - 1) for width in column_widths)))
                    + " |"
                )
            else:
                # Sample line:
                # | [PHP](http://php.net/) ...
                # For it, in regexp below,
                # \[([a-z0-9-]*)\] will match [PHP]
                # \((.*?)\) will match (http://php.net/)
                match = re.match(
                    r"\| \[([a-z0-9-]*)\]\((.*?)\) ", line, flags=re.IGNORECASE
                )
                if match:
                    dep_title = match.group(1)
                    dep = dep_title.lower()
                    url = match.group(2)
                else:
                    log.warning("didn't find dep in line [%s]", line)
                    continue
                if dep not in deps_dict:
                    log.warning(
                        "unknown dependency in README: [%s] line [%s], will be EMPTY",
                        dep,
                        line,
                    )
                    deps_dict[dep] = collections.defaultdict(lambda: "-")
                if has_notes:
                    note = re.search(r"\| ([^|]*) \|$", line)
                    if not note:
                        log.warning("didn't find note in line [%s]", line)
                        note = ""
                    else:
                        note = note.group(1)
                if in_hub:
                    dep = re.sub("-hub$", "", dep)
                row = (
                    ["[%s](%s)" % (dep_title, url)]
                    + [deps_dict[dep][ref] for ref in refs]
                    + ([note] if has_notes else [])
                )
                line = (
                    "| "
                    + (
                        " | ".join(
                            (val.ljust(width) for val, width in zip(row, column_widths))
                        )
                    )
                    + " |"
                )
            readme_lines[i] = line
            if in_hub:
                updated_hub_table_lines.append(line)
            else:
                updated_agent_table_lines.append(line)

        updated_readme = "\n".join(readme_lines)
        updated_hub_table = "\n".join(updated_hub_table_lines)
        updated_agent_table = "\n".join(updated_agent_table_lines)

        return updated_readme, updated_agent_table, updated_hub_table

    def patch_readme(self, updated_readme):
        TARGET_README_PATH = "README.md"
        self.buildscripts_repo.put_file(TARGET_README_PATH, updated_readme)
        self.buildscripts_repo.commit("Update dependencies tables")

    def write_deps_json(self, json_path, refs):
        deps_data, _ = self.deps_dict(refs)
        write_json_file(json_path, deps_data)

    def write_cdx_sboms(self, cdx_sbom_path_template, refs, fake_rpm=True):
        for ref in refs:
            cdx_dict = collections.OrderedDict()
            cdx_dict["bomFormat"] = "CycloneDX"
            cdx_dict["specVersion"] = "1.6"

            metadata_dict = collections.OrderedDict()
            application_bomref = "northerntech:cfengine"
            metadata_dict["component"] = {
                "type": "application",
                "bom-ref": application_bomref,
                "name": "CFEngine",
                "version": ref,
            }
            cdx_dict["metadata"] = metadata_dict

            components = []
            deps_bomrefs = []
            deps_versions = self.deps_versions(ref)
            for dep_name, dep_version in deps_versions.items():
                c_bomref = f"northerntech:{dep_name}"
                component = {
                    "type": "library",
                    "bom-ref": c_bomref,
                    "name": dep_name,
                    "version": dep_version,
                }
                purl = "pkg:rpm/" + dep_name + "@" + dep_version
                if fake_rpm:
                    component["purl"] = purl
                components.append(component)
                deps_bomrefs.append(c_bomref)

            cdx_dict["components"] = components

            dependencies = [{"ref": application_bomref, "dependsOn": deps_bomrefs}]
            cdx_dict["dependencies"] = dependencies

            if "{}" in cdx_sbom_path_template:
                cdx_sbom_path = cdx_sbom_path_template.replace("{}", ref)
            else:
                log.warning(
                    "Substring {} not found in the CycloneDX SBOM path template, continuing using paths which might be unexpected"
                )
                if len(refs) == 1:
                    cdx_sbom_path = cdx_sbom_path_template
                else:
                    cdx_sbom_path = (
                        cdx_sbom_path_template[:-9] + "-" + ref + ".cdx.json"
                    )
            write_json_file(cdx_sbom_path, cdx_dict)

    def comparison_md_table(self, refs, skip_unchanged=False):
        """Column headers of B refs are always bolded. Row headers are never bolded."""
        deps_data, _ = self.deps_dict(refs)

        # all dependencies, sorted by ref-existence, then name, in Python 3.7+
        all_deps = deps_data.keys()

        compared_deps_data = collections.OrderedDict()

        for dep in all_deps:
            c_dep_data = collections.OrderedDict()
            bolded_in_row = 0

            # iterate over refs in non-overlapping pairs, and skipping the last odd ref
            for ref_A, ref_B in list(zip(refs, refs[1:]))[::2]:
                version_A = deps_data[dep][ref_A]
                version_B = deps_data[dep][ref_B]

                ref_B_bolded = "**" + ref_B + "**"
                c_dep_data[ref_A] = version_A
                c_dep_data[ref_B_bolded] = version_B

                if version_A != version_B:
                    bolded_in_row += 1
                    c_dep_data[ref_B_bolded] = "**" + version_B + "**"
            if len(refs) % 2 == 1:
                c_dep_data[refs[-1]] = deps_data[dep][refs[-1]]

            if bolded_in_row > 0 or not skip_unchanged:
                compared_deps_data[dep] = c_dep_data

        for dep in all_deps:
            if dep not in HUMAN_NAME:
                log.warning(
                    "Dependency " + dep + " is missing from the HUMAN_NAME dictionary"
                )
            if dep not in HOME_URL:
                log.warning(
                    "Dependency " + dep + " is missing from the HOME_URL dictionary"
                )

        deps_name_urllink_mapping = {
            d: (
                "[" + HUMAN_NAME.get(d, d) + "](" + HOME_URL[d] + ")"
                if d in HOME_URL
                else HUMAN_NAME.get(d, d)
            )
            for d in all_deps
        }

        md_table = dict_2d_as_markdown_table(
            compared_deps_data,
            header_cell="CFEngine version",
            row_name_mapping=deps_name_urllink_mapping,
        )
        return md_table


def dict_2d_as_markdown_table(
    nested_dict,
    header_cell="",
    row_name_mapping=None,
):
    """Input `nested_dict` is assumed to be of the form `nested_dict[row][column] = cell`."""
    column_separator = " | "
    row_left_separator = "| "
    row_right_separator = " |\n"

    if row_name_mapping is None:
        row_names = nested_dict.keys()
    else:
        row_names = list(map(lambda d: row_name_mapping[d], nested_dict.keys()))
    header_column_width = max(
        len(header_cell), max(len(row_name) for row_name in row_names)
    )

    # this assumes that the ordered dictionary's first value has all the inner keys
    column_names = list(nested_dict[list(nested_dict.keys())[0]].keys())
    header_row = [header_cell] + column_names

    column_widths = [header_column_width] + [
        max(
            [len(str(nested_dict[row][column_name])) for row in nested_dict]
            + [len(column_name)]
        )
        for column_name in column_names
    ]

    header_row_markdown = (
        row_left_separator
        + column_separator.join(
            [
                "{:<{}}".format(column_header, column_width)
                for column_header, column_width in zip(header_row, column_widths)
            ]
        )
        + row_right_separator
    )
    table_string = header_row_markdown

    separator_row_markdown = (
        row_left_separator
        + column_separator.join(
            [":" + "-" * (column_width - 1) for column_width in column_widths]
        )
        + row_right_separator
    )
    table_string += separator_row_markdown

    table_string += (
        row_right_separator.join(
            [
                row_left_separator
                + column_separator.join(
                    [
                        "{:<{}}".format(
                            nested_dict.get(row, {}).get(column_header, row_name),
                            column_width,
                        )
                        for column_header, column_width in zip(
                            header_row, column_widths
                        )
                    ]
                )
                for row_name, row in zip(row_names, nested_dict)
            ]
        )
        + row_right_separator
    )

    return table_string


def parse_args():
    parser = argparse.ArgumentParser(
        description="CFEngine dependencies enumeration tool"
    )
    parser.add_argument(
        "refs",
        nargs="*",
        help="List of refs (branches or tags) to process, given as separate arguments",
        default=ACTIVE_BRANCHES,
    )
    parser.add_argument(
        "--to-json",
        help="Output to a JSON file with an optionally specified path",
        nargs="?",
        const="deps.json",
        default=None,
        dest="json_path",
    )
    parser.add_argument(
        "--to-cdx-sbom",
        help="Output to a CycloneDX SBOM JSON file (or files, for multiple refs) with an optionally specified path template",
        nargs="?",
        const="sbom-{}.cdx.json",
        default=None,
        dest="cdx_sbom_path_template",
    )
    parser.add_argument(
        "--compare",
        action="store_true",
        help="Compare refs in pairs instead of processing each ref individually for the displayed Markdown table",
    )
    parser.add_argument(
        "--skip-unchanged",
        action="store_true",
        help="Skip dependencies with all versions identical when using --compare",
    )
    parser.add_argument(
        "--patch",
        action="store_true",
        help="Modify the README with updated dependency tables in addition to displaying them",
    )
    parser.add_argument(
        "--no-info",
        action="store_true",
        help="Disable informational messages",
    )
    parser.add_argument(
        "--root",
        help="Optionally specify buildscripts root directory path",
        dest="repo_path",
    )

    return parser.parse_args()


def main():
    args = parse_args()

    if args.compare and len(args.refs) % 2 == 1:
        log.warning("comparing with an odd number of versions")

    dr = DepsReader(repo_path=args.repo_path, log_info=not args.no_info)

    if args.json_path:
        dr.write_deps_json(args.json_path, args.refs)

    if args.cdx_sbom_path_template:
        dr.write_cdx_sboms(args.cdx_sbom_path_template, args.refs)

    if args.patch or not args.compare:
        updated_readme, updated_agent_table, updated_hub_table = (
            dr.updated_deps_markdown_table(args.refs)
        )

    if args.compare:
        comparison_table = dr.comparison_md_table(args.refs, args.skip_unchanged)
        print(comparison_table)
    else:
        print("### Agent dependencies\n")
        print(updated_agent_table)
        print("\n### Enterprise Hub dependencies\n")
        print(updated_hub_table)

    if args.patch:
        dr.patch_readme(updated_readme)


if __name__ == "__main__":
    sys.exit(main())
