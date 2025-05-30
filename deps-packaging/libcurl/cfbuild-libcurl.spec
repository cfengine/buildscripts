%define curl_version 8.14.1

Summary: CFEngine Build Automation -- libcurl
Name: cfbuild-libcurl
Version: %{version}
Release: 1
Source: curl-%{curl_version}.tar.gz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n curl-%{curl_version}

# we don't bundle OpenSSL on RHEL 8 (and newer in the future)
%if %{?rhel}%{!?rhel:0} > 7
%define ssl_prefix /usr
%else
%define ssl_prefix %{prefix}
%endif

./configure \
    --with-sysroot=%{prefix} \
    --with-ssl=%{ssl_prefix} \
    --with-zlib=%{prefix} \
    --disable-ldap \
    --disable-ldaps \
    --disable-ntlm \
    --without-gnutls \
    --without-gssapi \
    --without-libpsl \
    --without-librtmp \
    --without-libssh2 \
    --without-nghttp2 \
    --without-winidn \
    --prefix=%{prefix} \
    CPPFLAGS="-I%{prefix}/include -DAF_LOCAL=AF_UNIX" \
    LD_LIBRARY_PATH="%{prefix}/lib" \
    LD_RUN_PATH="%{prefix}/lib"

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
%prefix/bin/wcurl

%dir %prefix/lib
%prefix/lib/*.so*

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/curl-config

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so
%prefix/lib/pkgconfig

%changelog
