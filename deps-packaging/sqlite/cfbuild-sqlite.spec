Summary: CFEngine Build Automation -- sqlite
Name: cfbuild-sqlite
Version: %{version}
Release: 1
Source0: sqlite-autoconf-3071300.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine
%define srcdir sqlite-autoconf-3071300

%prep
mkdir -p %{_builddir}
%setup -q -n %{srcdir}

%build

./configure --prefix=/var/cfengine CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA"

make

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/include

cp %{_builddir}/%{srcdir}/.libs/libsqlite3.so ${RPM_BUILD_ROOT}%{prefix}/lib
cp %{_builddir}/%{srcdir}/.libs/libsqlite3.so.0 ${RPM_BUILD_ROOT}%{prefix}/lib
cp %{_builddir}/%{srcdir}/.libs/libsqlite3.so.0.8.6 ${RPM_BUILD_ROOT}%{prefix}/lib

cp %{_builddir}/%{srcdir}/sqlite3.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/sqlite3ext.h ${RPM_BUILD_ROOT}%{prefix}/include

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- sqlite development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- sqlite

%description devel
CFEngine Build Automation -- sqlite

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%prefix/include

%dir %prefix/lib
%prefix/lib/*.so

%changelog
