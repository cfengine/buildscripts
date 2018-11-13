%define openssl_version 1.1.0i

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

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n openssl-%{openssl_version}

%build

if [ -z "$MAKE" ]
then
    export MAKE=`which make`
fi

SYS=`uname -s`


echo ==================== BUILD_TYPE is $BUILD_TYPE ====================

test -d /var/cfengine || ( sudo mkdir /var/cfengine && sudo chmod 777 /var/cfengine )
mkdir -p /var/cfengine/include

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

# Work around platform-specific issues
HACK_FLAGS=
if [ $OS = centos ]  ||  [ $OS = rhel ]
then
    if [ `echo $OS_VERSION | cut -d. -f1` = 4 ]
    then
        HACK_FLAGS=-D_GNU_SOURCE                              # CentOS 4 issue
    fi
fi

./config shared  no-idea no-rc5 no-ssl3 no-dtls no-psk no-srp no-engine \
         $DEBUG_CONFIG_FLAGS \
         --prefix=%{prefix} \
         $HACK_FLAGS   \
         $DEBUG_CFLAGS \
         $LDFLAGS

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

$MAKE DESTDIR=${RPM_BUILD_ROOT} install_sw
$MAKE DESTDIR=${RPM_BUILD_ROOT} install_ssldirs

# Removing unused files

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/c_rehash

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libssl.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libcrypto.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig/openssl.pc
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/misc/CA.pl
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/misc/tsget
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/openssl.cnf.dist

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
%{prefix}/lib/libssl.so.1.1
%{prefix}/lib/libcrypto.so
%{prefix}/lib/libcrypto.so.1.1
%{prefix}/ssl/openssl.cnf

%files devel
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/libssl.so
%{prefix}/lib/libcrypto.so

%{prefix}/lib/pkgconfig

%changelog
