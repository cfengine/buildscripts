%define librsync_version 2.3.4

Summary: CFEngine Build Automation -- librsync
Name: cfbuild-librsync
Version: %{version}
Release: 1
Source0: librsync-%{librsync_version}.tar.gz
License: LGPL
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n librsync-%{librsync_version}
for i in %{_topdir}/SOURCES/00*.patch; do
    $PATCH -p1 < $i
done

# Set correct file permissions after patching files into existence.
chmod +x ar-lib compile config.guess config.sub configure depcomp \
    install-sh libtool ltmain.sh missing

# Make sure timestamps are correct after patching files into existence

touch -t 0001010100 configure.ac
touch -t 0001010100 Makefile.am
touch -t 0001010100 m4/lt~obsolete.m4
touch -t 0001010100 m4/ltversion.m4
touch -t 0001010100 m4/ltsugar.m4
touch -t 0001010100 m4/ltoptions.m4
touch -t 0001010100 m4/libtool.m4

touch -t 0001010101 aclocal.m4
touch -t 0001010101 config.guess
touch -t 0001010101 config.sub
touch -t 0001010101 ltmain.sh
touch -t 0001010101 Makefile.in
touch -t 0001010101 install-sh
touch -t 0001010101 missing
touch -t 0001010101 depcomp
touch -t 0001010101 config.hin

touch -t 0001010102 configure
touch -t 0001010102 libtool
touch -t 0001010102 compile
touch -t 0001010102 ar-lib

./configure --prefix=%{prefix} --enable-shared --disable-static

rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/librsync.a

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/librsync.la

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- librsync -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- librsync

%description devel
CFEngine Build Automation -- librsync -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/*.so*

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%dir %{prefix}/lib
%{prefix}/lib/pkgconfig

%changelog
