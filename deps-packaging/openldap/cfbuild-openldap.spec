Summary: CFEngine Build Automation -- openldap
Name: cfbuild-openldap
Version: %{version}
Release: 1
Source0: openldap-2.4.23.tgz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n openldap-2.4.23

LDFLAGS=-L%{buildprefix}/lib
CPPFLAGS=-I%{buildprefix}/include

#
# glibc-2.8 errorneously hides peercred(3) under #ifdef __USE_GNU.
#
# Remove this after decomissioning all glibc-2.8-based distributions
# (e.g. SLES 11).
#
CPPFLAGS="$CPPFLAGS -D_GNU_SOURCE"

SYS=`uname -s`

if [ $SYS = "AIX" ]; then
    cd /var/cfengine/lib
    sudo ar qv libssl.a libssl.so
    sudo ar qv libcrypto.a libcrypto.so
    cd -
fi
./configure --prefix=%{prefix} \
            --enable-shared \
            --disable-slapd \
            --disable-backends \
            --with-tls=openssl \
            --without-gssapi \
            LDFLAGS="$LDFLAGS" \
            CPPFLAGS="$CPPFLAGS"

%build

if [ -z $MAKE ]; then
    MAKE_PATH=`which MAKE`
    export MAKE=$MAKE_PATH
fi    

$MAKE -C include
$MAKE -C libraries

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE -C include install DESTDIR=${RPM_BUILD_ROOT}

if [ $SYS = "AIX" ]; then
sudo cp ./libraries/liblber/.libs/liblber.a /var/cfengine/lib
$MAKE -C libraries install DESTDIR=${RPM_BUILD_ROOT}
sudo rm -f /var/cfengine/lib/liblber.a
else
$MAKE -C libraries install DESTDIR=${RPM_BUILD_ROOT}
fi

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/etc
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.la

if [ $SYS = "AIX" ]; then
    sudo rm /var/cfengine/lib/libssl.a
    sudo rm /var/cfengine/lib/libcrypto.a
fi
%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- openldap -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- openldap

%description devel
CFEngine Build Automation -- openldap -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/*.so.*

%files devel
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/*.so

%changelog
