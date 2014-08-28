Summary: CFEngine Build Automation -- mysql
Name: cfbuild-mysql
Version: %{version}
Release: 1
Source0: mysql-5.1.53.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n mysql-5.1.53

%build

# FIXME: zlib?

./configure --prefix=%{prefix} --without-server --enable-shared --enable-thread-safe-client

for i in include zlib mysys libmysql libmysql_r scripts; do
   make -C $i
done

%install
rm -rf ${RPM_BUILD_ROOT}

for i in include libmysql libmysql_r scripts; do
    make -C $i install DESTDIR=${RPM_BUILD_ROOT}
done

mv ${RPM_BUILD_ROOT}%{prefix}/lib/mysql/libmysqlclient*.so* ${RPM_BUILD_ROOT}%{prefix}/lib

rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/msql2mysql
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_convert_table_format
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_find_rows
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_fix_extensions
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_fix_privilege_tables
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_secure_installation
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_setpermission
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysql_zap
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysqlaccess
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysqlbug
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysqld_multi
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysqldumpslow
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/mysqlhotcopy
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/mysql
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/mysql/libmysqlclient.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/mysql/libmysqlclient.la
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/mysql/libmysqlclient_r.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/mysql/libmysqlclient_r.la

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- mysql -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- mysql

%description devel
CFEngine Build Automation -- mysql -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/mysql_config

%dir %prefix/include
%prefix/include/mysql

%dir %prefix/lib
%prefix/lib/libmysqlclient.so
%prefix/lib/libmysqlclient_r.so

%changelog
