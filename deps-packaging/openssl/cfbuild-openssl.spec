%define fips_version 1.2.2

Summary: CFEngine Build Automation -- openssl
Name: cfbuild-openssl
Version: %{version}
Release: 1
Source0: openssl-0.9.8r.tar.gz
Source1: openssl-fips-%{fips_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

Patch0: aix-ar-arguments.patch

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -a1 -n openssl-0.9.8r
%if "%{_os}" == "aix"
%patch0 -p1
%endif

%build

if [ -z $MAKE]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

SYS=`uname -s`
VER=`uname -v`

cd openssl-fips-%{fips_version}
if [ $SYS = "AIX" ]; then
./Configure aix-gcc fipscanisterbuild no-asm
/usr/bin/patch -p1 < ../../../SOURCES/makefile.fips.aix.patch

if [ $VER = "6" ]; then
RM='rm -f'
fi
else
./config fipscanisterbuild no-asm
fi

$MAKE
cd ..

if [ $SYS = "AIX" ]; then
./Configure aix-gcc --with-fipslibdir=%{_builddir}/openssl-0.9.8r/openssl-fips-%{fips_version}/fips shared --prefix=%{prefix}

if [ $VER = "6" ]; then
/usr/bin/patch -p1 < ../../SOURCES/makefile.openssl.aix6.patch
else
/usr/bin/patch -p1 < ../../SOURCES/makefile.openssl.aix.patch
fi

$MAKE
else
./config fips --with-fipslibdir=%{_builddir}/openssl-0.9.8r/openssl-fips-%{fips_version}/fips \
         shared --prefix=%{prefix}
$MAKE SHARED_LDFLAGS="${SHARED_LDFLAGS} -L%{prefix}/lib -Wl,-rpath %{prefix}/lib"
fi

# ECDSA/ECDH tests are broken, so we explicitly omit them

if ! [ $SYS = "AIX" ]; then
%if %{?with_testsuite:1}%{!?with_testsuite:0}
$MAKE test TESTS="test_des test_idea test_sha test_md4 test_md5 test_hmac test_md2 test_mdc2 test_rmd test_rc2 test_rc4 test_rc5 test_bf test_cast test_aes test_rand test_bn test_ec test_enc test_x509 test_rsa test_crl test_sid test_gen test_req test_pkcs7 test_verify test_dh test_dsa test_ss test_ca test_engine test_evp test_ssl test_ige test_jpake"
%endif
fi

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE INSTALL_PREFIX=${RPM_BUILD_ROOT} install_sw

# Removing unused files

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/c_rehash
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/openssl

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libssl.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libcrypto.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/engines
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig/openssl.pc

rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/certs
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/private
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/openssl.cnf
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/misc

rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/fipsld
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/fips_premain.c
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/fips_premain.c.sha1
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/fipscanister.o
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/fipscanister.o.sha1

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

%dir %{prefix}/lib
%{prefix}/lib/libssl.so
%{prefix}/lib/libssl.so.0.9.8
%{prefix}/lib/libcrypto.so
%{prefix}/lib/libcrypto.so.0.9.8

%files devel
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/libssl.so
%{prefix}/lib/libcrypto.so

%{prefix}/lib/pkgconfig

%changelog
