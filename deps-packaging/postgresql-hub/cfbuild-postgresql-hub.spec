Summary: CFEngine Build Automation -- postgresql
Name: cfbuild-postgresql
Version: %{version}
Release: 1
Source0: postgresql-9.4.5.tar.gz
Source1: postgresql.conf.cfengine
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n postgresql-9.4.5

%build

SYS=`uname -s`

LD_LIBRARY_PATH=%{prefix}/lib CPPFLAGS=-I%{prefix}/include ./configure --prefix=%{prefix} --without-zlib --without-readline --with-openssl

if [ -z $MAKE ]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

$MAKE
$MAKE -C contrib

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE install DESTDIR=${RPM_BUILD_ROOT}
$MAKE -C contrib install DESTDIR=${RPM_BUILD_ROOT}
cp ${RPM_BUILD_ROOT}/../../SOURCES/postgresql.conf.cfengine ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- postgresql

%package devel
Summary: CFEngine Build Automation -- postgresql -- development files
Group: Other
AutoReqProv: no
%description devel
CFEngine Build Automation -- postgresql -- dev files

%package libs
Summary: CFEngine Build Automation -- postgresql -- libraries
Group: Other
AutoReqProv: no
%description libs
CFEngine Build Automation -- postgresql -- libraries

%package server
Summary: CFEngine Build Automation -- postgresql -- server files
Group: Other
AutoReqProv: no
%description server
CFEngine Build Automation -- postgresql -- server files

%package contrib
Summary: CFEngine Build Automation -- postgresql -- contrib
Group: Other
AutoReqProv: no
%description contrib
CFEngine Build Automation -- postgresql -- contrib

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/clusterdb
%{prefix}/bin/createdb
%{prefix}/bin/createlang
%{prefix}/bin/createuser
%{prefix}/bin/dropdb
%{prefix}/bin/droplang
%{prefix}/bin/dropuser
%{prefix}/bin/pg_basebackup
%{prefix}/bin/pg_config
%{prefix}/bin/pg_dump
%{prefix}/bin/pg_dumpall
%{prefix}/bin/pg_isready
%{prefix}/bin/pg_receivexlog
%{prefix}/bin/pg_restore
%{prefix}/bin/psql
%{prefix}/bin/reindexdb
%{prefix}/bin/vacuumdb
%{prefix}/bin/initdb
%{prefix}/bin/pg_controldata
%{prefix}/bin/pg_ctl
%{prefix}/bin/pg_resetxlog
%{prefix}/bin/postgres
%{prefix}/bin/postmaster
%{prefix}/bin/pg_test_timing
%{prefix}/bin/pg_standby
%{prefix}/bin/pg_archivecleanup
%{prefix}/bin/oid2name
%{prefix}/bin/pg_upgrade
%{prefix}/bin/pg_xlogdump
%{prefix}/bin/pgbench
%{prefix}/bin/vacuumlo
%{prefix}/bin/pg_test_fsync
%{prefix}/bin/pg_recvlogical

#%dir %{prefix}/share/postgresql/tsearch_data
#%{prefix}/share/postgresql/tsearch_data/*

%dir %{prefix}/lib
%{prefix}/lib/libecpg_compat.so.3
%{prefix}/lib/libecpg_compat.so.3.6
%{prefix}/lib/libecpg.so
%{prefix}/lib/libecpg.so.6
%{prefix}/lib/libecpg.so.6.6
%{prefix}/lib/libpgtypes.so.3
%{prefix}/lib/libpgtypes.so.3.5
%{prefix}/lib/libpq.so.5
%{prefix}/lib/libpq.so.5.7
%{prefix}/lib/libpgtypes.so
%{prefix}/lib/libpq.so
%{prefix}/lib/libecpg_compat.so

%dir %{prefix}/lib/postgresql
%{prefix}/lib/postgresql/libpqwalreceiver.so

%dir %{prefix}/lib/postgresql
%{prefix}/lib/postgresql/*.so

%dir %{prefix}/share/postgresql
%{prefix}/share/postgresql/*.*

%dir %{prefix}/share/postgresql/timezonesets
%{prefix}/share/postgresql/timezonesets/*

%dir %{prefix}/share/postgresql/timezone
%{prefix}/share/postgresql/timezone/*

%dir %{prefix}/share/postgresql/extension
%{prefix}/share/postgresql/extension/*

%dir %{prefix}/share/postgresql/tsearch_data
%{prefix}/share/postgresql/tsearch_data/*

%dir %{prefix}/share/doc/postgresql/extension
%{prefix}/share/doc/postgresql/extension/*

%changelog

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*

%dir %{prefix}/bin
%{prefix}/bin/ecpg

%dir %{prefix}/lib
%{prefix}/lib/libecpg.a
%{prefix}/lib/libecpg_compat.a
%{prefix}/lib/libpgcommon.a
%{prefix}/lib/libpgport.a
%{prefix}/lib/libpgtypes.a
%{prefix}/lib/libpq.a

%dir %{prefix}/lib/postgresql/pgxs
%{prefix}/lib/postgresql/pgxs/*

%dir %{prefix}/lib/pkgconfig
%{prefix}/lib/pkgconfig/*
