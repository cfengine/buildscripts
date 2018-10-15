%define attr_version 2.4.48

Summary: CFEngine Build Automation -- libattr
Name: cfbuild-libattr
Version: %{version}
Release: 1
Source: attr-%{attr_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}
%define incldir /usr/include

%prep
mkdir -p %{_builddir}
%setup -q -n attr-%{attr_version}

zcat ../../SOURCES/attr.destdir.diff.gz | $PATCH -p1 || true

./configure --prefix=%{prefix} --includedir=%{incldir} --enable-gettext=no

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install-dev DESTDIR=${RPM_BUILD_ROOT}
make install-lib DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -rf ${RPM_BUILD_ROOT}%{prefix}/libexec
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libattr development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libattr

%description devel
CFEngine Build Automation -- libattr devel

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%incldir/attr

%dir %prefix/lib
%prefix/lib/*.so

%changelog 
