# Debian Dependencies for CFEngine

The files in this directory provide the means to build Debian packages
which depend on what you need in order to build and develop the
CFEngine code-base.  The details of how you do your development affect
which of these packages you'll find useful; see the description at the
end of each .ctl file for details.

For typical development, as a contributor, it should suffice to
install the two packages that a simple run of make -k shall produce.
If you install these via an apt repository, your apt tools should
automatically pull in all the packages on which they depend.  The main
advantages to having these dependency packages installed are
 * to simplify installing all needed dependencies and
 * to help you keep track of why you have those packages installed.

If you install using the apt tools, they'll mark the prerequisites as
installed to satisfy a dependency.  If you later install an update of
these dependency packages, any obsolete prerequisites shall be marked
for deletion automatically.

You can also install the packages using dpkg -i; it'll report conflict
due to any needed packages that are missing, but a run of aptitude
shall offer you installation of those missing packages as a way to
resolve those conflicts.  Accept this resolution and it'll all work.
You may need to repeat your original dpkg -i to clear the packages'
"broken" flag.

## Implementation

These dependency packages are generated using the Debian equivs
package: you'll need to install it (and its dependencies) before you
run make.  The Makefile included here knows how to drive generation of
packages using the equivs tools.

If you don't have lintian installed, you'll get an error about its
absence, but your packages have been built all the same (they just
haven't been sanity-checked), albeit you need to make -k in order to
get all packages, rather than stopping on the first error.

For details related to contents of the *.ctl files,
see [Debian Control](https://www.debian.org/doc/debian-policy/ch-controlfields.html)
