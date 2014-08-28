Summary: CFEngine Build Automation -- libmcrypt
Name: cfbuild-libmcrypt
Version: %{version}
Release: 1
Source0: libmcrypt-2.5.8.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n libmcrypt-2.5.8

./configure --prefix=%{prefix} --disable-dependency-tracking

%build

make 

%install

rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libmcrypt/
rm -f  ${RPM_BUILD_ROOT}%{prefix}/lib/libmcrypt.la
rm -rf ${RPM_BUILD_ROOT}%{prefix}/man/
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libmcrypt -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libmcrypt

%description devel
CFEngine Build Automation -- libmcrypt -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/libmcrypt-config

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so

%changelog
