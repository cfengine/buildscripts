%define acl_version 2.2.53

Summary: CFEngine Build Automation -- libacl
Name: cfbuild-libacl
Version: %{version}
Release: 1
Source: acl-%{acl_version}.tar.gz
Patch0: no_fancy_gcc.patch
License: MIT
Group: Other
Url: http://example.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n acl-%{acl_version}

%patch0 -p1
./configure --prefix=%{prefix} --enable-gettext=no

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

cp ${RPM_BUILD_ROOT}%{prefix}/include/sys/acl.h ${RPM_BUILD_ROOT}%{prefix}/include/

rm -rf ${RPM_BUILD_ROOT}%{prefix}/share
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig
find ${RPM_BUILD_ROOT}%{prefix}/bin/ -mindepth 1 -name 'getfacl' -o -print0 | xargs -0 rm -rf

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libacl development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libacl

%description devel
CFEngine Build Automation -- libacl devel

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/getfacl

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%prefix/include

%dir %prefix/lib
%prefix/lib/*.so

%changelog
