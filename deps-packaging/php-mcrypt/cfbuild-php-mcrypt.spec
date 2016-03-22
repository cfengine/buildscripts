Summary: CFEngine Build Automation -- php-mcrypt
Name: cfbuild-php-mcrypt
Version: %{version}
Release: 1
Source0: php-5.1.6.tar.gz
Source1: mcrypt.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n php-5.1.6/ext/mcrypt

%build

%{prefix}/httpd/php/bin/phpize
./configure --with-mcrypt=%{prefix} --prefix=%{prefix}

make 

%install
rm -rf ${RPM_BUILD_ROOT}

EXTDIR=$(php-config --extension-dir)
make install INSTALL_ROOT=${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/php
mv ${RPM_BUILD_ROOT}/${EXTDIR}/mcrypt.so ${RPM_BUILD_ROOT}%{prefix}/lib/php
rmdir --ignore-fail-on-non-empty -p ${RPM_BUILD_ROOT}/${EXTDIR}
cp %SOURCE1 ${RPM_BUILD_ROOT}%{prefix}/lib/php

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- php-mcrypt

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/mcrypt.so
%{prefix}/lib/php/mcrypt.ini

%changelog
