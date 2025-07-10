%define php_version 8.4.10

Summary: CFEngine Build Automation -- php
Name: cfbuild-php
Version: %{version}
Release: 1
Source0: php-%{php_version}.tar.gz
Source1: php.ini
Source2: php-fpm.conf
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n php-%{php_version}

if expr "`cat /etc/redhat-release`" : '.* [7]\.'
then
  patch -p1 < %{_topdir}/SOURCES/0001-Disable-fancy-intrinsics-stuff.patch
fi

%if %{?rhel}%{!?rhel:0} == 8
CFLAGS="-fPIE"
LDFLAGS="-pie"
%else
CFLAGS=""
LDFLAGS=""
%endif

./configure --prefix=%{prefix}/httpd/php \
  --with-config-file-scan-dir=%{prefix}/httpd/php/lib \
  --without-apxs2 \
  --with-openssl=shared,%{prefix} \
  --with-curl=shared,%{prefix} \
  --with-ldap=%{prefix} \
  --with-pdo-pgsql=%{prefix} \
  --with-iconv \
  --with-zlib=%{prefix} \
  --with-libmbfl=%{prefix} \
  --enable-mbstring \
  --enable-sockets \
  --disable-mbregex \
  --enable-fpm \
  --without-layout \
  --without-sqlite3 \
  --without-bz2 \
  --without-qdbm \
  --without-ndbm \
  --without-db4 \
  --without-db3 \
  --without-db2 \
  --without-db1 \
  --without-dbm \
  --without-tcadb \
  --without-cdb \
  --without-enchant \
  --without-gettext \
  --without-gmp \
  --without-mhash \
  --without-imap \
  --without-imap-ssl \
  --without-oci8 \
  --without-odbcver \
  --without-adabas \
  --without-sapdb \
  --without-solid \
  --without-ibm-db2 \
  --without-empress \
  --without-empress-bcs \
  --without-custom-odbc \
  --without-iodbc \
  --without-esoob \
  --without-unixODBC \
  --without-dbmaker \
  --without-pdo-dblib \
  --without-pdo-firebird \
  --without-pdo-mysql \
  --without-pdo-oci \
  --without-pdo-odbc \
  --without-pdo-sqlite \
  --without-pgsql \
  --without-pspell \
  --without-libedit \
  --without-readline \
  --without-mm \
  --without-snmp \
  --without-tidy \
  --without-xmlrpc \
  --without-xsl \
  --without-pear \
  --without-tsrm-pth \
  --without-tsrm-st \
  --without-tsrm-pthreads \
  CPPFLAGS="-I%{prefix}/include" LD_LIBRARY_PATH="%{prefix}/lib" LD_RUN_PATH="%{prefix}/lib" PKG_CONFIG_PATH="%{prefix}/lib/pkgconfig" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/httpd/conf
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/httpd/php/etc
cp %{prefix}/httpd/conf/httpd.conf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf
cp ${RPM_BUILD_ROOT}/../../SOURCES/php-fpm.conf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/etc

INSTALL_ROOT=${RPM_BUILD_ROOT} make install

cp %{_builddir}/php-%{php_version}/php.ini-production ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Reduce information leakage by default
sed -ri 's/^\s*expose_php\s*=.*/expose_php = Off/g' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Increase the php memory limit so that Mission Portal works with larger infrastructures without modification
sed -ri 's/^\s*memory_limit\s*=.*/memory_limit = 256M/g' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Set the default timezone for php
sed -ri 's/^(\s|;)*date.timezone\s*=.*/date.timezone = "UTC"/g' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Set the phar readonly Off for php
sed -ri 's/^(\s|;)phar.readonly = On/phar.readonly = Off/' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

echo "extension=curl.so" >> ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/curl.ini
echo "extension=openssl.so" >>${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/openssl.ini
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php/.channels
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php/.depdb
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php/.depdblock
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php/.filemap
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php/.lock
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php/.registry
rm -rf ${RPM_BUILD_ROOT}/.channels
rm -rf ${RPM_BUILD_ROOT}/.depdb
rm -rf ${RPM_BUILD_ROOT}/.depdblock
rm -rf ${RPM_BUILD_ROOT}/.filemap
rm -rf ${RPM_BUILD_ROOT}/.lock
rm -rf ${RPM_BUILD_ROOT}/.registry

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- php -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- php

%description devel
CFEngine Build Automation -- php -- development files

%files
%defattr(-,root,root)

%dir %prefix/httpd/php
%prefix/httpd/php/lib
%prefix/httpd/php/bin
%prefix/httpd/php/php
%prefix/httpd/php/etc
%prefix/httpd/php/sbin


%files devel
%defattr(-,root,root)

%dir %prefix/httpd/php
%prefix/httpd/php/include

%changelog







