%define coreutils_version 9.11

Summary: CFEngine Build Automation -- coreutils (date)
Name: cfbuild-coreutils
Version: %{version}
Release: 1
Source0: coreutils-%{coreutils_version}.tar.xz
Patch0: 0001-Guard-pwd.h-and-grp.h-includes-in-idcache.c-and-use.patch
License: GPL3
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n coreutils-%{coreutils_version}

%patch0 -p1

cp %{_sourcedir}/built-sources.mk .

FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=%{prefix}

%build

# We only need the "date" binary out of the whole coreutils suite, so
# generate the gnulib-derived BUILT_SOURCES (configmake.h, version.h etc)
# and then build just that one target instead of "make all".
BUILT_SOURCES=$(make -s -f built-sources.mk print-built-sources)
make $BUILT_SOURCES
make src/date

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/bin
install -m 755 src/date ${RPM_BUILD_ROOT}%{prefix}/bin/date

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- coreutils (date)

%files
%defattr(755,root,root)
%dir %prefix/bin
%prefix/bin/date

%changelog
