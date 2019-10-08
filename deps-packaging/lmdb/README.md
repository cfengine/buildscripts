# Upgrading / patching LMDB

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
