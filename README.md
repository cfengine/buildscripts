This repository contains the necessary tools to build and test cfengine packages for various platforms.

## Hardware requirements

By experimentation I have found that building hub packages, which includes php dependency requires more than 1.6G of RAM/swap. 2.6G worked for me, less might work as well.

## Example build of Community Agent

A minimal example would be to build packages for cfengine community agent.
This should be done in an isolated environment such as a dedicated host, virtual machine or linux container.

Install necessary distribution packages. For example on debian/ubuntu:

```
apt update -y
apt upgrade -y
apt install -y git autoconf automake m4 make bison flex binutils libtool gcc g++ libc-dev libpam0g-dev python3 psmisc libtokyocabinet-dev libssl-dev libpcre2-dev default-jre-headless build-essential fakeroot ntp dpkg-dev debhelper pkg-config nfs-common sudo apt-utils wget libncurses5 rsync libexpat1-dev libexpat1 curl
apt purge -y emacs emacs24 libltdl-dev libltdl7
```

Get the cfengine source code:

```
mkdir $HOME/cfengine
cd $HOME/cfengine
git clone --recursive --depth 1 https://github.com/cfengine/core
git clone --depth 1 https://github.com/cfengine/buildscripts
git clone --depth 1 https://github.com/cfengine/masterfiles
```

Set some environment variables:

```
export NO_CONFIGURE=1
export PROJECT=community
export BUILD_TYPE=DEBUG
export EXPLICIT_ROLE=agent
```

Execute the build steps and see that packages are generated:

```
./buildscripts/build-scripts/autogen
./buildscripts/build-scripts/clean-buildmachine
./buildscripts/build-scripts/build-environment-check
./buildscripts/build-scripts/install-dependencies
./buildscripts/build-scripts/configure
./buildscripts/build-scripts/compile
./buildscripts/build-scripts/package
ls -l cfengine-community/*.deb
```

## General Build Machine Prerequisites

Due to sheer diversity of the environments, build machine is expected to provide
strict minimum amount of software (don't forget --no-install-recommends on
dpkg-based systems):

To access the build machine:
 * SSH server
  * Bundled one on Unixes
  * FreeSSHd on Windows
 * 'build' account with SSH key installed

To transfer files back and forth:
 * rsync on Unixes
 * 7z on Windows

To be able to install packages and run tests:
 * passwordless sudo access for 'build' account
 * sudo should not require TTY (remove 'Defaults requiretty' from /etc/sudoers)

To build everything:
 * GCC (gcc)
 * GNU make (make)
 * libc development package (libc-dev, glibc-devel)
 * bison (bison)
 * flex (flex)
 * fakeroot (but not fakeroot 1.12, it is horribly slow!)

To create packages:
 * Native packaging manager
  * rpm-build on RPM-based systems
  * dpkg-dev, debhelper, fakeroot
  * WiX on Windows

To build MySQL library (yeah!):
 * g++ (gcc-c++, g++)
 * ncurses (ncurses-devel, libncurses5-dev)

To build libvirt:
 * pkg-config (pkg-config, pkgconfig)

Anything else is either preprocessed on buildbot slave or built and installed
during build.

## Documentation build pre-requisites

 * texinfo
 * texlive
 * cm-super
 * texlive-fonts-extra

## Non-requisites

Build machines should not contain the following items, which may interfere with
build process:

 * CFEngine itself, either in source or binary form (build machines are
   short-living, so this is not a problem)
 * Development packages for anything beside libc to avoid picking them up
   instead of bundled ones accidentally.
 * MySQL and PostgreSQL servers, clients and libraries

The following packages should not be installed on build machines as well, to
avoid accidentally regenerating files transferred from buildslave:

 * automake
 * autoconf
 * libtool

## Dependencies

File `install-dependencies` and the relevant subdirectories in `deps-packaging` are the source of this information.

### Agent Dependencies

| CFEngine version                                                                 | 3.18.x | 3.21.x | master | Notes                    |
| -------------------------------------------------------------------------------- | ------ | ------ | ------ | ------------------------ |
| [diffutils](https://ftpmirror.gnu.org/diffutils/)                                | 3.9    | 3.9    | 3.10   |                          |
| [libacl](http://download.savannah.gnu.org/releases/acl/)                         | 2.3.1  | 2.3.1  | 2.3.1  |                          |
| [libattr](http://download.savannah.gnu.org/releases/attr/)                       | 2.5.1  | 2.5.1  | 2.5.1  |                          |
| [libcurl](http://curl.haxx.se/download.html)                                     | 8.0.1  | 8.0.1  | 8.1.2  |                          |
| [libgnurx](http://www.gnu.org/software/rx/rx.html)                               | 2.5.1  | 2.5.1  | 2.5.1  | Windows Enterprise agent |
| [libiconv](http://ftp.gnu.org/gnu/libiconv/)                                     | 1.17   | 1.17   | 1.17   | Needed by libxml2        |
| [libxml2](http://xmlsoft.org/sources/)                                           | 2.11.2 | 2.11.2 | 2.11.4 |                          |
| [libyaml](http://pyyaml.org/wiki/LibYAML)                                        | 0.2.5  | 0.2.5  | 0.2.5  |                          |
| [LMDB](https://github.com/LMDB/lmdb/)                                            | 0.9.30 | 0.9.30 | 0.9.30 |                          |
| [OpenLDAP](http://www.openldap.org/software/download/OpenLDAP/openldap-release/) | 2.6.4  | 2.6.4  | 2.6.4  | Enterprise agent only    |
| [OpenSSL](http://openssl.org/)                                                   | 1.1.1t | 3.0.8  | 3.1.1  |                          |
| [PCRE](http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/)                  | 8.45   | 8.45   | -      |                          |
| [PCRE2](https://github.com/PCRE2Project/pcre2/releases/)                         | -      | -      | 10.42  |                          |
| [pthreads-w32](ftp://sourceware.org/pub/pthreads-win32/)                         | 2-9-1  | 2-9-1  | 2-9-1  | Windows Enterprise agent |
| [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads)                     | 2.1.28 | 2.1.28 | 2.1.28 | Solaris Enterprise agent |
| [zlib](http://www.zlib.net/)                                                     | 1.2.13 | 1.2.13 | 1.2.13 |                          |
| libgcc                                                                           |        |        |        | AIX and Solaris only     |

### Enterprise Hub dependencies:

| CFEngine version                                    | 3.18.x | 3.21.x | master |
| --------------------------------------------------- | ------ | ------ | ------ |
| [Apache](http://httpd.apache.org/)                  | 2.4.57 | 2.4.55 | 2.4.57 |
| [APR](https://apr.apache.org/)                      | 1.7.4  | 1.7.4  | 1.7.4  |
| [apr-util](https://apr.apache.org/)                 | 1.6.3  | 1.6.3  | 1.6.3  |
| [Git](https://www.kernel.org/pub/software/scm/git/) | 2.40.1 | 2.40.1 | 2.41.0 |
| [libexpat](https://libexpat.github.io/)             | -      | -      | 2.5.0  |
| [PHP](http://php.net/)                              | 8.0.28 | 8.1.12 | 8.2.7  |
| [PostgreSQL](http://www.postgresql.org/)            | 13.10  | 15.2   | 15.3   |
| [rsync](https://download.samba.org/pub/rsync/)      | 3.2.7  | 3.2.7  | 3.2.7  |

* [MinGW-w64](http://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
  * Requires change of buildslaves (autobuild)

Other dependencies (**find out why they are needed!**)

* autoconf 2.69
