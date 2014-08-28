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

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n php-5.1.6/ext/mcrypt

%build

phpize
./configure --with-mcrypt=%{prefix} --prefix=%{prefix} LDFLAGS="-L/var/cfengine/lib" CPPFLAGS="-I/var/cfengine/include" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

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
