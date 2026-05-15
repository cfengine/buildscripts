%define openldap_version 2.6.13

Summary: CFEngine Build Automation -- openldap
Name: cfbuild-openldap
Version: %{version}
Release: 1
Source0: openldap-%{openldap_version}.tgz
Patch0:  no_Sockaddr_redefine.patch
# patches for openssl 4.0.0 unavailable in a release as of 2.6.13
Patch1: f3b49ffa10d93e841d00f05d9f56b88078acf235.patch
Patch2: a599597cb3cb6d36f888bffcbd0b010a644b92c5.patch
Patch3: 75b624f47574dffb1f5041625cf9d6218dbcb07d.patch
Patch4: a704373426e37fd7f4e4beb3be451b5555799517.patch
Patch5: gcc-8.5.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n openldap-%{openldap_version}

%patch -P0 -p0
%patch -P1 -p1
%patch -P2 -p1
%patch -P3 -p1
%patch -P4 -p1
%patch -P5 -p1

CPPFLAGS=-I%{buildprefix}/include

#
# glibc-2.8 errorneously hides peercred(3) under #ifdef __USE_GNU.
#
# Remove this after decomissioning all glibc-2.8-based distributions
# (e.g. SLES 11).
#
CPPFLAGS="$CPPFLAGS -D_GNU_SOURCE"

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
rm -rf ${RPM_BUILD_ROOT}

$MAKE -C include install DESTDIR=${RPM_BUILD_ROOT}
$MAKE -C libraries install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/etc
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig/*.pc

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




