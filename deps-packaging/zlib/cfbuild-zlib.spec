Summary: CFEngine Build Automation -- zlib
Name: cfbuild-zlib
Version: %{version}
Release: 1
Source0: zlib-1.3.2.tar.gz
Patch0: AIX_LDSHARED.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n zlib-1.3.2

%patch0 -p1

%build

if [ -z $MAKE ]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

./configure --prefix=%{prefix}

$MAKE

# $MAKE check doesn't work on AIX, see CFE-4092 for details
# %if %{?with_testsuite:1}%{!?with_testsuite:0}
# $MAKE check
# %endif

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE install prefix=${RPM_BUILD_ROOT}%{prefix}

rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libz.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/man
rmdir ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- zlib -- development files
Group: Other

AutoReqProv: no

%description
CFEngine Build Automation -- zlib

%description devel
CFEngine Build Automation -- zlib -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/libz.so
%{prefix}/lib/libz.so.1
%{prefix}/lib/libz.so.1.3.2

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%dir %{prefix}/lib/pkgconfig
%{prefix}/lib/pkgconfig/zlib.pc

%changelog
