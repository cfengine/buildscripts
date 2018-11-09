File `install-dependencies` and the relevant subdirectories
in `deps-packaging` are the source of this information.


Build dependencies:

* lcov
* git
* rsync

## Agent Dependencies

| Package      | CFEngine 3.7.x | CFEngine 3.10.x |                      CFEngine 3.12.x | Notes                    |
| ------------ | -------------- | --------------- | ------------------------------------ | ------------------------ |
| cyrus-sasl   |         2.1.26 |          2.1.26 |                               2.1.26 | Solaris Enterprise agent |
| lcov         |           1.13 |            1.13 |                                 1.13 |                          |
| libacl       |         2.2.52 |          2.2.52 |                               2.2.52 |                          |
| libattr      |         2.4.47 |          2.4.47 |                               2.4.47 |                          |
| libcurl      |         7.59.0 |          7.59.0 |                               7.60.0 |                          |
| libgnurx     |          2.5.1 |           2.5.1 |                                2.5.1 | Windows Enterprise agent |
| libiconv     |           1.15 |            1.15 |                                 1.15 |                          |
| libxml2      |          2.9.8 |           2.9.8 |                                2.9.8 |                          |
| libyaml      |          0.1.7 |           0.1.7 |                                0.1.7 |                          |
| libvirt      |        1.1.3.9 |         1.1.3.9 | removed from cfengine built packages |                          |
| LMDB         |         0.9.22 |          0.9.22 |                               0.9.22 |                          |
| OpenSSL      |         1.0.2o |          1.0.2o |                               1.1.0h |                          |
| OpenLDAP     |         2.4.46 |          2.4.46 |                               2.4.46 | Enterprise agent only    |
| PCRE         |           8.42 |            8.42 |                                 8.42 |                          |
| pthreads-w32 |          2.9.1 |           2.9.1 |                                2.9.1 | Windows Enterprise agent |
| zlib         |         1.2.11 |          1.2.11 |                               1.2.11 |                          |
| PostgreSQL   |         9.0.23 |          9.0.23 | removed from cfengine built packages |                          |

* [zlib](http://www.zlib.net/) 1.2.11
* [OpenSSL](http://openssl.org/) 1.1.0i
* [PCRE](http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/) 8.42
* [LMDB](https://github.com/LMDB/lmdb/) 0.9.22
* [libyaml](http://pyyaml.org/wiki/LibYAML) 0.2.1
* [libxml2](http://xmlsoft.org/sources/) 2.9.8
* [libiconv](http://ftp.gnu.org/gnu/libiconv/) 1.15
  * Needed by libxml2
* [libacl](http://download.savannah.gnu.org/releases/acl/) 2.2.53
* [libattr](http://download.savannah.gnu.org/releases/attr/) 2.4.48
* [libcurl](http://curl.haxx.se/download.html) 7.62.0
* libgcc
  * Currently only in use on AIX, Solaris, GCC dynamically links to it in order
    to substitute missing system functions
  * "Package" only copies the (outdated) system library to `/var/cfengine`

## Enterprise Hub dependencies:


| Package    | CFEngine 3.7.x | CFEngine 3.10.x | CFEngine 3.12.x |
| ---------- | -------------- | --------------- | --------------- |
| Apache     |         2.2.34 |          2.4.33 |          2.4.29 |
| APR        |          1.5.2 |           1.5.2 |           1.6.3 |
| apr-util   |          1.5.2 |           1.5.4 |           1.6.1 |
| Git        |        1.8.5.6 |          2.13.6 |          2.17.1 |
| libmcrypt  |          2.5.8 |           2.5.8 |         removed |
| OpenLDAP   |         2.4.45 |          2.4.45 |          2.4.45 |
| PHP        |         5.6.35 |          5.6.35 |           7.2.6 |
| PostgreSQL |         9.3.22 |           9.6.8 |            10.4 |
| Redis      |         2.8.24 |          3.2.11 |         removed |
| rsync      |          3.1.3 |           3.1.3 |           3.1.3 |


* [MinGW-w64](http://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
  * Requires change of buildslaves (autobuild)
* [pthreads-w32](ftp://sourceware.org/pub/pthreads-win32/) 2.9.1
* [OpenLDAP](http://www.openldap.org/software/download/OpenLDAP/openldap-release/) 2.4.46
* [gnu rx](http://www.gnu.org/software/rx/rx.html) 2.5.1 **DEPRECATED**
  * Needed by MinGW

Hub specific dependencies:

* [APR](https://apr.apache.org/) 1.6.5
* [apr-util](https://apr.apache.org/) 1.6.1
* [Apache](http://httpd.apache.org/) 2.4.35
* [PostgreSQL](http://www.postgresql.org/) for the hub 10.6
* [Redis](http://redis.io/) 3.2.11
* [PHP](http://php.net/) 7.2.12
* [Git](https://www.kernel.org/pub/software/scm/git/) 2.19.1
* [rsync](https://download.samba.org/pub/rsync/) 3.1.3

Other dependencies (**find out why they are needed!**)

* [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads) 2.1.26
  * Only build on Solaris and HP-UX, why? What makes it necessary?

* autoconf 2.69
