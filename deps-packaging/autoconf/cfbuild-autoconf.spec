Summary: CFEngine Build Automation -- autoconf
Name: cfbuild-autoconf
Version: 2.71
Release: 1
Source0: autoconf-2.71.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-2.71-buildroot

AutoReqProv: no

%prep
mkdir -p %{_builddir}
%setup -q -n autoconf-2.71

./configure --prefix=/usr

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
