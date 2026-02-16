%define expat_version 2.7.4

Summary: CFEngine Build Automation -- libexpat
Name: cfbuild-libexpat
Version: %{version}
Release: 1
Source0: expat-%{expat_version}.tar.xz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n expat-%{expat_version}

CFLAGS="-fPIC -DPIC" ./configure --prefix=%{prefix} --without-examples --without-tests --without-xmlwf --enable-static=no --enable-shared=yes

%build

make

%install

rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/cmake
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libexpat -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libexpat

%description devel
CFEngine Build Automation -- libexpat -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so*

%files devel
%defattr(-,root,root)

%prefix/include
%dir %prefix/lib
%prefix/lib/pkgconfig

%changelog
