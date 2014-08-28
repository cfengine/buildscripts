Summary: CFEngine Build Automation -- php-svn
Name: cfbuild-php-svn
Version: %{version}
Release: 1
Source0: svn-1.0.1.tgz
Source1: svn.ini
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n svn-1.0.1

%build

phpize
./configure --prefix=%{prefix} CPPFLAGS="-I/var/cfengine/include" LDFLAGS="-L/var/cfengine/lib" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

make

%install
rm -rf ${RPM_BUILD_ROOT}

EXTDIR=$(php-config --extension-dir)

make install INSTALL_ROOT=${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/php
mv ${RPM_BUILD_ROOT}/${EXTDIR}/svn.so ${RPM_BUILD_ROOT}%{prefix}/lib/php
rmdir --ignore-fail-on-non-empty -p ${RPM_BUILD_ROOT}/${EXTDIR}
cp %SOURCE1 ${RPM_BUILD_ROOT}%{prefix}/lib/php

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- php-svn

%files
%defattr(-,root,root)

%dir %{prefix}/lib/php
%{prefix}/lib/php/svn.so
%{prefix}/lib/php/svn.ini

%changelog
