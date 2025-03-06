import collections
import json
import logging as log
import os
import re
import subprocess
import sys


class GitException(Exception):
    """Base class for all exceptions in this file"""

    pass


class WrongArgumentsException(GitException):
    """Exception that is risen when incorrect arguments were passed"""

    pass


class GitRepo:
    """Class responsible for working with locally checked-out repository"""

    def __init__(
        self,
        dirname,
        repo_name,
        upstream_name,
        my_name,
        checkout_branch=None,
        checkout_tag=None,
    ):
        """Clones a remote repo to a directory (or freshens it if it's already
        checked out), configures it and optionally checks out a requested branch
        Args:
            dirname - name of directory in local filesystem where to clone the repo
            repo_name - name of repository (like 'core' or 'masterfiles')
            upstream_name - name of original owner of the repo (usually 'cfengine')
                We will pull from github.com/upstream_name/repo_name
            my_name - name of github user where we will push and create PR from
                (usually 'cf-bottom')
                We will push to github.com/my_name/repo_name
            checkout_branch - optional name of branch to checkout. If not provided,
                a branch from previous work might be left checked out
            checkout_tag - same for tag.
        """
        self.dirname = dirname
        self.repo_name = repo_name
        self.username = my_name  # TODO: this should be github username of current user

        upstream_url = "https://github.com/{}/{}.git".format(upstream_name, repo_name)
        origin_url = "https://github.com/{}/{}.git".format(my_name, repo_name)

        if not os.path.exists(dirname):
            self.run_command("clone", "--no-checkout", origin_url, dirname)
        upstream_add_command_result = self.run_command(
            "remote", "add", "upstream", upstream_url, check=False
        )
        if upstream_add_command_result.returncode != 0:
            # Assume that we failed to add remote called 'upstream' because it was
            # already added. In this case, we should succeed in setting its url.
            self.run_command("remote", "set-url", "upstream", upstream_url)
        if checkout_branch is not None:
            self.checkout(checkout_branch)
        if checkout_tag is not None:
            self.checkout(checkout_tag, tag=True)

    def run_command(self, *command, **kwargs):
        """Runs a git command against git repo.
        Syntactically this function tries to be as close to subprocess.run
        as possible, just adding 'git' with some extra parameters in the beginning
        """
        git_command = [
            "git",
            "-C",
            self.dirname,
            "-c",
            "push.default=simple",
            "-c",
            "checkout.defaultRemote=upstream",
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
            # so delete `-C self.dirname` arguments from git command line
            del git_command[1]
            del git_command[1]
        kwargs["universal_newlines"] = True
        log.debug("running command: {}".format(" ".join(git_command)))
        return subprocess.run(git_command, **kwargs)

    def checkout(self, branch=None, tag=None, remote="upstream", new=False):
        """Checkout given branch or tag, optionally creating branch.
        Note that it's an error to create-and-checkout branch which already exists.
        Also, it's not supported to create tags.
        """
        # parse args
        if not branch and not tag:
            raise WrongArgumentsException(
                "only one of `branch`, `tag` arguments can be passed to `checkout` function"
            )
        ref = branch or tag
        if not ref:
            raise WrongArgumentsException(
                "one of `branch`, `tag` arguments must be passed to `checkout` function"
            )
        if tag and new:
            raise WrongArgumentsException("this is not the way to create tags")

        if new:
            # just create new branch
            self.run_command("checkout", "-b", branch)
        else:
            # first, ensure that we're aware of target ref
            self.run_command("fetch", remote, ref)
            # switch to the branch
            if branch:
                self.run_command("checkout", branch)
            # ensure we're on the tip of ref
            self.run_command("reset", "--hard", "FETCH_HEAD")
        self.run_command("submodule", "update", "--init")

    def get_file(self, path):
        """Returns contents of a file as a single string"""
        with open(self.dirname + "/" + path) as f:
            return f.read()

    def put_file(self, path, data, add=True):
        """Overwrites file with data, optionally running `git add {path}` afterwards"""
        with open(self.dirname + "/" + path, "w") as f:
            f.write(data)
        if add:
            self.run_command("add", path)

    def commit(self, message):
        """Creates commit with message"""
        self.run_command("commit", "-m", message, "--allow-empty")

    def push(self, ref=None, remote="origin", upstream=True):
        """Pushes local branch or tag to remote repo, optionally also setting it as upstream"""
        cmd = ["push"]
        if upstream:
            cmd.append("-u")
        cmd.append(remote)
        if ref is not None:
            cmd.append(ref)

        self.run_command(*cmd)


def pretty(data):
    return json.dumps(data, indent=2)


class DepsReader:
    """
    Currently it's working only with cfengine/buildscripts repo, as described at
    https://github.com/mendersoftware/infra/blob/master/files/buildcache/release-scripts/RELEASE_PROCESS.org#minor-dependencies-update
    """

    ## def __init__(self, github, username):
    def __init__(self, username):
        ## self.github = github
        self.username = username

        # prepare repo
        REPO_OWNER = "cfengine"
        REPO_NAME = "buildscripts"
        local_path = "../../buildscriptscopy/" + REPO_NAME
        self.buildscripts_repo = GitRepo(
            local_path, REPO_NAME, REPO_OWNER, self.username, "master"
        )

    def deps_list(self, branch="master"):
        """Returns a list of dependencies for given branch, for example: `["lcov", "pthreads-w32", "libgnurx"]`.
        Assumes the proper branch is checked out by `self.buildscripts_repo`.
        """
        # TODO: get value of $EMBEDDED_DB from file
        embedded_db = "lmdb"
        if branch == "3.7.x":
            options_file = self.buildscripts_repo.get_file(
                "build-scripts/install-dependencies"
            )
        else:
            options_file = self.buildscripts_repo.get_file(
                "build-scripts/compile-options"
            )
        options_lines = options_file.splitlines()
        if branch == "3.7.x":
            filtered_lines = (
                x for x in options_lines if re.match('\s*DEPS=".*\\$DEPS', x)
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
        return only_deps

    def extract_version_from_filename(self, dep, filename):
        if dep == "openssl":
            # On different branches we use openssl from different sources
            # (this will be cleaned up soon). When downloading from github,
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
            separator = "char"
        elif dep == "pthreads-w32":
            version = re.search("w32-([0-9-]*)-rel", filename).group(1)
            separator = "-"
        else:
            version = re.search("[-_]([0-9.]*)[\.-]", filename).group(1)
            separator = "."
        return (version, separator)

    def get_current_version(self, dep):
        """Returns the current version of dependency `dep`."""
        dist_file_path = "deps-packaging/{}/distfiles".format(dep)
        dist_file = self.buildscripts_repo.get_file(dist_file_path)
        dist_file = dist_file.strip()
        old_filename = re.sub(".* ", "", dist_file)
        (old_version, separator) = self.extract_version_from_filename(dep, old_filename)
        return old_version

    def deps_versions(self, branch):
        """Returns a dictionary of dependencies and versions for a branch:
        ```
        {
            "dep1": "version",
            "dep2": "version",
            ...
        }
        ```
        """
        deps_versions = {}
        deps_list = self.deps_list(branch)
        for dep in deps_list:
            deps_versions[dep] = self.get_current_version(dep)
        return deps_versions

    def deps_table(self, branches):
        """Returns a 2D dictionary of dependencies and versions from all branches: `deps_table[dep][branch] = version`, as well as a dictionary of widths of each column (branch)."""

        deps_table = {}
        branch_column_widths = {}

        for branch in branches:
            branch_column_widths[branch] = len(branch)
            self.buildscripts_repo.checkout(branch)
            self.buildscripts_repo.run_command("pull")
            deps_versions = self.deps_versions(branch)

            for dep in deps_versions:
                if not dep in deps_table:
                    deps_table[dep] = collections.defaultdict(lambda: "-")
                deps_table[dep][branch] = deps_versions[dep]
                branch_column_widths[branch] = max(
                    branch_column_widths[branch], len(deps_versions[dep])
                )

        return deps_table, branch_column_widths

    def update_deps_table(self, branches):
        deps_table, branch_column_widths = self.deps_table(branches)

        # patch the readme
        self.buildscripts_repo.checkout("master")
        readme_file_path = "README.md"
        readme_file = self.buildscripts_repo.get_file(readme_file_path)
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
                # Desired output row: ['CFEngine version', branches..., 'Notes']
                # Also note that list addition is concatenation: [1] + [2] == [1, 2]
                row = (
                    ["CFEngine version"]
                    + [branch for branch in branches]
                    + (["Notes"] if has_notes else [])
                )
                # Width of source columns
                column_widths = [len(x) for x in line.split("|")]
                # Note that first and last column widths are zero, since line
                # begins and ends with '|'. We're actually interested in widths
                # of first column (with words "CFEngine version" in it) and,
                # possibly, last ("Notes", which is now second-to-last).
                # Between them are branch column widths, calculated earlier.
                # Also we substract 2 to remove column "padding".
                column_widths = (
                    [column_widths[1] - 2]
                    + [  # "CFEngine version"
                        branch_column_widths[branch] for branch in branches
                    ]
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
            elif line.startswith("| --"):
                line = (
                    "| " + (" | ".join(("-" * width for width in column_widths))) + " |"
                )
            else:
                # Sample line:
                # | [PHP](http://php.net/) ...
                # For it, in regexp below,
                # \[([a-z0-9-]*)\] will match [PHP]
                # \((.*?)\) will match (http://php.net/)
                match = re.match(
                    "\| \[([a-z0-9-]*)\]\((.*?)\) ", line, flags=re.IGNORECASE
                )
                if match:
                    dep_title = match.group(1)
                    dep = dep_title.lower()
                    url = match.group(2)
                else:
                    log.warning("didn't find dep in line [%s]", line)
                    continue
                if dep not in deps_table:
                    log.warning(
                        "unknown dependency in README: [%s] line [%s], will be EMPTY",
                        dep,
                        line,
                    )
                    deps_table[dep] = collections.defaultdict(lambda: "-")
                if has_notes:
                    note = re.search("\| ([^|]*) \|$", line)
                    if not note:
                        log.warning("didn't find note in line [%s]", line)
                        note = ""
                    else:
                        note = note.group(1)
                if in_hub:
                    dep = re.sub("-hub$", "", dep)
                row = (
                    ["[%s](%s)" % (dep_title, url)]
                    + [deps_table[dep][branch] for branch in branches]
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

        ## timestamp = re.sub("[^0-9-]", "_", str(datetime.datetime.today()))
        ## new_branchname = "deptables-{}".format(timestamp)
        ## self.buildscripts_repo.checkout(new_branchname, new=True)
        readme_file = "\n".join(readme_lines)
        ## self.buildscripts_repo.put_file(readme_file_path, readme_file)
        self.buildscripts_repo.put_file("READMEbottomnew.md", readme_file)
        ## self.buildscripts_repo.commit("Update dependency tables")
        ## self.buildscripts_repo.push(new_branchname)
        ## pr_text = self.github.create_pr(
        ##     target_repo="{}/{}".format(upstream_name, self.buildscripts_repo.repo_name),
        ##     target_branch="master",
        ##     source_user=self.username,
        ##     source_branch=new_branchname,
        ##     title="Update dependency tables",
        ##     text="",
        ## )


def bot_tom_depstable():
    branches = ["3.21.x", "3.24.x", "master"]

    uc = DepsReader("cfengine")
    uc.update_deps_table(branches)


def main():
    bot_tom_depstable()


if __name__ == "__main__":
    ret = main()
    sys.exit(ret)
