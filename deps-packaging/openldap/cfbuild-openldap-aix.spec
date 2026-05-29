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
%patch1 -p1
%patch2 -p1
%patch3 -p1
%patch4 -p1

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
