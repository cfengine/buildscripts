CFEngine Build Instructions for FreeBSD
=======================================

Pre-Requisites
--------------
* setup and configure git
```
sudo pkg install -qy devel/git
git config --global user.email <your git email>
git config --global user.name <your git username>
```

* install other dependencies
```
sudo pkg install -qy lang/python security/sudo
```

Configure Environment
---------------------
* for either community or enterprise edition use
```
export BUILD_TYPE=DEBUG
export EXPLICIT_ROLE=agent
```
* for community edition use
```
export PROJECT=community
```
* in order to build enterprise edition you must have access to
the enterprise github repository, typically this is not granted
but contact sales@northern.tech to discuss.
```
export PROJECT=nova
```

Steps
-----
```
mkdir build
cd build
git clone git@github.com:cfengine/buildscripts.git
git clone git@github.com:cfengine/core.git
git clone git@github.com:cfengine/masterfiles.git
git clone git@github.com:cfengine/enterprise.git # optional see Configure Environment above
git clone git@github.com:cfengine/design-center.git
sudo pkg install -qy devel/autoconf devel/automake devel/libtool
./buildscripts/build-scripts/autogen
sudo pkg delete -qy devel/autoconf devel/automake devel/libtool m4
sudo pkg delete -qyx 'auto.*wrapper'
sudo pkg install -qy devel/gmake lang/gcc6
sudo pkg install -qy databases/sqlite3
sudo pkg install -qy devel/pkgconf ftp/wget
./buildscripts/build-scripts/build-environment-check
./buildscripts/build-scripts/install-dependencies
./buildscripts/build-scripts/configure
./buildscripts/build-scripts/generate-source-tarballs
./buildscripts/build-scripts/test
./buildscripts/build-scripts/compile
./buildscripts/build-scripts/package
```

The generated package will be either located in cfengine-nova or cfengine-community depending on the option you chose.

Install
-------
* If installing on the same system that build was performed, first clean cfbuild packages
```
sudo pkg delete -qyx cfbuild-.*
```
* then install the package
```
sudo pkg install cfengine-<nova|community>/cfengine-<nova|community>-<version>.txz
```

Dependency Updates
------------------
When a dependency version changes in the deps-packages/*/distfile file the deps-packages/*/freebsd/*-MANIFEST files will be automatically updated in this repository. This should be done manually and then the changes to *-MANIFEST should be committed to this repository.

The automated process updates the version number in *-MANIFEST and also updates the files{} section which contains sha hashes for each distribution file. Pruning of the distribution files to include might also be desired but is optional.
