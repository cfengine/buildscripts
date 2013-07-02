Summary: CFEngine Build Automation -- libcurl
Name: cfbuild-libcurl
Version: %{version}
Release: 1
Source: curl-7.27.0.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n curl-7.27.0

./configure --with-sysroot=%{prefix} --with-ldap-lib=libldap-2.4.so.2 --with-lber-lib=liblber-2.4.so.2 --with-ssl=%{prefix} --with-zlib=%{prefix} --prefix=%{prefix}

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libcurl.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libcurl.la

%clean

rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libcurl -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libcurl

%description devel
CFEngine Build Automation -- libcurl

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/curl
%prefix/bin/curl-config

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so
%prefix/lib/pkgconfig

%changelog
