Summary: CFEngine Build Automation -- pcre
Name: cfbuild-pcre
Version: %{version}
Release: 1
Source0: pcre-8.12.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n pcre-8.12

./configure --prefix=%{prefix} --enable-unicode-properties --disable-cpp

%build

make
%if %{?with_testsuite:1}%{!?with_testsuite:0}
make check
%endif

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/pcregrep
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/pcretest
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpcre.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpcre.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpcreposix.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpcreposix.la
# Do not merge those lines into single one -- any new file in share should trigger an error
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/man
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/doc
rmdir ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- pcre -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- pcre

%description devel
CFEngine Build Automation -- pcre -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/libpcre.so.0
%prefix/lib/libpcre.so.0.0.1
%prefix/lib/libpcreposix.so.0
%prefix/lib/libpcreposix.so.0.0.0

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/pcre-config

%dir %prefix/include
%prefix/include/pcre.h
%prefix/include/pcreposix.h

%dir %prefix/lib
%prefix/lib/libpcre.so
%prefix/lib/libpcreposix.so

%dir %prefix/lib/pkgconfig
%prefix/lib/pkgconfig/libpcre.pc
%prefix/lib/pkgconfig/libpcreposix.pc

%changelog
