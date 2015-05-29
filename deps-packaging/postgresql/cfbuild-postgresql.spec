Summary: CFEngine Build Automation -- postgresql
Name: cfbuild-postgresql
Version: %{version}
Release: 1
Source0: postgresql-9.0.20.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n postgresql-9.0.20

%build

# zlib??

# Build just the libpq library, we don't need the whole server.

SYS=`uname -s`

if [ $SYS = "AIX" ]; then
  $PATCH -p1 < ../../SOURCES/makefile.aix.patch
fi

./configure --prefix=%{prefix} --without-zlib --without-readline --enable-shared

if [ -z $MAKE ]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

$MAKE -C src/bin/pg_config
$MAKE -C src/backend ../../src/include/utils/fmgroids.h
$MAKE -C src/interfaces/libpq

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE install -C src/bin/pg_config DESTDIR=${RPM_BUILD_ROOT}
$MAKE install -C src/include DESTDIR=${RPM_BUILD_ROOT}
$MAKE install -C src/interfaces/libpq DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/postgresql
rm -f ${RPM_BUILD_ROOT}%{prefix}/include/pg_config*.h
rm -rf ${RPM_BUILD_ROOT}%{prefix}/include/postgresql/server
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpq.a

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- postgresql -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- postgresql

%description devel
CFEngine Build Automation -- postgresql -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/libpq.so.5
%{prefix}/lib/libpq.so.5.3

%files devel
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/pg_config

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/libpq.so

%changelog
