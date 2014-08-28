Summary: CFEngine Build Automation -- mongo-c
Name: cfbuild-mongo-c-devel
Version: %{version}
Release: 1
Source0: v0.3.1.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine
%define srcdir mongo-c-driver-0.3.1

%prep
mkdir -p %{_builddir}
%setup -q -n %{srcdir}

%build

SOURCE="src/md5.c src/mongo.c src/gridfs.c src/bson.c src/numbers.c"
gcc -c -std=c99 -pedantic -Wall -g -fPIC -O3 -Isrc $SOURCE
ar rc libmongoc.a md5.o mongo.o gridfs.o bson.o numbers.o
ranlib libmongoc.a
ar rc libbson.a md5.o bson.o numbers.o
ranlib libbson.a

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/include

cp %{_builddir}/%{srcdir}/libmongoc.a ${RPM_BUILD_ROOT}%{prefix}/lib
cp %{_builddir}/%{srcdir}/libbson.a ${RPM_BUILD_ROOT}%{prefix}/lib

cp %{_builddir}/%{srcdir}/src/bson.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/mongo_except.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/mongo.h ${RPM_BUILD_ROOT}%{prefix}/include
cp %{_builddir}/%{srcdir}/src/platform_hacks.h ${RPM_BUILD_ROOT}%{prefix}/include

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
%{prefix}/include/mongo_except.h
%{prefix}/include/mongo.h
%{prefix}/include/platform_hacks.h

%changelog
