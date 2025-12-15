This repository contains the necessary tools to build and test cfengine packages for various platforms.

## Hardware requirements

By experimentation I have found that building hub packages, which includes php dependency requires more than 1.6G of RAM/swap.
2.6G worked for me, less might work as well.

## Example build of Community Agent

A minimal example would be to build packages for cfengine community agent.
This should be done in an isolated environment such as a dedicated host, virtual machine or linux container.

Install necessary distribution packages.
For example on debian/ubuntu:

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
./buildscripts/build-scripts/install-dependencies
./buildscripts/build-scripts/configure
./buildscripts/build-scripts/compile
./buildscripts/build-scripts/package
ls -l cfengine-community/*.deb
```

## General Build Machine Prerequisites

Due to sheer diversity of the environments, build machine is expected to provide strict minimum amount of software (don't forget `--no-install-recommends` on dpkg-based systems):

To access the build machine:

- SSH server
  - Bundled one on Unixes
  - FreeSSHd on Windows
- 'build' account with SSH key installed

To transfer files back and forth:

- rsync on Unixes
- 7z on Windows

To be able to install packages and run tests:

- passwordless sudo access for 'build' account
- sudo should not require TTY (remove 'Defaults requiretty' from /etc/sudoers)

To build everything:

- GCC (gcc)
  - Additionally, libgcc is used on AIX and Solaris only
- GNU make (make)
- libc development package (libc-dev, glibc-devel)
- bison (bison)
- flex (flex)
- fakeroot (but not fakeroot 1.12, it is horribly slow!)

To create packages:

- Native packaging manager
  - rpm-build on RPM-based systems
  - dpkg-dev, debhelper, fakeroot
  - WiX on Windows

To build MySQL library (yeah!):

- g++ (gcc-c++, g++)
- ncurses (ncurses-devel, libncurses5-dev)

To build libvirt:

- pkg-config (pkg-config, pkgconfig)

Anything else is either preprocessed on buildbot slave or built and installed during build.

## Documentation build pre-requisites

- texinfo
- texlive
- cm-super
- texlive-fonts-extra

## Non-requisites

Build machines should not contain the following items, which may interfere with build process:

- CFEngine itself, either in source or binary form (build machines are short-living, so this is not a problem)
- Development packages for anything beside libc to avoid picking them up instead of bundled ones accidentally.
- MySQL and PostgreSQL servers, clients and libraries

The following packages should not be installed on build machines as well, to avoid accidentally regenerating files transferred from buildslave:

- automake
- autoconf
- libtool

## Dependencies

File `install-dependencies` and the relevant subdirectories in `deps-packaging` are the source of this information.

### Agent Dependencies

| CFEngine version                                                                  | 3.21.x | 3.24.x | master | Notes                    |
| :-------------------------------------------------------------------------------- | :----- | :----- | :----- | :----------------------- |
| [diffutils](https://ftpmirror.gnu.org/diffutils/)                                 | 3.12   | 3.12   | 3.12   |                          |
| [libacl](https://download.savannah.gnu.org/releases/acl/)                         | 2.3.2  | 2.3.2  | 2.3.2  |                          |
| [libattr](https://download.savannah.gnu.org/releases/attr/)                       | 2.5.2  | 2.5.2  | 2.5.2  |                          |
| [libcurl](https://curl.se/download.html)                                          | 8.17.0 | 8.17.0 | 8.17.0 |                          |
| [libgnurx](https://www.gnu.org/software/rx/rx.html)                               | 2.5.1  | 2.5.1  | 2.5.1  | Windows Enterprise agent |
| [libiconv](https://ftp.gnu.org/gnu/libiconv/)                                     | 1.18   | 1.18   | 1.18   | Needed by libxml2        |
| [libxml2](https://gitlab.gnome.org/GNOME/libxml2)                                 | 2.15.1 | 2.15.1 | 2.15.1 |                          |
| [libyaml](https://pyyaml.org/wiki/LibYAML)                                        | 0.2.5  | 0.2.5  | 0.2.5  |                          |
| [LMDB](https://github.com/LMDB/lmdb/)                                             | 0.9.33 | 0.9.33 | 0.9.33 |                          |
| [OpenLDAP](https://www.openldap.org/software/download/OpenLDAP/openldap-release/) | 2.6.10 | 2.6.10 | 2.6.10 | Enterprise agent only    |
| [OpenSSL](https://openssl.org/)                                                   | 3.0.18 | 3.6.0  | 3.6.0  | See **note** below       |
| [PCRE](https://www.pcre.org/)                                                     | 8.45   | -      | -      |                          |
| [PCRE2](https://github.com/PCRE2Project/pcre2/releases/)                          | -      | 10.47  | 10.47  |                          |
| [pthreads-w32](https://sourceware.org/pub/pthreads-win32/)                        | 2-9-1  | 2-9-1  | 2-9-1  | Windows Enterprise agent |
| [SASL2](https://www.cyrusimap.org/sasl/)                                          | 2.1.28 | 2.1.28 | 2.1.28 | Solaris Enterprise agent |
| [zlib](https://www.zlib.net/)                                                     | 1.3.1  | 1.3.1  | 1.3.1  |                          |
| [librsync](https://github.com/librsync/librsync/releases)                         | -      | -      | 2.3.4  |                          |
| [leech](https://github.com/larsewi/leech/releases)                                | -      | -      | 0.2.0  |                          |

**Note:** We don't package OpenSSL for RHEL >= 8 and SuSE >= 15.
We use the systems bundled SSL for these platforms.

### Enterprise Hub dependencies

| CFEngine version                                    | 3.21.x | 3.24.x | master |
| :-------------------------------------------------- | :----- | :----- | :----- |
| [Apache](https://httpd.apache.org/)                 | 2.4.66 | 2.4.66 | 2.4.66 |
| [APR](https://apr.apache.org/)                      | 1.7.6  | 1.7.6  | 1.7.6  |
| [apr-util](https://apr.apache.org/)                 | 1.6.3  | 1.6.3  | 1.6.3  |
| [Git](https://www.kernel.org/pub/software/scm/git/) | 2.52.0 | 2.52.0 | 2.52.0 |
| [libexpat](https://libexpat.github.io/)             | -      | 2.7.3  | 2.7.3  |
| [PHP](https://php.net/)                             | 8.3.28 | 8.3.28 | 8.4.14 |
| [PostgreSQL](https://www.postgresql.org/)           | 15.15  | 16.11  | 18.1   |
| [nghttp2](https://nghttp2.opg/)                     | -      | -      | 1.68.0 |
| [rsync](https://download.samba.org/pub/rsync/)      | 3.4.1  | 3.4.1  | 3.4.1  |

- [MinGW-w64](https://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
  - Requires change of buildslaves (autobuild)
