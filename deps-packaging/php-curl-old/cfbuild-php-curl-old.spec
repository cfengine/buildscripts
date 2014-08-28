Summary: CFEngine Build Automation -- php-curl-old
Name: cfbuild-php-curl-old
Version: %{version}
Release: 1
Source0: php-5.2.1.tar.gz
Source1: curl.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n php-5.2.1/ext/curl

%build

phpize
./configure --with-curl=%{prefix} --prefix=%{prefix}

make 

%install
rm -rf ${RPM_BUILD_ROOT}

EXTDIR=$(php-config --extension-dir)
make install INSTALL_ROOT=${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/php
mv ${RPM_BUILD_ROOT}/${EXTDIR}/curl.so ${RPM_BUILD_ROOT}%{prefix}/lib/php
rmdir --ignore-fail-on-non-empty -p ${RPM_BUILD_ROOT}/${EXTDIR}
cp %SOURCE1 ${RPM_BUILD_ROOT}%{prefix}/lib/php

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- php-curl-old

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/curl.so
%{prefix}/lib/php/curl.ini

%changelog
