%define libxml_version 2.14.1

Summary: CFEngine Build Automation -- libxml2
Name: cfbuild-libxml2
Version: %{version}
Release: 1
Source0: libxml2-%{libxml_version}.tar.xz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
export PATH=/opt/freeware/bin:$PATH # to use newer version of tar on aix platform
# Note that we can't change $PATH globally for all dependencies, since it breaks
# openssl: `ar` in /opt/freeware/bin exhausts memory when making libcrypto_a.a
%setup -q -n libxml2-%{libxml_version}

SYS=`uname -s`

if expr \( "z$SYS" = 'zAIX' \) \| \( "`cat /etc/redhat-release`" : '.* [45]\.' \)
then
    mv configure configure.bak
    sed 's/ *-Wno-array-bounds//' configure.bak >configure
    chmod a+x configure
fi
./configure --prefix=%{prefix} --without-python --enable-shared --disable-static --with-zlib=%{prefix} \
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


