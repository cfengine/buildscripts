%define php_version 5.4.38

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

./configure --prefix=%{prefix}/httpd/php --with-apxs2=%{prefix}/httpd/bin/apxs --with-config-file=%{prefix}/httpd/php   --with-openssl=shared,%{prefix} --with-config-file-scan-dir=%{prefix}/httpd/php/lib --with-libxml-dir=%{prefix} --with-curl=shared,%{prefix} --with-mcrypt=shared,%{prefix} --with-pdo --with-pdo-pgsql=%{prefix} --with-json LDFLAGS="-L/var/cfengine/lib -Wl,-R/var/cfengine/lib" CPPFLAGS="-I/var/cfengine/include" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/httpd/conf
cp %{prefix}/httpd/conf/httpd.conf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf

INSTALL_ROOT=${RPM_BUILD_ROOT} make install

cp %{_builddir}/php-%{php_version}/php.ini-production ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/php.ini
echo "extension=curl.so" >> ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/curl.ini
echo "extension=mcrypt.so" >> ${RPM_BUILD_ROOT}%{prefix}/httpd/php/lib/mcrypt.ini
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
%prefix/httpd/php/etc
%prefix/httpd/php/lib
%prefix/httpd/php/bin
%prefix/httpd/php/php
%prefix/httpd/php/lib/php.ini

%dir %prefix/httpd/modules
%prefix/httpd/modules/libphp5.so

%files devel
%defattr(-,root,root)

%dir %prefix/httpd/php
%prefix/httpd/php/include

%changelog
