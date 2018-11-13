%define php_version 7.2.12

Summary: CFEngine Build Automation -- php
Name: cfbuild-php
Version: %{version}
Release: 1
Source0: php-%{php_version}.tar.gz
Source1: php.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n php-%{php_version}

if expr "`cat /etc/redhat-release`" : '.* [5]\.'
then
  patch -p0 < %{_topdir}/SOURCES/old-gcc-isfinite.patch
fi

./configure --prefix=%{prefix}/httpd/php \
--with-apxs2=%{prefix}/httpd/bin/apxs \
--with-config-file=%{prefix}/httpd/php \
--with-openssl=shared,%{prefix} \
--with-config-file-scan-dir=%{prefix}/httpd/php/lib \
--with-libxml-dir=%{prefix} \
--with-curl=shared,%{prefix} \
--with-ldap=%{prefix} \
--with-pdo \
--with-pdo-pgsql=%{prefix} \
--with-json \
--with-iconv \
--without-aolserver \
--without-caudium \
--without-continuity \
--without-fpm-user \
--without-fpm-group \
--without-fpm-systemd \
--without-fpm-acl \
--without-isapi \
--without-litespeed \
--without-milter \
--without-nsapi \
--without-phttpd \
--without-pi3web \
--without-roxen \
--without-thttpd \
--without-tux \
--without-webjames \
--without-layout \
--without-sqlite3 \
--without-bz2 \
--without-qdbm \
--without-gdbm \
--without-ndbm \
--without-db4 \
--without-db3 \
--without-db2 \
--without-db1 \
--without-dbm \
--without-tcadb \
--without-cdb \
--without-enchant \
--without-gd \
--without-t1lib \
--without-gettext \
--without-gmp \
--without-mhash \
--without-imap \
--without-imap-ssl \
--without-interbase \
--without-icu-dir \
--without-libmbfl \
--without-onig \
--without-mssql \
--without-mysql \
--without-mysql-sock \
--without-mysqli \
--without-oci8 \
--without-odbcver \
--without-adabas \
--without-sapdb \
--without-solid \
--without-ibm-db2 \
--without-ODBCRouter \
--without-empress \
--without-empress-bcs \
--without-birdstep \
--without-custom-odbc \
--without-iodbc \
--without-esoob \
--without-unixODBC \
--without-dbmaker \
--without-pdo-dblib \
--without-pdo-firebird \
--without-pdo-mysql \
--without-pdo-oci \
--without-pdo-oci \
--without-pdo-oci \
--without-pdo-odbc \
--without-pdo-odbc \
--without-pdo-odbc \
--without-pdo-sqlite \
--without-pgsql \
--without-pspell \
--without-libedit \
--without-readline \
--without-recode \
--without-mm \
--without-snmp \
--without-sybase-ct \
--without-tidy \
--without-xmlrpc \
--without-xsl \
--without-libzip \
--without-pear \
--without-pear \
--without-zend-vm \
--without-tsrm-pth \
--without-tsrm-st \
--without-tsrm-pthreads \
CPPFLAGS="-I/var/cfengine/include" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/httpd/conf
cp %{prefix}/httpd/conf/httpd.conf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf

INSTALL_ROOT=${RPM_BUILD_ROOT} make install

cp %{_builddir}/php-%{php_version}/php.ini-production ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Reduce information leakage by default
sed -ri 's/^\s*expose_php\s*=.*/expose_php = Off/g' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Increase the php memory limit so that Mission Portal works with larger infrastructures without modification
sed -ri 's/^\s*memory_limit\s*=.*/memory_limit = 256M/g' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

# Set the default timezone for php
sed -ri 's/^(\s|;)*date.timezone\s*=.*/date.timezone = "UTC"/g' ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini

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
%prefix/httpd/php/lib/php.ini

%dir %prefix/httpd/modules
%prefix/httpd/modules/libphp7.so

%files devel
%defattr(-,root,root)

%dir %prefix/httpd/php
%prefix/httpd/php/include

%changelog

