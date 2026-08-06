# Upgrading / patching LMDB

## Before changing the version: check the on-disk format

LMDB has no in-place upgrade. If the new version writes a different on-disk
format, every existing `*.lmdb` becomes unreadable, and CFEngine takes that for
corruption and deletes it (ENT-9717).

The format is stable within a `<major>.<minor>` series and changed in 1.0, so a
patch bump is safe and a series bump is not. Series bumps are handled by
`lmdb_dump_databases()` / `lmdb_load_databases()` in
`packaging/common/script-templates/script-common.sh` (CFE-4701), which key off the
version in `source` below via `LMDB_VERSION`. A format change *within* a series
would need `lmdb_migration_needed()` made more specific.

## Upgrading / patching

From the directory above buildscripts:

```
$ git clone https://github.com/LMDB/lmdb.git
$ cd lmdb
$ git fetch --all --tags
```

Check out the desired version (see distfiles for current version, or use a newer tag to upgrade):

```
$ export LMDB_TAG="LMDB_0.9.24"
$ git checkout $LMDB_TAG
```

Apply our patches:

```
$ cd libraries/liblmdb
$ git am -3 ../../../buildscripts/deps-packaging/lmdb/00*
```

If there were no conflicts - rejoice!

If there were any conflicts, resolve them and regenerate the patches with:

```
$ git format-patch $LMDB_TAG..HEAD
$ rm ../../../buildscripts/deps-packaging/lmdb/*.patch
$ mv 00* ../../../buildscripts/deps-packaging/lmdb
```

and commit them to proper branch in buildscripts repo

If you want to make changes to autotools files (configure.am, Makefile.am) do it now.

Commit your manual changes first (changes to configure.ac and Makefile.am).

Then generate the files using:

```
$ autoreconf -i
$ automake
```

And commit those changes separately:

```
$ git add -A
$ git commit
```

Once again, regenerate and commit the patch files in buildscripts repo:

```
$ git format-patch $LMDB_TAG..HEAD
$ rm ../../../buildscripts/deps-packaging/lmdb/*.patch
$ mv 00* ../../../buildscripts/deps-packaging/lmdb
```
