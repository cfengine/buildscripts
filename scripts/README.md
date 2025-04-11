# deptool

`deptool.py` is a script which can be used to enumerate dependencies of CFEngine.
It supports printing to stdout in the Markdown table format, and printing to file in the JSON format (see `--to-json`).
It can also generate basic SBOMs in the CycloneDX JSON format (see [below](https://github.com/cfengine/buildscripts/tree/master/scripts#generating-cyclonedx-json-sboms) for usage instructions).
It can be used as a replacement for the [cf-bottom](https://github.com/cfengine/cf-bottom/) `depstable` command.

`deptool.py` works on a local buildscripts repository. By default, the repository is assumed to be current working directory (i.e. `.`).
A custom path for the local repository can be specified using the `--root` argument.
Running the script will modify the git state of the repository by checking out branches (and with `--patch`, also overwriting and git-adding `README.md`), so it might be preferable to [use a copy of the buildscripts repository](https://github.com/cfengine/buildscripts/tree/master/scripts#using-a-copy-of-the-repository).

A custom list of versions to process can be specified ([given as space-separated command-line arguments](https://github.com/cfengine/buildscripts/tree/master/scripts#specifying-custom-versions-list)).

See `python deptool.py -h` for more information on all available command-line arguments.

## Examples

### Suppressing logs

```
$ python scripts/deptool.py --no-info
WARNING:root:didn't find dep in line [| libgcc                                                                            |        |        |        | AIX and Solaris only     |]
### Agent Dependencies

| CFEngine version                                                                  | 3.21.x | 3.24.x | master | Notes                    |
| :-------------------------------------------------------------------------------- | :----- | :----- | :----- | :----------------------- |
| [diffutils](https://ftpmirror.gnu.org/diffutils/)                                 | 3.10   | 3.10   | 3.10   |                          |
| [libacl](https://download.savannah.gnu.org/releases/acl/)                         | 2.3.2  | 2.3.2  | 2.3.2  |                          |
| [libattr](https://download.savannah.gnu.org/releases/attr/)                       | 2.5.2  | 2.5.2  | 2.5.2  |                          |
| [libcurl](https://curl.se/download.html)                                          | 8.10.1 | 8.10.1 | 8.11.1 |                          |
| [libgnurx](https://www.gnu.org/software/rx/rx.html)                               | 2.5.1  | 2.5.1  | 2.5.1  | Windows Enterprise agent |
| [libiconv](https://ftp.gnu.org/gnu/libiconv/)                                     | 1.17   | 1.17   | 1.17   | Needed by libxml2        |
| [libxml2](https://gitlab.gnome.org/GNOME/libxml2)                                 | 2.13.4 | 2.13.4 | 2.13.5 |                          |
| [libyaml](https://pyyaml.org/wiki/LibYAML)                                        | 0.2.5  | 0.2.5  | 0.2.5  |                          |
| [LMDB](https://github.com/LMDB/lmdb/)                                             | 0.9.33 | 0.9.33 | 0.9.33 |                          |
| [OpenLDAP](https://www.openldap.org/software/download/OpenLDAP/openldap-release/) | 2.6.8  | 2.6.8  | 2.6.9  | Enterprise agent only    |
| [OpenSSL](https://openssl.org/)                                                   | 3.0.15 | 3.4.0  | 3.4.0  |                          |
| [PCRE](https://www.pcre.org/)                                                     | 8.45   | -      | -      |                          |
| [PCRE2](https://github.com/PCRE2Project/pcre2/releases/)                          | -      | 10.44  | 10.44  |                          |
| [pthreads-w32](https://sourceware.org/pub/pthreads-win32/)                        | 2-9-1  | 2-9-1  | 2-9-1  | Windows Enterprise agent |
| [SASL2](https://www.cyrusimap.org/sasl/)                                          | 2.1.28 | 2.1.28 | 2.1.28 | Solaris Enterprise agent |
| [zlib](https://www.zlib.net/)                                                     | 1.3.1  | 1.3.1  | 1.3.1  |                          |
| [librsync](https://github.com/librsync/librsync/releases)                         | -      | -      | 2.3.4  |                          |
| [leech](https://github.com/larsewi/leech/releases)                                | -      | -      | 0.1.24 |                          |

### Enterprise Hub dependencies

| CFEngine version                                    | 3.21.x | 3.24.x | master |
| :-------------------------------------------------- | :----- | :----- | :----- |
| [Apache](https://httpd.apache.org/)                 | 2.4.62 | 2.4.62 | 2.4.62 |
| [APR](https://apr.apache.org/)                      | 1.7.5  | 1.7.5  | 1.7.5  |
| [apr-util](https://apr.apache.org/)                 | 1.6.3  | 1.6.3  | 1.6.3  |
| [Git](https://www.kernel.org/pub/software/scm/git/) | 2.47.0 | 2.47.0 | 2.47.1 |
| [libexpat](https://libexpat.github.io/)             | -      | 2.6.3  | 2.6.3  |
| [PHP](https://php.net/)                             | 8.3.13 | 8.3.13 | 8.3.15 |
| [PostgreSQL](https://www.postgresql.org/)           | 15.8   | 16.4   | 17.2   |
| [nghttp2](https://nghttp2.opg/)                     | -      | -      | 1.64.0 |
| [rsync](https://download.samba.org/pub/rsync/)      | 3.3.0  | 3.3.0  | 3.3.0  |

```

### Specifying custom versions list

```
python scripts/deptool.py 3.21.6 3.24.x master
```

### Comparing versions

```
$ python scripts/deptool.py 3.24.x master --compare --no-info
| CFEngine version                                                                  | 3.24.x | **master** |
| :-------------------------------------------------------------------------------- | :----- | :--------- |
| [Apache](https://httpd.apache.org/)                                               | 2.4.62 | 2.4.62     |
| [APR](https://apr.apache.org/)                                                    | 1.7.5  | 1.7.5      |
| [apr-util](https://apr.apache.org/)                                               | 1.6.3  | 1.6.3      |
| [diffutils](https://ftpmirror.gnu.org/diffutils/)                                 | 3.10   | 3.10       |
| [Git](https://www.kernel.org/pub/software/scm/git/)                               | 2.47.0 | **2.47.1** |
| [libacl](https://download.savannah.gnu.org/releases/acl/)                         | 2.3.2  | 2.3.2      |
| [libattr](https://download.savannah.gnu.org/releases/attr)                        | 2.5.2  | 2.5.2      |
| [libcurl](https://curl.se/download.html)                                          | 8.10.1 | **8.11.1** |
| [libcurl-hub](https://curl.se/download.html)                                      | 8.10.1 | **8.11.1** |
| [libexpat](https://libexpat.github.io/)                                           | 2.6.3  | 2.6.3      |
| [libgnurx](https://www.gnu.org/software/rx/rx.html)                               | 2.5.1  | 2.5.1      |
| [libiconv](https://ftp.gnu.org/gnu/libiconv/)                                     | 1.17   | 1.17       |
| [libxml2](https://gitlab.gnome.org/GNOME/libxml2)                                 | 2.13.4 | **2.13.5** |
| [LibYAML](https://pyyaml.org/wiki/LibYAML)                                        | 0.2.5  | 0.2.5      |
| [LMDB](https://github.com/LMDB/lmdb/)                                             | 0.9.33 | 0.9.33     |
| [OpenLDAP](https://www.openldap.org/software/download/OpenLDAP/openldap-release/) | 2.6.8  | **2.6.9**  |
| [OpenSSL](https://openssl.org/)                                                   | 3.4.0  | 3.4.0      |
| [PCRE2](https://github.com/PCRE2Project/pcre2/releases/)                          | 10.44  | 10.44      |
| [PHP](https://php.net/)                                                           | 8.3.13 | **8.3.15** |
| [PostgreSQL](https://www.postgresql.org/)                                         | 16.4   | **17.2**   |
| [pthreads-w32](https://sourceware.org/pub/pthreads-win32/)                        | 2-9-1  | 2-9-1      |
| [rsync](https://download.samba.org/pub/rsync/)                                    | 3.3.0  | 3.3.0      |
| [SASL2](https://www.cyrusimap.org/sasl/)                                          | 2.1.28 | 2.1.28     |
| [zlib](https://www.zlib.net/)                                                     | 1.3.1  | 1.3.1      |
| [leech](https://github.com/larsewi/leech/releases)                                | -      | **0.1.24** |
| [librsync](https://github.com/librsync/librsync/releases)                         | -      | **2.3.4**  |
| [nghttp2](https://nghttp2.org/)                                                   | -      | **1.64.0** |

```

Rows which contain no dependency version changes can be omitted:

```
$ python scripts/deptool.py --compare 3.21.5 3.21.6 3.24.0 3.24.1 --no-info --skip-unchanged
| CFEngine version                                                                  | 3.21.5 | **3.21.6** | 3.24.0 | **3.24.1** |
| :-------------------------------------------------------------------------------- | :----- | :--------- | :----- | :--------- |
| [Apache](https://httpd.apache.org/)                                               | 2.4.59 | **2.4.62** | 2.4.59 | **2.4.62** |
| [APR](https://apr.apache.org/)                                                    | 1.7.4  | **1.7.5**  | 1.7.4  | **1.7.5**  |
| [Git](https://www.kernel.org/pub/software/scm/git/)                               | 2.45.1 | **2.47.0** | 2.45.2 | **2.47.0** |
| [LCOV](https://github.com/linux-test-project/lcov/)                               | 1.16   | **-**      | -      | -          |
| [libcurl](https://curl.se/download.html)                                          | 8.7.1  | **8.10.1** | 8.8.0  | **8.10.1** |
| [libcurl-hub](https://curl.se/download.html)                                      | 8.7.1  | **8.10.1** | 8.8.0  | **8.10.1** |
| [libxml2](https://gitlab.gnome.org/GNOME/libxml2)                                 | 2.12.6 | **2.13.4** | 2.13.1 | **2.13.4** |
| [LMDB](https://github.com/LMDB/lmdb/)                                             | 0.9.32 | **0.9.33** | 0.9.33 | 0.9.33     |
| [OpenLDAP](https://www.openldap.org/software/download/OpenLDAP/openldap-release/) | 2.6.7  | **2.6.8**  | 2.6.8  | 2.6.8      |
| [OpenSSL](https://openssl.org/)                                                   | 3.0.13 | **3.0.15** | 3.3.1  | **3.4.0**  |
| [PHP](https://php.net/)                                                           | 8.2.19 | **8.3.13** | 8.3.8  | **8.3.13** |
| [PostgreSQL](https://www.postgresql.org/)                                         | 15.6   | **15.8**   | 16.3   | **16.4**   |
| [libexpat](https://libexpat.github.io/)                                           | -      | -          | 2.5.0  | **2.6.3**  |

```

### Using a copy of the repository

```
python scripts/deptool.py --root ../buildscripts-copy
```

### Generating CycloneDX JSON SBOMs

```
python deptool.py --to-cdx-sbom
```

A separate CycloneDX JSON SBOM is generated for each version. Optionally, a path template can be specified using `{}` as a substitute for the version:

```
python deptool.py --to-cdx-sbom my-sbom-{}.cdx.json
```
