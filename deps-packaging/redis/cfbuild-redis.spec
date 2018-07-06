Summary: CFEngine Build Automation -- redis
Name: cfbuild-redis
Version: %{version}
Release: 1
Source0: redis-3.2.12.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%ifarch %ix86
%define lbits %{nil}
%else
%define lbits %{nil}
%endif

%prep
mkdir -p %{_builddir}

%setup -q -n redis-3.2.12
$PATCH -s -p1 < %{_topdir}/SOURCES/redis.patch

%build

if [ -z $MAKE ]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

$MAKE
cd deps/hiredis && $MAKE dynamic

%install
PREFIX=%{prefix}

mkdir -p $RPM_BUILD_ROOT/$PREFIX/bin
mkdir -p $RPM_BUILD_ROOT/$PREFIX/lib%{lbits}
mkdir -p $RPM_BUILD_ROOT/$PREFIX/include/hiredis

cp -pf %{_builddir}/redis-*/src/redis-server     $RPM_BUILD_ROOT/$PREFIX/bin
cp -pf %{_builddir}/redis-*/src/redis-benchmark  $RPM_BUILD_ROOT/$PREFIX/bin
cp -pf %{_builddir}/redis-*/src/redis-cli        $RPM_BUILD_ROOT/$PREFIX/bin
cp -pf %{_builddir}/redis-*/src/redis-check-aof  $RPM_BUILD_ROOT/$PREFIX/bin

cp -a %{_builddir}/redis-*/deps/hiredis/hiredis.h %{_builddir}/redis-*/deps/hiredis/async.h %{_builddir}/redis-*/deps/hiredis/adapters $RPM_BUILD_ROOT/$PREFIX/include/hiredis
cp -a %{_builddir}/redis-*/deps/hiredis/libhiredis.so $RPM_BUILD_ROOT/$PREFIX/lib%{lbits}/libhiredis.so.0.11
cd $RPM_BUILD_ROOT/$PREFIX/lib%{lbits} && ln -sf libhiredis.so.0.11 libhiredis.so.0
cd $RPM_BUILD_ROOT/$PREFIX/lib%{lbits} && ln -sf libhiredis.so.0 libhiredis.so
cp -a %{_builddir}/redis-*/deps/hiredis/libhiredis.a $RPM_BUILD_ROOT/$PREFIX/lib%{lbits}

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- redis -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- redis

%description devel
CFEngine Build Automation -- redis -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/redis-cli
%{prefix}/bin/redis-server
%{prefix}/bin/redis-check-aof
%{prefix}/bin/redis-benchmark

%dir %{prefix}/lib%{lbits}
%{prefix}/lib%{lbits}/libhiredis.so*

%files devel
%defattr(-,root,root)

%dir %{prefix}/lib%{lbits}
%{prefix}/lib%{lbits}/libhiredis.a

%dir %{prefix}/include/hiredis
%{prefix}/include/hiredis/hiredis.h
%{prefix}/include/hiredis/async.h

%dir %{prefix}/include/hiredis/adapters
%{prefix}/include/hiredis/adapters/ae.h
%{prefix}/include/hiredis/adapters/libev.h
%{prefix}/include/hiredis/adapters/libuv.h
%{prefix}/include/hiredis/adapters/libevent.h

%changelog

