%global debug_package %{nil}
%global __strip /bin/true
%global _enable_debug_packages 0
Summary: CFEngine Build Automation -- autoconf
Name: cfbuild-autoconf
Version: 2.69
Release: 1
Source0: autoconf-2.69.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-2.60-buildroot

AutoReqProv: no

%prep
mkdir -p %{_builddir}
%setup -q -n autoconf-2.60

CFLAGS="$CFLAGS -ggdb3" ./configure --prefix=/usr

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}/usr/share/info
rm -rf ${RPM_BUILD_ROOT}/usr/share/emacs
rm -rf ${RPM_BUILD_ROOT}/usr/share/man

%clean
rm -rf $RPM_BUILD_ROOT

%description 
CFEngine Build Automation -- autoconf

%files
%defattr(-,root,root)

%dir /usr/bin
/usr/bin/autoconf
/usr/bin/autoheader
/usr/bin/autom4te
/usr/bin/autoreconf
/usr/bin/autoscan
/usr/bin/autoupdate
/usr/bin/ifnames

%dir /usr/share
/usr/share/autoconf

%changelog
