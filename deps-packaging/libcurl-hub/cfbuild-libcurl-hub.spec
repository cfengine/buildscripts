%define curl_version 8.12.1

Summary: CFEngine Build Automation -- libcurl
Name: cfbuild-libcurl-hub
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
    --without-axtls \
    --without-cyassl \
    --without-egd-socket \
    --without-gnutls \
    --without-gssapi \
    --without-libidn \
    --without-libpsl \
    --without-librtmp \
    --without-libssh2 \
    --without-nghttp2 \
    --without-nss \
    --without-polarssl \
    --without-winidn \
    --without-winssl \
    --prefix=%{prefix} \
    CPPFLAGS="-I%{prefix}/include" \
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






