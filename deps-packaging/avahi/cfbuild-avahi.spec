Summary: CFEngine Build Automation -- avahi
Name: cfbuild-avahi
Version: 0.6.31
Release: 31
Source0: avahi-0.6.31.tar.gz
License: LGPL
Group: Other
Url: http://avahi.org/
BuildRoot: %{_topdir}/BUILD/%{name}-0.6.31-buildroot

AutoReqProv: no

%prep
mkdir -p %{_builddir}
%setup -q -n avahi-0.6.31

%build

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}/usr/include/avahi-client
for i in client.h lookup.h publish.h;
do
  cp avahi-client/$i ${RPM_BUILD_ROOT}/usr/include/avahi-client
done

mkdir -p ${RPM_BUILD_ROOT}/usr/include/avahi-common
for i in address.h  alternative.h  cdecl.h  defs.h  domain.h  error.h  gccmacro.h  llist.h  malloc.h  rlist.h  simple-watch.h  strlst.h  thread-watch.h  timeval.h  watch.h;
do
  cp avahi-common/$i ${RPM_BUILD_ROOT}/usr/include/avahi-common
done

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- avahi

%files
%defattr(-,root,root)

%dir /usr/include/avahi-client
/usr/include/avahi-client/client.h  
/usr/include/avahi-client/lookup.h  
/usr/include/avahi-client/publish.h

%dir /usr/include/avahi-common
/usr/include/avahi-common/address.h  
/usr/include/avahi-common/alternative.h  
/usr/include/avahi-common/cdecl.h  
/usr/include/avahi-common/defs.h  
/usr/include/avahi-common/domain.h  
/usr/include/avahi-common/error.h  
/usr/include/avahi-common/gccmacro.h  
/usr/include/avahi-common/llist.h  
/usr/include/avahi-common/malloc.h  
/usr/include/avahi-common/rlist.h  
/usr/include/avahi-common/simple-watch.h  
/usr/include/avahi-common/strlst.h  
/usr/include/avahi-common/thread-watch.h  
/usr/include/avahi-common/timeval.h  
/usr/include/avahi-common/watch.h

%changelog
