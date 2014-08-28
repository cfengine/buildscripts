Summary: CFEngine Build Automation -- php-mongo
Name: cfbuild-php-mongo
Version: %{version}
Release: 1
Source0: mongo-1.2.6.tgz
Source1: mongo.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n mongo-1.2.6

%build

phpize
./configure --prefix=%{prefix}

make

%install
rm -rf ${RPM_BUILD_ROOT}

EXTDIR=$(php-config --extension-dir)

make install INSTALL_ROOT=${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/php
mv ${RPM_BUILD_ROOT}/${EXTDIR}/mongo.so ${RPM_BUILD_ROOT}%{prefix}/lib/php
rmdir --ignore-fail-on-non-empty -p ${RPM_BUILD_ROOT}/${EXTDIR}
cp %SOURCE1 ${RPM_BUILD_ROOT}%{prefix}/lib/php

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- php-mongo

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/mongo.so
%{prefix}/lib/php/mongo.ini

%changelog
