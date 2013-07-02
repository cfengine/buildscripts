Summary: CFEngine Build Automation -- postgresql
Name: cfbuild-postgresql
Version: %{version}
Release: 1
Source0: postgresql-9.0.4.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n postgresql-9.0.4

%build

# zlib??

# Build just the libpq library, we don't need the whole server.

./configure --prefix=%{prefix} --without-zlib --without-readline

make -C src/bin/pg_config
make -C src/backend ../../src/include/utils/fmgroids.h
make -C src/interfaces/libpq

%install
rm -rf ${RPM_BUILD_ROOT}

make install -C src/bin/pg_config DESTDIR=${RPM_BUILD_ROOT}
make install -C src/include DESTDIR=${RPM_BUILD_ROOT}
make install -C src/interfaces/libpq DESTDIR=${RPM_BUILD_ROOT}

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
