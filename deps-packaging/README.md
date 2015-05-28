See file `install-dependencies` for more details, as well as the
relevant subdirectories.


Build dependencies:

* lcov
* autoconf
* automake
* libtool
* git
* rsync

Agent dependencies:

* [zlib](http://www.zlib.net/) 1.2.8
* [OpenSSL](http://openssl.org/) 0.9.8ze **OUTDATED** end-of-2015 will be **DEPRECATED**
* [PCRE](http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/) 8.33 **OUTDATED**
* [LMDB](https://github.com/LMDB/lmdb/) 0.9.14
* [libyaml](http://pyyaml.org/wiki/LibYAML) 0.1.5
* [libxml2](ftp://xmlsoft.org/libxml2/) 2.9.1 **OUTDATED**
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
* pthreads-w32
* [OpenLDAP](http://www.openldap.org/software/download/) 2.4.36 **OUTDATED**
* [libvirt](http://libvirt.org/sources/stable_updates/) 1.1.3 **OUTDATED**

Hub specific dependencies:

* [APR](https://apr.apache.org/) 1.4.8 **OUTDATED**
* [apr-util](https://apr.apache.org/) 1.5.2 **OUTDATED**
* [Apache](http://httpd.apache.org/) 2.2.29
* [PostgreSQL](http://www.postgresql.org/) 9.0.4 **OUTDATED** 9/2015 to be **DEPRECATED**
* PostgreSQL for the hub 9.3.2  **OUTDATED**
  * **TODO** Why two different postgresql?
* [Redis](http://redis.io/) 2.8.2 **WAY OUTDATED**
* [PHP](http://php.net/) 5.4.38 **OUTDATED**
* [php-apc](https://pecl.php.net/package/APC) 3.1.13
  * We're using the latest version, which was released in 2012!
    This project seems stale, do we really need it in our code?
    **TODO remove**
* [php-svn](https://pecl.php.net/package/svn) 1.0.1 **OUTDATED**
* [libcurl](http://curl.haxx.se/download.html) 7.27.0 **OUTDATED**

Other dependencies (**find out why they are needed!**)

* libmcrypt (??)
* libiconv  (??)
* [gnu rx](http://www.gnu.org/software/rx/rx.html) **DEPRECATED**
* [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads) 2.1.26
  * Not built on RHEL, why?

