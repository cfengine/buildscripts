%define nghttp2_version 1.65.0

Summary: CFEngine Build Automation -- nghttp2
Name: cfbuild-nghttp2
Version: %{version}
Release: 1
Source0: nghttp2-%{nghttp2_version}.tar.xz
License: MIT
Group: Other
Url: nghttp2.org
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}
%prep
mkdir -p %{_builddir}
%setup -q -n nghttp2-%{nghttp2_version}

./configure --prefix=%{prefix}

%build

make

%install

rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Remove unused files
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libnghttp2.*a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/doc/nghttp2/README.rst
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/man/man1/h2load.1
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/man/man1/nghttp*
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/nghttp2/fetch-ocsp-response

%clean

rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- nghttp2 -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- nghttp2

%description devel
CFEngine Build Automation -- nghttp2 -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so*

%files devel
%defattr(-,root,root)

%prefix/include
%dir %prefix/lib
%prefix/lib/pkgconfig

%changelog
