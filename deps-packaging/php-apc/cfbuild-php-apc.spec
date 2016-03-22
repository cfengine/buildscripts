Summary: CFEngine Build Automation -- php-apc
Name: cfbuild-php-apc
Version: %{version}
Release: 1
Source0: APC-3.1.13.tgz
Source1: apc.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n APC-3.1.13

%build

%{prefix}/httpd/php/bin/phpize
./configure --prefix=%{prefix} --with-php-config=%{prefix}/httpd/php/bin/php-config LDFLAGS="-L%{prefix}/lib" CPPFLAGS="-I%{prefix}/include"

make

%install
rm -rf ${RPM_BUILD_ROOT}

EXTDIR=$(php-config --extension-dir)

make install INSTALL_ROOT=${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/php
mv ${RPM_BUILD_ROOT}/${EXTDIR}/apc.so ${RPM_BUILD_ROOT}%{prefix}/lib/php
rmdir --ignore-fail-on-non-empty -p ${RPM_BUILD_ROOT}/${EXTDIR}
rm -f ${RPM_BUILD_ROOT}%{prefix}/httpd/php/include/php/ext/apc/apc_serializer.h

cp %SOURCE1 ${RPM_BUILD_ROOT}%{prefix}/lib/php

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- php-apc

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/apc.so
%{prefix}/lib/php/apc.ini

%changelog
