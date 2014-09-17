Section: contrib/devel
Maintainer: Edward Welbourne <edward.welbourne@cfengine.com>
Build-Depends: equivs
Package: cfbuildslave
Changelog: ChangeLogslave.txt
Depends: gcc, make, libc-dev, bison, flex, fakeroot | fakeroot-ng, g++, libncurses5-dev, pkg-config, dpkg-dev, rsync, openssh-server
Suggests: lcov, cfbuilddoc
Conflicts: cfengine, automake, autoconf, libtool, libssl-dev, libpcre3-dev, libqdbm-dev, libtokyocabinet-dev, libmysqlclient-dev, libpq-dev, libacl1-dev
Description: CFEngine build-slave essentials
 This package pulls in the ones a build slave needs in order to build
 CFEngine.  It also conflicts with things it's a bad idea to have
 installed on a build slave.
