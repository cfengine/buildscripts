
# Building CFEngine with nix

## Common workflow

You add a change in one of your repo. This workflow assumes you commit your changes first — `nix flake update` needs a stable commit to pin to (an uncommitted/dirty tree is handled differently; see the note at the end).


```
victor-moene@victomoe:~/northern.tech/cfengine/core (cfengine-flake)$ touch a
victor-moene@victomoe:~/northern.tech/cfengine/core (cfengine-flake)$ git add a 
victor-moene@victomoe:~/northern.tech/cfengine/core (cfengine-flake)$ git commit -m "a"
[cfengine-flake 150282eb4] a
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 a
victor-moene@victomoe:~/northern.tech/cfengine/core (cfengine-flake)$ git status
On branch cfengine-flake
Your branch is ahead of 'origin/cfengine-flake' by 1 commit.
  (use "git push" to publish your local commits)

nothing to commit, working tree clean
```

Then you update buildscripts' flake.lock

```
victor-moene@victomoe:~/northern.tech/cfengine/buildscripts/contrib/nix (cfengine-buildscripts-flake)$ nix flake update
warning: Git tree '/home/victor-moene/northern.tech/cfengine/buildscripts' is dirty
warning: updating lock file "/home/victor-moene/northern.tech/cfengine/buildscripts/contrib/nix/flake.lock":
• Updated input 'core':
    'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=87d67cce8b4367d21139282256d23f7f407aca49&submodules=1' (2026-09-07)
  → 'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=150282eb48c808a745abcdfee69cc0d409313a14&submodules=1' (2026-09-07)
• Updated input 'enterprise/core':
    'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=87d67cce8b4367d21139282256d23f7f407aca49&submodules=1' (2026-09-07)
  → 'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=150282eb48c808a745abcdfee69cc0d409313a14&submodules=1' (2026-09-07)
• Updated input 'mission-portal/nova/core':
    'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=87d67cce8b4367d21139282256d23f7f407aca49&submodules=1' (2026-09-07)
  → 'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=150282eb48c808a745abcdfee69cc0d409313a14&submodules=1' (2026-09-07)
• Updated input 'mission-portal/nova/enterprise/core':
    'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=87d67cce8b4367d21139282256d23f7f407aca49&submodules=1' (2026-09-07)
  → 'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=150282eb48c808a745abcdfee69cc0d409313a14&submodules=1' (2026-09-07)
• Updated input 'nova/core':
    'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=87d67cce8b4367d21139282256d23f7f407aca49&submodules=1' (2026-09-07)
  → 'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=150282eb48c808a745abcdfee69cc0d409313a14&submodules=1' (2026-09-07)
• Updated input 'nova/enterprise/core':
    'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=87d67cce8b4367d21139282256d23f7f407aca49&submodules=1' (2026-09-07)
  → 'git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix&ref=refs/heads/cfengine-flake&rev=150282eb48c808a745abcdfee69cc0d409313a14&submodules=1' (2026-09-07)
```

In short, the flake.lock is a file pinning all the inputs of the final derivation.

Now you can build with the newest commit:

```
victor-moene@victomoe:~/northern.tech/cfengine/buildscripts/contrib/nix (cfengine-buildscripts-flake)$ nix build .#community-client -o myoutput
```

You can choose to build `community-client`, `enterprise-client` or `enterprise-hub`. These are listed in `buildscripts/contrib/nix/flake.nix`

Where myoutput is a symlink with the compiled binaries. For exemple, from a previous build, I got:

```
victor-moene@victomoe:~/northern.tech/cfengine/buildscripts/contrib/nix (cfengine-buildscripts-flake)$ ls myoutput
bin  cgi-bin  conf  error  etc  htdocs  icons  lib  logs  masterfiles  master_software_updates  modules  php  sbin  share  var
```

CFEngine expects some level of permissions on its source files, so you might have to copy the output somewhere else.

## Sharing builds

To share fully reproducible builds, simply share the `flake.lock` file, and run nix build. This assumes you have the same commits in the repos.

## Garbage collection

Nix stores every derivation as a unique package in the Nix store, so disk usage can grow quickly. Run `nix-collect-garbage` (or `nix-collect-garbage -d` to also remove old generations) from time to time to reclaim space.

Note: any `-o` result symlink (e.g. `myoutput`) acts as a garbage-collection root — as long as it exists, Nix won't clean up the store paths it points to. Remove old output symlinks you no longer need before running garbage collection, or point `-o` at `/tmp` so they get cleaned up automatically.

