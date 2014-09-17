Section: contrib/devel
Maintainer: Edward Welbourne <edward.welbourne@cfengine.com>
Build-Depends: equivs
Package: cfbuild-native
Changelog: ChangeLog-native.txt
Depends: gcc | clang, make, libpam-dev, libssl-dev, libpcre3-dev, liblmdb-dev | libtokyocabinet-dev | libqdbm-dev
Suggests: libmysqlclient-dev, libpq-dev, libacl1-dev, lcov
Description: CFEngine native prerequisites
 This package pulls in the ones you need in order to build shipped
 versions of CFEngine from source.
