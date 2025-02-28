%define apr_version 1.6.3

Summary: CFEngine Build Automation -- apr-util
Name: cfbuild-apr-util
Version: %{version}
Release: 1
Source0: apr-util-%{apr_version}.tar.gz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n apr-util-%{apr_version}

CPPFLAGS=-I%{buildprefix}/include

#
# glibc-2.8 errorneously hides peercred(3) under #ifdef __USE_GNU.
#
# Remove this after decomissioning all glibc-2.8-based distributions
# (e.g. SLES 11).
#
CPPFLAGS="$CPPFLAGS -D_GNU_SOURCE"

SYS=`uname -s`

./configure --prefix=%{prefix}  --with-apr=%{prefix} --with-ldap-lib=%{prefix}/lib --with-ldap \
            CPPFLAGS="$CPPFLAGS"

%build

if [ -z $MAKE ]; then
    MAKE_PATH=`which MAKE`
    export MAKE=$MAKE_PATH
fi    

$MAKE

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE install DESTDIR=${RPM_BUILD_ROOT}
$MAKE install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/etc
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/apr-util-1/*.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/apr-util-1/*.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.exp
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- apr-util -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- apr-util

%description devel
CFEngine Build Automation -- apr -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/*.so.*
%{prefix}/lib/apr-util-1/*.so
%{prefix}/bin/apu*

%files devel
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/*.so

%changelog
