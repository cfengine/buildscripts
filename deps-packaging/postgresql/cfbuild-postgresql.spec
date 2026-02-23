%define postgresql_version 18.2

Summary: CFEngine Build Automation -- postgresql
Name: cfbuild-postgresql
Version: %{version}
Release: 1
Source0: postgresql-%{postgresql_version}.tar.bz2
Source1: postgresql.conf.cfengine.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n postgresql-%{postgresql_version}

%build

SYS=`uname -s`

LD_LIBRARY_PATH=%{prefix}/lib CPPFLAGS=-I%{prefix}/include ./configure --prefix=%{prefix} --without-zlib --without-readline --with-openssl --without-icu

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
patch -d ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/ -o postgresql.conf.cfengine < ${RPM_BUILD_ROOT}/../../SOURCES/postgresql.conf.cfengine.patch
patch ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.sample ${RPM_BUILD_ROOT}/../../SOURCES/postgresql.conf.sample.patch
chmod --reference ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.sample ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.cfengine
chown --reference ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.sample ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.cfengine
patch ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/pg_hba.conf.sample ${RPM_BUILD_ROOT}/../../SOURCES/pg_hba.conf.sample.patch
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.a

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

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/clusterdb
%{prefix}/bin/createdb
%{prefix}/bin/createuser
%{prefix}/bin/dropdb
%{prefix}/bin/dropuser
%{prefix}/bin/initdb
%{prefix}/bin/oid2name
%{prefix}/bin/pg_amcheck
%{prefix}/bin/pg_archivecleanup
%{prefix}/bin/pg_basebackup
%{prefix}/bin/pg_checksums
%{prefix}/bin/pg_combinebackup
%{prefix}/bin/pg_config
%{prefix}/bin/pg_controldata
%{prefix}/bin/pg_createsubscriber
%{prefix}/bin/pg_ctl
%{prefix}/bin/pg_dump
%{prefix}/bin/pg_dumpall
%{prefix}/bin/pg_isready
%{prefix}/bin/pg_receivewal
%{prefix}/bin/pg_recvlogical
%{prefix}/bin/pg_resetwal
%{prefix}/bin/pg_restore
%{prefix}/bin/pg_rewind
%{prefix}/bin/pg_test_fsync
%{prefix}/bin/pg_test_timing
%{prefix}/bin/pg_upgrade
%{prefix}/bin/pg_verifybackup
%{prefix}/bin/pg_waldump
%{prefix}/bin/pg_walsummary
%{prefix}/bin/pgbench
%{prefix}/bin/postgres
%{prefix}/bin/psql
%{prefix}/bin/reindexdb
%{prefix}/bin/vacuumdb
%{prefix}/bin/vacuumlo
%{prefix}/lib/libecpg.so*
%{prefix}/lib/libecpg_compat.so*
%{prefix}/lib/libpgtypes.so*
%{prefix}/lib/libpq.so*
%{prefix}/lib/postgresql/*.so
%{prefix}/share/doc/postgresql/*
%{prefix}/share/postgresql/*

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*

%dir %{prefix}/bin
%{prefix}/bin/ecpg

%dir %{prefix}/lib/postgresql/pgxs
%{prefix}/lib/postgresql/pgxs/*

%dir %{prefix}/lib/pkgconfig
%{prefix}/lib/pkgconfig/*

%changelog






