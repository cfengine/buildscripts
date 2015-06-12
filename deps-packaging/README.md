All versions listed apply to 3.7.x branch unless mentioned
otherwise. File `install-dependencies` and the relevant subdirectories
in `deps-packaging` are the source of this information.


Build dependencies:

* lcov
* autoconf
* automake
* libtool
* git
* rsync

Agent dependencies:

* [zlib](http://www.zlib.net/) 1.2.8
* [OpenSSL](http://openssl.org/) 1.0.2c
* [PCRE](http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/) 8.37
* [LMDB](https://github.com/LMDB/lmdb/) 0.9.14
* [libyaml](http://pyyaml.org/wiki/LibYAML) 0.1.5
* [libxml2](http://xmlsoft.org/libxml2/) 2.9.2
* [libiconv](http://ftp.gnu.org/gnu/libiconv/) 1.14
  * Needed by libxml2
* [libacl](http://download.savannah.gnu.org/releases/acl/) 2.2.52
* [libattr](http://download.savannah.gnu.org/releases/attr/) 2.4.47
* libgcc
  * Currently only in use on AIX, Solaris, GCC dynamically links to it in order
    to substitute missing system functions
  * "Package" only copies the (outdated) system library to `/var/cfengine`

Enterprise agent specific dependencies:

* [MinGW-w64](http://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
  * Requires change of buildslaves (autobuild)
* [pthreads-w32](ftp://sourceware.org/pub/pthreads-win32/) 2.9.1
* [OpenLDAP](http://www.openldap.org/software/download/) 2.4.40
* [libvirt](http://libvirt.org/sources/stable_updates/) 1.1.3.9
* [PostgreSQL](http://www.postgresql.org/) 9.0.20 9/2015 to be **DEPRECATED**
  * From this one we selectively build only `libpq`
* [gnu rx](http://www.gnu.org/software/rx/rx.html) 2.5.1 **DEPRECATED**
  * Needed by MinGW

Hub specific dependencies:

* [APR](https://apr.apache.org/) 1.5.2
* [apr-util](https://apr.apache.org/) 1.5.4
* [Apache](http://httpd.apache.org/) 2.2.29
* PostgreSQL for the hub 9.3.7
* [Redis](http://redis.io/) 2.8.20
* [PHP](http://php.net/) 5.6.9
* [libcurl](http://curl.haxx.se/download.html) 7.27.0 **OUTDATED**
  * Needed for php module
* libmcrypt 2.5.8
  * Needed for php module
* [libiconv](http://ftp.gnu.org/gnu/libiconv/) 1.14
  * Needed to be built into PHP, it's used by `cf_util_helper.php`

Other dependencies (**find out why they are needed!**)

* [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads) 2.1.26
  * Only build on Solaris and HP-UX, why? What makes it necessary?

