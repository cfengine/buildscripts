Summary: CFEngine Build Automation -- php-json
Name: cfbuild-php-json
Version: %{version}
Release: 1
Source0: json-1.2.1.tgz
Source1: json.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n json-1.2.1

%build

%{prefix}/httpd/php/bin/phpize
./configure --prefix=%{prefix}

make 

%install
rm -rf ${RPM_BUILD_ROOT}

EXTDIR=$(php-config --extension-dir)

make install INSTALL_ROOT=${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/php
mv ${RPM_BUILD_ROOT}/${EXTDIR}/json.so ${RPM_BUILD_ROOT}%{prefix}/lib/php
rmdir --ignore-fail-on-non-empty -p ${RPM_BUILD_ROOT}/${EXTDIR}
cp %SOURCE1 ${RPM_BUILD_ROOT}%{prefix}/lib/php

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- php-json

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/json.so
%{prefix}/lib/php/json.ini

%changelog
