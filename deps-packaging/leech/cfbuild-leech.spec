%define leech_version 0.2.0

Summary: CFEngine Build Automation -- leech
Name: cfbuild-leech
Version: %{version}
Release: 1
Source0: leech-%{leech_version}.tar.gz
License: LGPL
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n leech-%{leech_version}

./configure --prefix=%{prefix} --enable-shared --disable-static

rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libleech.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libleech.la

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- leech -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- leech

%description devel
CFEngine Build Automation -- leech -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/*.so*

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%dir %{prefix}/lib
%{prefix}/lib/*.la

%changelog
