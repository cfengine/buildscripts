File `install-dependencies` and the relevant subdirectories
in `deps-packaging` are the source of this information.


Build dependencies:

* lcov
* git
* rsync

## Agent Dependencies

| CFEngine version | 3.12.x | 3.15.x | master | Notes |
|  --------------  | ------ | ------ | ------ | ----- |
|  sasl2           | 2.1.27 | 2.1.27 | 2.1.27 | Solaris Enterprise agent |
|  lcov            | 1.14   | 1.14   | 1.14   |                          |
|  libacl          | 2.2.53 | 2.2.53 | 2.2.53 |                          |
|  libattr         | 2.4.48 | 2.4.48 | 2.4.48 |                          |
|  libcurl         | 7.69.0 | 7.69.0 | 7.68.0 |                          |
|  libgnurx        | 2.5.1  | 2.5.1  | 2.5.1  | Windows Enterprise agent |
|  libiconv        | 1.16   | 1.16   | 1.16   |                          |
|  libxml2         | 2.9.10 | 2.9.10 | 2.9.10 |                          |
|  libyaml         | 0.2.2  | 0.2.2  | 0.2.2  |                          |
|  lmdb            | 0.9.24 | 0.9.24 | 0.9.24 |                          |
|  openldap        | 2.4.49 | 2.4.49 | 2.4.49 | Enterprise agent only    |
|  openssl         | 1.1.1d | 1.1.1d | 1.1.1d |                          |
|  pcre            | 8.44   | 8.44   | 8.44   |                          |
|  pthreads-w32    | 2-9-1  | 2-9-1  | 2-9-1  | Windows Enterprise agent |
|  zlib            | 1.2.11 | 1.2.11 | 1.2.11 |                          |

* [zlib](http://www.zlib.net/) 1.2.11
* [OpenSSL](http://openssl.org/) 1.1.1d
* [PCRE](http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/) 8.44
* [LMDB](https://github.com/LMDB/lmdb/) 0.9.24
* [libyaml](http://pyyaml.org/wiki/LibYAML) 0.2.2
* [libxml2](http://xmlsoft.org/sources/) 2.9.10
* [libiconv](http://ftp.gnu.org/gnu/libiconv/) 1.16
  * Needed by libxml2
* [libacl](http://download.savannah.gnu.org/releases/acl/) 2.2.53
* [libattr](http://download.savannah.gnu.org/releases/attr/) 2.4.48
* [libcurl](http://curl.haxx.se/download.html) 7.68.0
* libgcc
  * Currently only in use on AIX, Solaris, GCC dynamically links to it in order
    to substitute missing system functions
  * "Package" only copies the (outdated) system library to `/var/cfengine`

## Enterprise Hub dependencies:


| CFEngine version | 3.12.x | 3.15.x | master |
|  --------------  | ------ | ------ | ------ |
|  apache          | 2.4.41 | 2.4.41 | 2.4.41 |
|  apr             | 1.7.0  | 1.7.0  | 1.7.0  |
|  apr-util        | 1.6.1  | 1.6.1  | 1.6.1  |
|  git             | 2.25.1 | 2.25.1 | 2.25.1 |
|  openldap        | 2.4.49 | 2.4.49 | 2.4.49 |
|  php             | 7.2.28 | 7.4.3  | 7.4.2  |
|  postgresql      | 10.12  | 12.2   | 12.2   |
|  rsync           | 3.1.3  | 3.1.3  | 3.1.3  |

* [MinGW-w64](http://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
  * Requires change of buildslaves (autobuild)
* [pthreads-w32](ftp://sourceware.org/pub/pthreads-win32/) 2.9.1
* [OpenLDAP](http://www.openldap.org/software/download/OpenLDAP/openldap-release/) 2.4.49
* [gnu rx](http://www.gnu.org/software/rx/rx.html) 2.5.1 **DEPRECATED**
  * Needed by MinGW

Hub specific dependencies:

* [APR](https://apr.apache.org/) 1.7.0
* [apr-util](https://apr.apache.org/) 1.6.1
* [Apache](http://httpd.apache.org/) 2.4.41
* [PostgreSQL](http://www.postgresql.org/) for the hub 12.2
* [Redis](http://redis.io/) 3.2.11
* [PHP](http://php.net/) 7.4.2
* [Git](https://www.kernel.org/pub/software/scm/git/) 2.25.1
* [rsync](https://download.samba.org/pub/rsync/) 3.1.3

Other dependencies (**find out why they are needed!**)

* [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads) 2.1.27
  * Only build on Solaris and HP-UX, why? What makes it necessary?

* autoconf 2.69
