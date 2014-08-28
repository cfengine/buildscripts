Summary: CFEngine Build Automation -- php-curl
Name: cfbuild-php-curl
Version: %{version}
Release: 1
Source0: php-5.3.3.tar.gz
Source1: curl.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n php-5.3.3/ext/curl

%build

phpize
./configure --with-curl=%{prefix} --prefix=%{prefix} LDFLAGS="-L/var/cfengine/lib" CPPFLAGS="-I/var/cfengine/include" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

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
CFEngine Build Automation -- php-curl

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/curl.so
%{prefix}/lib/php/curl.ini

%changelog
