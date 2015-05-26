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
* [PCRE](ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/) 8.33 **OUTDATED**
* LMDB
* [libyaml](http://pyyaml.org/wiki/LibYAML) 0.1.5
* [libxml2](ftp://xmlsoft.org/libxml2/) 2.9.1 **OUTDATED**
* libgcc
  * Currently only in use on AIX, Solaris
  * "Package" only copies the (outdated) system library to `/var/cfengine`

Enterprise agent specific dependencies:

* [MinGW-w64](http://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
* pthreads-w32
* OpenLDAP
* libvirt

Hub specific dependencies:

* APR
* apr-util
* Apache
* PostgreSQL
* Redis
* PHP
* php-apc
* php-svn

Other dependencies (*find out why they are needed!*)

* libmcrypt (??)
* libiconv  (??)
* [gnu rx](http://www.gnu.org/software/rx/rx.html) **DEPRECATED**
* libcurl (is it community or enterprise or hub dependency?)
* libacl  (same question)
* libattr (same question)
* [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads) 2.1.26
  * Not built on RHEL, why?

