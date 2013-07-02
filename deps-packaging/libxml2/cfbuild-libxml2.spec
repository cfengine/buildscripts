Summary: CFEngine Build Automation -- libxml2
Name: cfbuild-libxml2
Version: %{version}
Release: 1
Source0: libxml2-sources-2.7.7.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n libxml2-2.7.7

./configure --prefix=%{prefix} --without-python

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

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/xml2-config

%prefix/include

%dir %prefix/lib
%prefix/lib/*.so
%prefix/lib/pkgconfig

%changelog
