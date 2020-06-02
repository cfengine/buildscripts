File `install-dependencies` and the relevant subdirectories
in `deps-packaging` are the source of this information.


## Build dependencies

| CFEngine version | 3.12.x | 3.15.x | master |
| ---------------- | ------ | ------ | ------ |
| lcov             | 1.14   | 1.14   | 1.14   |
| git              |        |        |        |
| rsync            |        |        |        |

## Agent Dependencies

| CFEngine version                                                                 | 3.12.x | 3.15.x | master | Notes                    |
| -------------------------------------------------------------------------------- | ------ | ------ | ------ | ------------------------ |
| [SASL2](https://cyrusimap.org/mediawiki/index.php/Downloads)                     | 2.1.27 | 2.1.27 | 2.1.27 | Solaris Enterprise agent |
| [libacl](http://download.savannah.gnu.org/releases/acl/)                         | 2.2.53 | 2.2.53 | 2.2.53 |                          |
| [libattr](http://download.savannah.gnu.org/releases/attr/)                       | 2.4.48 | 2.4.48 | 2.4.48 |                          |
| [libcurl](http://curl.haxx.se/download.html)                                     | 7.70.0 | 7.70.0 | 7.68.0 |                          |
| [libgnurx](http://www.gnu.org/software/rx/rx.html)                               | 2.5.1  | 2.5.1  | 2.5.1  | Windows Enterprise agent |
| [libiconv](http://ftp.gnu.org/gnu/libiconv/)                                     | 1.16   | 1.16   | 1.16   | Needed by libxml2        |
| [libxml2](http://xmlsoft.org/sources/)                                           | 2.9.10 | 2.9.10 | 2.9.10 |                          |
| [libyaml](http://pyyaml.org/wiki/LibYAML)                                        | 0.2.4  | 0.2.4  | 0.2.2  |                          |
| [LMDB](https://github.com/LMDB/lmdb/)                                            | 0.9.24 | 0.9.24 | 0.9.24 |                          |
| [OpenLDAP](http://www.openldap.org/software/download/OpenLDAP/openldap-release/) | 2.4.50 | 2.4.50 | 2.4.49 | Enterprise agent only    |
| [OpenSSL](http://openssl.org/)                                                   | 1.1.1g | 1.1.1g | 1.1.1f |                          |
| [PCRE](http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/)                  | 8.44   | 8.44   | 8.44   |                          |
| [pthreads-w32](ftp://sourceware.org/pub/pthreads-win32/)                         | 2-9-1  | 2-9-1  | 2-9-1  | Windows Enterprise agent |
| [zlib](http://www.zlib.net/)                                                     | 1.2.11 | 1.2.11 | 1.2.11 |                          |
| libgcc                                                                           |        |        |        | AIX and Solaris only     |

## Enterprise Hub dependencies:

| CFEngine version                                    | 3.12.x | 3.15.x | master |
| --------------------------------------------------- | ------ | ------ | ------ |
| [Apache](http://httpd.apache.org/)                  | 2.4.43 | 2.4.43 | 2.4.41 |
| [APR](https://apr.apache.org/)                      | 1.7.0  | 1.7.0  | 1.7.0  |
| [apr-util](https://apr.apache.org/)                 | 1.6.1  | 1.6.1  | 1.6.1  |
| [Git](https://www.kernel.org/pub/software/scm/git/) | 2.26.2 | 2.26.2 | 2.25.1 |
| [PHP](http://php.net/)                              | 7.2.30 | 7.4.5  | 7.4.2  |
| [PostgreSQL](http://www.postgresql.org/)            | 10.12  | 12.2   | 12.2   |
| [rsync](https://download.samba.org/pub/rsync/)      | 3.1.3  | 3.1.3  | 3.1.3  |

* [MinGW-w64](http://sourceforge.net/projects/mingw-w64/) **OUTDATED** needed
  for [redmine#2932](https://dev.cfengine.com/issues/2932)
  * Requires change of buildslaves (autobuild)

Other dependencies (**find out why they are needed!**)

* autoconf 2.69
