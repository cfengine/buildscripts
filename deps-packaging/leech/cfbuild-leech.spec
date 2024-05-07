%define leech_version 0.1.19

Summary: CFEngine Build Automation -- leech
Name: cfbuild-leech
Version: %{version}
Release: 1
Source0: leech-%{leech_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n leech-%{leech_version}

# Touch this file, or else autoreconf is called for some reason
touch config.h.in
./configure --prefix=%{prefix}

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.la

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

%dir %prefix/lib
%prefix/lib/*.so.*
%prefix/lib/*.so

%files devel
%defattr(-,root,root)

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so

%changelog




