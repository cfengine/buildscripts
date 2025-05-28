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

# we don't bundle OpenSSL on RHEL 8 (and newer in the future)
%if %{?rhel}%{!?rhel:0} > 7
CPPFLAGS=-I%{buildprefix}/include:/usr/include
%else
CPPFLAGS=-I%{buildprefix}/include
%endif

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




