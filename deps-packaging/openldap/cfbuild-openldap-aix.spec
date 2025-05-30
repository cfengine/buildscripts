%define openldap_version 2.6.10

Summary: CFEngine Build Automation -- openldap
Name: cfbuild-openldap
Version: %{version}
Release: 1
Source0: openldap-%{openldap_version}.tgz
Patch0:  no_Sockaddr_redefine.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n openldap-%{openldap_version}

%patch0 -p0

# Either "$LDFLAGS -L%{prefix}lib"
# Or     "-bsvr4 $LDFLAGS -Wl,-R,%{prefix}/lib"
CPPFLAGS=-I%{buildprefix}/include

#
# glibc-2.8 errorneously hides peercred(3) under #ifdef __USE_GNU.
#
# Remove this after decomissioning all glibc-2.8-based distributions
# (e.g. SLES 11).
#
CPPFLAGS="$CPPFLAGS -D_GNU_SOURCE"

SYS=`uname -s`


./configure --prefix=%{prefix} \
            --enable-shared \
            --disable-slapd \
            --disable-backends \
            --with-tls=openssl \
            --without-gssapi \
            CPPFLAGS="$CPPFLAGS"

%build

if [ -z $MAKE ]; then
    MAKE_PATH=`which MAKE`
    export MAKE=$MAKE_PATH
fi

$MAKE -C include
$MAKE -C libraries

%install

$MAKE -C include install DESTDIR=${RPM_BUILD_ROOT}
sudo cp ./libraries/liblber/.libs/liblber.a %{prefix}/lib
sudo cp ./libraries/liblber/.libs/liblber.so %{prefix}/lib
$MAKE -C libraries install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/etc

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
%{prefix}/lib/*.a
%{prefix}/lib/*.la
%{prefix}/lib/*.so
%prefix/lib/*.so.*

%files devel
%defattr(-,root,root)

%{prefix}/include

%changelog
