Summary: CFEngine Build Automation -- automake
Name: cfbuild-automake
Version: 1.10.1
Release: 1
Source0: automake-1.10.1.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-1.10.1-buildroot

AutoReqProv: no

%prep
mkdir -p %{_builddir}
%setup -q -n automake-1.10.1

CFLAGS="$CFLAGS -ggdb3" ./configure --prefix=/usr

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}/usr/share/doc
rm -rf ${RPM_BUILD_ROOT}/usr/share/info

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- automake

%files
%defattr(-,root,root)

%dir /usr/bin
/usr/bin/aclocal
/usr/bin/aclocal-1.10
/usr/bin/automake
/usr/bin/automake-1.10

%dir /usr/share
/usr/share/aclocal-1.10
/usr/share/automake-1.10

%changelog
