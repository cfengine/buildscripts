Summary: CFEngine Build Automation -- mongo-c
Name: cfbuild-mongo-c-new-devel
Version: %{version}
Release: 1
Source0: v0.6.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine
%define srcdir mongodb-mongo-c-driver-013fe75

%prep
mkdir -p %{_builddir}
%setup -q -n %{srcdir}

%build

SOURCE="src/md5.c src/mongo.c src/gridfs.c src/bson.c src/numbers.c src/env_posix.c src/encoding.c"
gcc -c -std=c99 -pedantic -Wall -g -fPIC -O3 -D_POSIX_SOURCE -Isrc $SOURCE
ar rc libmongoc.a md5.o mongo.o env_posix.o gridfs.o bson.o numbers.o encoding.o
ranlib libmongoc.a
ar rc libbson.a md5.o bson.o numbers.o encoding.o
ranlib libbson.a

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/include

cp %{_builddir}/%{srcdir}/libmongoc.a ${RPM_BUILD_ROOT}%{prefix}/lib
cp %{_builddir}/%{srcdir}/libbson.a ${RPM_BUILD_ROOT}%{prefix}/lib

cp %{_builddir}/%{srcdir}/src/bson.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/encoding.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/mongo.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/env.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/gridfs.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/md5.h ${RPM_BUILD_ROOT}%{prefix}/include

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- mongo-c -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%{prefix}/lib/libmongoc.a
%{prefix}/lib/libbson.a

%dir %prefix/include
%{prefix}/include/bson.h
%{prefix}/include/encoding.h
%{prefix}/include/mongo.h
%{prefix}/include/env.h
%{prefix}/include/gridfs.h
%{prefix}/include/md5.h

%changelog
