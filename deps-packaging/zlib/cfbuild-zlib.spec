Summary: CFEngine Build Automation -- zlib
Name: cfbuild-zlib
Version: %{version}
Release: 1
Source0: zlib-1.2.5.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n zlib-1.2.5

%build

./configure --prefix=%{prefix}

make
%if %{?with_testsuite:1}%{!?with_testsuite:0}
make check
%endif

%install
rm -rf ${RPM_BUILD_ROOT}

make install prefix=${RPM_BUILD_ROOT}%{prefix}

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
%{prefix}/lib/libz.so.1
%{prefix}/lib/libz.so.1.2.5

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%dir %{prefix}/lib
%{prefix}/lib/libz.so

%dir %{prefix}/lib/pkgconfig
%{prefix}/lib/pkgconfig/zlib.pc

%changelog
