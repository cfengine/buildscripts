%define openssl_version 1.0.2e

Summary: CFEngine Build Automation -- openssl
Name: cfbuild-openssl
Version: %{version}
Release: 1
Source0: openssl-%{openssl_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

Patch0: honor-LDFLAGS.patch

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n openssl-%{openssl_version}

%patch0 -p1

%build

if [ -z "$MAKE" ]
then
    export MAKE=`which make`
fi

SYS=`uname -s`


echo ==================== BUILD_TYPE is $BUILD_TYPE ====================

    DEBUG_CONFIG_FLAGS=
    DEBUG_CFLAGS=
    if [ $BUILD_TYPE = "DEBUG" ]
    then
        DEBUG_CONFIG_FLAGS="no-asm -DPURIFY"
        DEBUG_CFLAGS="-g2 -O1 -fno-omit-frame-pointer"
    # Workaround for OpenSSL build issue on our old SuSE buildslave, see:
    # http://www.mail-archive.com/openssl-dev@openssl.org/msg39231.html
    elif [ "$OS" = sles ]
    then
        DEBUG_CONFIG_FLAGS=no-asm
    fi

    ./config shared  no-idea no-rc5 no-ssl2 no-ssl3 no-dtls no-psk no-srp \
        $DEBUG_CONFIG_FLAGS \
        --prefix=%{prefix} \
        $DEBUG_CFLAGS

    # Remove -O3 and -fomit-frame-pointer from debug builds
    if [ $BUILD_TYPE = "DEBUG" ]
    then
        sed -e '/^CFLAG=/{s/ -O3//;s/ -fomit-frame-pointer//}'   \
            Makefile > Makefile.cfe \
            && mv Makefile.cfe Makefile
    fi

    $MAKE depend
    $MAKE

%if %{?with_testsuite:1}%{!?with_testsuite:0}
    $MAKE test
%endif


%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE INSTALL_PREFIX=${RPM_BUILD_ROOT} install_sw

# Removing unused files

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/c_rehash

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libssl.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libcrypto.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/engines
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig/openssl.pc

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- openssl -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- openssl

%description devel
CFEngine Build Automation -- openssl -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/openssl

%dir %{prefix}/lib
%{prefix}/lib/libssl.so
%{prefix}/lib/libssl.so.1.0.0
%{prefix}/lib/libcrypto.so
%{prefix}/lib/libcrypto.so.1.0.0

%dir %{prefix}/ssl
%{prefix}/ssl/openssl.cnf

%dir %{prefix}/ssl/certs
%dir %{prefix}/ssl/private
%dir %{prefix}/ssl/misc
%{prefix}/ssl/misc/CA.pl
%{prefix}/ssl/misc/CA.sh
%{prefix}/ssl/misc/c_hash
%{prefix}/ssl/misc/c_info
%{prefix}/ssl/misc/c_issuer
%{prefix}/ssl/misc/c_name
%{prefix}/ssl/misc/tsget


%files devel
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/libssl.so
%{prefix}/lib/libcrypto.so

%{prefix}/lib/pkgconfig

%changelog
