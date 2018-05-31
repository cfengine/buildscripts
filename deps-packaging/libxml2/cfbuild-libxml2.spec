%global debug_package %{nil}
%global __strip /bin/true
%global _enable_debug_packages 0
%define libxml_version 2.9.8

Summary: CFEngine Build Automation -- libxml2
Name: cfbuild-libxml2
Version: %{version}
Release: 1
Source0: libxml2-%{libxml_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n libxml2-%{libxml_version}

SYS=`uname -s`
if [ "z$SYS" = "zAIX" ]
then
    ${PATCH} -p0 < ../../SOURCES/aix-nan.patch
fi

if expr \( "z$SYS" = 'zAIX' \) \| \( "`cat /etc/redhat-release`" : '.* 4\.' \)
then
    mv configure configure.bak
    sed 's/ *-Wno-array-bounds//' configure.bak >configure
    chmod a+x configure
fi
CFLAGS="$CFLAGS -ggdb3" ./configure --prefix=%{prefix} --without-python --enable-shared --disable-static --with-zlib=%{prefix} \
    CPPFLAGS="-I%{prefix}/include" \
    LD_LIBRARY_PATH="%{prefix}/lib" LD_RUN_PATH="%{prefix}/lib"

%build
make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/xmlcatalog
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/xmllint
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libxml2.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libxml2.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/xml2Conf.sh
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/cmake
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libxml2 -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libxml2

%description devel
CFEngine Build Automation -- libxml2 -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*
%prefix/lib/*.so

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/xml2-config

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so
%prefix/lib/pkgconfig

%changelog
