%define postgresql_version 10.6

Summary: CFEngine Build Automation -- postgresql
Name: cfbuild-postgresql
Version: %{version}
Release: 1
Source0: postgresql-%{postgresql_version}.tar.gz
Source1: postgresql.conf.cfengine.patch
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n postgresql-%{postgresql_version}

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
patch -d ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/ -o postgresql.conf.cfengine < ${RPM_BUILD_ROOT}/../../SOURCES/postgresql.conf.cfengine.patch
chmod --reference ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.sample ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.cfengine
chown --reference ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.sample ${RPM_BUILD_ROOT}%{prefix}/share/postgresql/postgresql.conf.cfengine

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
%{prefix}/bin/pg_archivecleanup
%{prefix}/bin/pg_basebackup
%{prefix}/bin/pg_config
%{prefix}/bin/pg_controldata
%{prefix}/bin/pg_ctl
%{prefix}/bin/pg_dump
%{prefix}/bin/pg_dumpall
%{prefix}/bin/pg_isready
%{prefix}/bin/pg_receivewal
%{prefix}/bin/pg_recvlogical
%{prefix}/bin/pg_resetwal
%{prefix}/bin/pg_restore
%{prefix}/bin/pg_rewind
%{prefix}/bin/pg_standby
%{prefix}/bin/pg_test_fsync
%{prefix}/bin/pg_test_timing
%{prefix}/bin/pg_upgrade
%{prefix}/bin/pg_waldump
%{prefix}/bin/pgbench
%{prefix}/bin/postgres
%{prefix}/bin/postmaster
%{prefix}/bin/psql
%{prefix}/bin/reindexdb
%{prefix}/bin/vacuumdb
%{prefix}/bin/vacuumlo
%{prefix}/lib/libecpg.so*
%{prefix}/lib/libecpg_compat.so*
%{prefix}/lib/libpgtypes.so*
%{prefix}/lib/libpq.so*
%{prefix}/lib/postgresql/_int.so
%{prefix}/lib/postgresql/adminpack.so
%{prefix}/lib/postgresql/amcheck.so
%{prefix}/lib/postgresql/ascii_and_mic.so
%{prefix}/lib/postgresql/auth_delay.so
%{prefix}/lib/postgresql/auto_explain.so
%{prefix}/lib/postgresql/autoinc.so
%{prefix}/lib/postgresql/bloom.so
%{prefix}/lib/postgresql/btree_gin.so
%{prefix}/lib/postgresql/btree_gist.so
%{prefix}/lib/postgresql/chkpass.so
%{prefix}/lib/postgresql/citext.so
%{prefix}/lib/postgresql/cube.so
%{prefix}/lib/postgresql/cyrillic_and_mic.so
%{prefix}/lib/postgresql/dblink.so
%{prefix}/lib/postgresql/dict_int.so
%{prefix}/lib/postgresql/dict_snowball.so
%{prefix}/lib/postgresql/dict_xsyn.so
%{prefix}/lib/postgresql/earthdistance.so
%{prefix}/lib/postgresql/euc2004_sjis2004.so
%{prefix}/lib/postgresql/euc_cn_and_mic.so
%{prefix}/lib/postgresql/euc_jp_and_sjis.so
%{prefix}/lib/postgresql/euc_kr_and_mic.so
%{prefix}/lib/postgresql/euc_tw_and_big5.so
%{prefix}/lib/postgresql/file_fdw.so
%{prefix}/lib/postgresql/fuzzystrmatch.so
%{prefix}/lib/postgresql/hstore.so
%{prefix}/lib/postgresql/insert_username.so
%{prefix}/lib/postgresql/isn.so
%{prefix}/lib/postgresql/latin2_and_win1250.so
%{prefix}/lib/postgresql/latin_and_mic.so
%{prefix}/lib/postgresql/libpqwalreceiver.so
%{prefix}/lib/postgresql/lo.so
%{prefix}/lib/postgresql/ltree.so
%{prefix}/lib/postgresql/moddatetime.so
%{prefix}/lib/postgresql/pageinspect.so
%{prefix}/lib/postgresql/passwordcheck.so
%{prefix}/lib/postgresql/pg_buffercache.so
%{prefix}/lib/postgresql/pg_freespacemap.so
%{prefix}/lib/postgresql/pg_prewarm.so
%{prefix}/lib/postgresql/pg_stat_statements.so
%{prefix}/lib/postgresql/pg_trgm.so
%{prefix}/lib/postgresql/pg_visibility.so
%{prefix}/lib/postgresql/pgcrypto.so
%{prefix}/lib/postgresql/pgoutput.so
%{prefix}/lib/postgresql/pgrowlocks.so
%{prefix}/lib/postgresql/pgstattuple.so
%{prefix}/lib/postgresql/plpgsql.so
%{prefix}/lib/postgresql/postgres_fdw.so
%{prefix}/lib/postgresql/refint.so
%{prefix}/lib/postgresql/seg.so
%{prefix}/lib/postgresql/sslinfo.so
%{prefix}/lib/postgresql/tablefunc.so
%{prefix}/lib/postgresql/tcn.so
%{prefix}/lib/postgresql/test_decoding.so
%{prefix}/lib/postgresql/timetravel.so
%{prefix}/lib/postgresql/tsm_system_rows.so
%{prefix}/lib/postgresql/tsm_system_time.so
%{prefix}/lib/postgresql/unaccent.so
%{prefix}/lib/postgresql/utf8_and_ascii.so
%{prefix}/lib/postgresql/utf8_and_big5.so
%{prefix}/lib/postgresql/utf8_and_cyrillic.so
%{prefix}/lib/postgresql/utf8_and_euc2004.so
%{prefix}/lib/postgresql/utf8_and_euc_cn.so
%{prefix}/lib/postgresql/utf8_and_euc_jp.so
%{prefix}/lib/postgresql/utf8_and_euc_kr.so
%{prefix}/lib/postgresql/utf8_and_euc_tw.so
%{prefix}/lib/postgresql/utf8_and_gb18030.so
%{prefix}/lib/postgresql/utf8_and_gbk.so
%{prefix}/lib/postgresql/utf8_and_iso8859.so
%{prefix}/lib/postgresql/utf8_and_iso8859_1.so
%{prefix}/lib/postgresql/utf8_and_johab.so
%{prefix}/lib/postgresql/utf8_and_sjis.so
%{prefix}/lib/postgresql/utf8_and_sjis2004.so
%{prefix}/lib/postgresql/utf8_and_uhc.so
%{prefix}/lib/postgresql/utf8_and_win.so
%{prefix}/share/doc/postgresql/*
%{prefix}/share/postgresql/*

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
%{prefix}/lib/libpgfeutils.a
%{prefix}/lib/libpgport.a
%{prefix}/lib/libpgtypes.a
%{prefix}/lib/libpq.a

%dir %{prefix}/lib/postgresql/pgxs
%{prefix}/lib/postgresql/pgxs/*

%dir %{prefix}/lib/pkgconfig
%{prefix}/lib/pkgconfig/*

%changelog
