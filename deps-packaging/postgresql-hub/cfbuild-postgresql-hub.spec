%define postgresql_version 9.3.23

Summary: CFEngine Build Automation -- postgresql
Name: cfbuild-postgresql
Version: %{version}
Release: 1
Source0: postgresql-%{postgresql_version}.tar.gz
Source1: postgresql.conf.cfengine
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

#%dir %{prefix}/share/postgresql/tsearch_data
#%{prefix}/share/postgresql/tsearch_data/*

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

%files libs
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/libecpg_compat.so.3
%{prefix}/lib/libecpg_compat.so.3.5
%{prefix}/lib/libecpg.so
%{prefix}/lib/libecpg.so.6
%{prefix}/lib/libecpg.so.6.5
%{prefix}/lib/libpgtypes.so.3
%{prefix}/lib/libpgtypes.so.3.4
%{prefix}/lib/libpq.so.5
%{prefix}/lib/libpq.so.5.6
%{prefix}/lib/libpgtypes.so
%{prefix}/lib/libpq.so
%{prefix}/lib/libecpg_compat.so

%dir %{prefix}/lib/postgresql
%{prefix}/lib/postgresql/libpqwalreceiver.so

%files server
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/initdb
%{prefix}/bin/pg_controldata
%{prefix}/bin/pg_ctl
%{prefix}/bin/pg_resetxlog
%{prefix}/bin/postgres
%{prefix}/bin/postmaster

%dir %{prefix}/lib/postgresql
%{prefix}/lib/postgresql/ascii_and_mic.so
%{prefix}/lib/postgresql/cyrillic_and_mic.so
%{prefix}/lib/postgresql/dict_snowball.so
%{prefix}/lib/postgresql/euc2004_sjis2004.so
%{prefix}/lib/postgresql/euc_cn_and_mic.so
%{prefix}/lib/postgresql/euc_jp_and_sjis.so
%{prefix}/lib/postgresql/euc_kr_and_mic.so
%{prefix}/lib/postgresql/euc_tw_and_big5.so
%{prefix}/lib/postgresql/latin2_and_win1250.so
%{prefix}/lib/postgresql/latin_and_mic.so
%{prefix}/lib/postgresql/plpgsql.so
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
%{prefix}/lib/postgresql/utf8_and_iso8859_1.so
%{prefix}/lib/postgresql/utf8_and_iso8859.so
%{prefix}/lib/postgresql/utf8_and_johab.so
%{prefix}/lib/postgresql/utf8_and_sjis2004.so
%{prefix}/lib/postgresql/utf8_and_sjis.so
%{prefix}/lib/postgresql/utf8_and_uhc.so
%{prefix}/lib/postgresql/utf8_and_win.so
%{prefix}/lib/postgresql/sslinfo.so

%dir %{prefix}/share/postgresql
%{prefix}/share/postgresql/conversion_create.sql
%{prefix}/share/postgresql/information_schema.sql
%{prefix}/share/postgresql/pg_hba.conf.sample
%{prefix}/share/postgresql/pg_ident.conf.sample
%{prefix}/share/postgresql/pg_service.conf.sample
%{prefix}/share/postgresql/postgres.bki
%{prefix}/share/postgresql/postgres.description
%{prefix}/share/postgresql/postgresql.conf.sample
%{prefix}/share/postgresql/postgresql.conf.cfengine
%{prefix}/share/postgresql/postgres.shdescription
%{prefix}/share/postgresql/psqlrc.sample
%{prefix}/share/postgresql/recovery.conf.sample
%{prefix}/share/postgresql/snowball_create.sql
%{prefix}/share/postgresql/sql_features.txt
%{prefix}/share/postgresql/system_views.sql

%dir %{prefix}/share/postgresql/timezonesets
%{prefix}/share/postgresql/timezonesets/*

%dir %{prefix}/share/postgresql/timezone
%{prefix}/share/postgresql/timezone/*

%dir %{prefix}/share/postgresql/extension
%{prefix}/share/postgresql/extension/plpgsql.control
%{prefix}/share/postgresql/extension/plpgsql--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/plpgsql--1.0.sql
%{prefix}/share/postgresql/extension/sslinfo--1.0.sql
%{prefix}/share/postgresql/extension/sslinfo--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/sslinfo.control
%{prefix}/share/postgresql/extension/citext--1.0--1.1.sql
%{prefix}/share/postgresql/extension/citext--1.1--1.0.sql
%{prefix}/share/postgresql/extension/citext--1.1.sql

%dir %{prefix}/share/postgresql/tsearch_data
%{prefix}/share/postgresql/tsearch_data/*

%files contrib
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/pg_test_timing
%{prefix}/bin/pg_standby
%{prefix}/bin/pg_archivecleanup
%{prefix}/bin/oid2name
%{prefix}/bin/pg_upgrade
%{prefix}/bin/pg_xlogdump
%{prefix}/bin/pgbench
%{prefix}/bin/vacuumlo
%{prefix}/bin/pg_test_fsync

%dir %{prefix}/share/doc/postgresql/extension
%{prefix}/share/doc/postgresql/extension/refint.example
%{prefix}/share/doc/postgresql/extension/autoinc.example
%{prefix}/share/doc/postgresql/extension/moddatetime.example
%{prefix}/share/doc/postgresql/extension/insert_username.example
%{prefix}/share/doc/postgresql/extension/timetravel.example

%dir %{prefix}/share/postgresql/extension
%{prefix}/share/postgresql/extension/hstore--1.1--1.2.sql
%{prefix}/share/postgresql/extension/pg_buffercache.control
%{prefix}/share/postgresql/extension/fuzzystrmatch.control
%{prefix}/share/postgresql/extension/dblink--1.0--1.1.sql
%{prefix}/share/postgresql/extension/unaccent.control
%{prefix}/share/postgresql/extension/intarray--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/insert_username--1.0.sql
%{prefix}/share/postgresql/extension/chkpass--1.0.sql
%{prefix}/share/postgresql/extension/pg_buffercache--1.0.sql
%{prefix}/share/postgresql/extension/pg_freespacemap.control
%{prefix}/share/postgresql/extension/intarray.control
%{prefix}/share/postgresql/extension/cube--1.0.sql
%{prefix}/share/postgresql/extension/isn--1.0.sql
%{prefix}/share/postgresql/extension/test_parser--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/pgcrypto--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/dblink--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/ltree--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/cube.control
%{prefix}/share/postgresql/extension/tcn--1.0.sql
%{prefix}/share/postgresql/extension/pgstattuple--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/adminpack.control
%{prefix}/share/postgresql/extension/pgrowlocks--1.0--1.1.sql
%{prefix}/share/postgresql/extension/pgrowlocks--1.1.sql
%{prefix}/share/postgresql/extension/btree_gin--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/tcn.control
%{prefix}/share/postgresql/extension/btree_gist--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/btree_gin--1.0.sql
%{prefix}/share/postgresql/extension/intagg.control
%{prefix}/share/postgresql/extension/chkpass--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/hstore--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/file_fdw.control
%{prefix}/share/postgresql/extension/pg_stat_statements--1.1.sql
%{prefix}/share/postgresql/extension/dict_xsyn.control
%{prefix}/share/postgresql/extension/insert_username.control
%{prefix}/share/postgresql/extension/autoinc--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/moddatetime--1.0.sql
%{prefix}/share/postgresql/extension/refint--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/earthdistance--1.0.sql
%{prefix}/share/postgresql/extension/adminpack--1.0.sql
%{prefix}/share/postgresql/extension/pg_trgm--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/lo--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/dblink.control
%{prefix}/share/postgresql/extension/pageinspect--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/timetravel.control
%{prefix}/share/postgresql/extension/dict_int.control
%{prefix}/share/postgresql/extension/citext--1.0.sql
%{prefix}/share/postgresql/extension/unaccent--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/fuzzystrmatch--1.0.sql
%{prefix}/share/postgresql/extension/pg_trgm--1.1.sql
%{prefix}/share/postgresql/extension/hstore--1.2.sql
%{prefix}/share/postgresql/extension/hstore.control
%{prefix}/share/postgresql/extension/tsearch2.control
%{prefix}/share/postgresql/extension/earthdistance.control
%{prefix}/share/postgresql/extension/earthdistance--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/dict_xsyn--1.0.sql
%{prefix}/share/postgresql/extension/autoinc--1.0.sql
%{prefix}/share/postgresql/extension/pgstattuple--1.0--1.1.sql
%{prefix}/share/postgresql/extension/moddatetime.control
%{prefix}/share/postgresql/extension/tsearch2--1.0.sql
%{prefix}/share/postgresql/extension/tablefunc--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/tablefunc--1.0.sql
%{prefix}/share/postgresql/extension/fuzzystrmatch--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/intagg--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/autoinc.control
%{prefix}/share/postgresql/extension/ltree--1.0.sql
%{prefix}/share/postgresql/extension/moddatetime--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/pg_buffercache--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/unaccent--1.0.sql
%{prefix}/share/postgresql/extension/pgcrypto.control
%{prefix}/share/postgresql/extension/cube--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/dict_int--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/lo.control
%{prefix}/share/postgresql/extension/pgcrypto--1.0.sql
%{prefix}/share/postgresql/extension/ltree.control
%{prefix}/share/postgresql/extension/tablefunc.control
%{prefix}/share/postgresql/extension/pgrowlocks--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/pg_freespacemap--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/test_parser--1.0.sql
%{prefix}/share/postgresql/extension/intagg--1.0.sql
%{prefix}/share/postgresql/extension/pg_trgm--1.0--1.1.sql
%{prefix}/share/postgresql/extension/pageinspect--1.0--1.1.sql
%{prefix}/share/postgresql/extension/refint--1.0.sql
%{prefix}/share/postgresql/extension/seg--1.0.sql
%{prefix}/share/postgresql/extension/dblink--1.1.sql
%{prefix}/share/postgresql/extension/pg_freespacemap--1.0.sql
%{prefix}/share/postgresql/extension/pageinspect.control
%{prefix}/share/postgresql/extension/insert_username--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/pgstattuple.control
%{prefix}/share/postgresql/extension/timetravel--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/pgstattuple--1.1.sql
%{prefix}/share/postgresql/extension/refint.control
%{prefix}/share/postgresql/extension/pgrowlocks.control
%{prefix}/share/postgresql/extension/btree_gin.control
%{prefix}/share/postgresql/extension/isn.control
%{prefix}/share/postgresql/extension/chkpass.control
%{prefix}/share/postgresql/extension/lo--1.0.sql
%{prefix}/share/postgresql/extension/pg_stat_statements.control
%{prefix}/share/postgresql/extension/pg_stat_statements--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/timetravel--1.0.sql
%{prefix}/share/postgresql/extension/isn--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/intarray--1.0.sql
%{prefix}/share/postgresql/extension/hstore--1.0--1.1.sql
%{prefix}/share/postgresql/extension/seg--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/postgres_fdw--1.0.sql
%{prefix}/share/postgresql/extension/pg_trgm.control
%{prefix}/share/postgresql/extension/file_fdw--1.0.sql
%{prefix}/share/postgresql/extension/pageinspect--1.1.sql
%{prefix}/share/postgresql/extension/postgres_fdw.control
%{prefix}/share/postgresql/extension/test_parser.control
%{prefix}/share/postgresql/extension/btree_gist--1.0.sql
%{prefix}/share/postgresql/extension/citext--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/citext.control
%{prefix}/share/postgresql/extension/dict_int--1.0.sql
%{prefix}/share/postgresql/extension/seg.control
%{prefix}/share/postgresql/extension/tsearch2--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/btree_gist.control
%{prefix}/share/postgresql/extension/dict_xsyn--unpackaged--1.0.sql
%{prefix}/share/postgresql/extension/pg_stat_statements--1.0--1.1.sql

%dir %{prefix}/lib/postgresql
%{prefix}/lib/postgresql/pg_upgrade_support.so
%{prefix}/lib/postgresql/btree_gist.so
%{prefix}/lib/postgresql/citext.so
%{prefix}/lib/postgresql/pgstattuple.so
%{prefix}/lib/postgresql/hstore.so
%{prefix}/lib/postgresql/file_fdw.so
%{prefix}/lib/postgresql/_int.so
%{prefix}/lib/postgresql/dict_int.so
%{prefix}/lib/postgresql/pg_freespacemap.so
%{prefix}/lib/postgresql/lo.so
%{prefix}/lib/postgresql/timetravel.so
%{prefix}/lib/postgresql/postgres_fdw.so
%{prefix}/lib/postgresql/chkpass.so
%{prefix}/lib/postgresql/fuzzystrmatch.so
%{prefix}/lib/postgresql/pg_stat_statements.so
%{prefix}/lib/postgresql/autoinc.so
%{prefix}/lib/postgresql/passwordcheck.so
%{prefix}/lib/postgresql/refint.so
%{prefix}/lib/postgresql/insert_username.so
%{prefix}/lib/postgresql/unaccent.so
%{prefix}/lib/postgresql/tcn.so
%{prefix}/lib/postgresql/ltree.so
%{prefix}/lib/postgresql/worker_spi.so
%{prefix}/lib/postgresql/pageinspect.so
%{prefix}/lib/postgresql/tsearch2.so
%{prefix}/lib/postgresql/earthdistance.so
%{prefix}/lib/postgresql/dummy_seclabel.so
%{prefix}/lib/postgresql/pg_trgm.so
%{prefix}/lib/postgresql/btree_gin.so
%{prefix}/lib/postgresql/isn.so
%{prefix}/lib/postgresql/test_parser.so
%{prefix}/lib/postgresql/seg.so
%{prefix}/lib/postgresql/pg_buffercache.so
%{prefix}/lib/postgresql/dict_xsyn.so
%{prefix}/lib/postgresql/pgcrypto.so
%{prefix}/lib/postgresql/moddatetime.so
%{prefix}/lib/postgresql/auto_explain.so
%{prefix}/lib/postgresql/auth_delay.so
%{prefix}/lib/postgresql/adminpack.so
%{prefix}/lib/postgresql/cube.so
%{prefix}/lib/postgresql/tablefunc.so
%{prefix}/lib/postgresql/dblink.so
%{prefix}/lib/postgresql/pgrowlocks.so
%changelog

