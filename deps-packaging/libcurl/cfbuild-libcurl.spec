%define curl_version 7.61.0

Summary: CFEngine Build Automation -- libcurl
Name: cfbuild-libcurl
Version: %{version}
Release: 1
Source: curl-%{curl_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n curl-%{curl_version}

./configure --with-sysroot=%{prefix} --with-ldap-lib=libldap-2.4.so.2 --with-lber-lib=liblber-2.4.so.2 --with-ssl=%{prefix} --with-zlib=%{prefix} --prefix=%{prefix} CPPFLAGS="-I/var/cfengine/include" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

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

%dir %prefix/bin
%prefix/bin/curl

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/curl-config

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so
%prefix/lib/pkgconfig

%changelog

