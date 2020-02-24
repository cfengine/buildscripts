%define nghttp2_version 1.40.0
%global __os_install_post %{nil}

Summary: CFEngine Build Automation -- nghttp2
Name: cfbuild-nghttp2
Version: %{version}
Release: 1
Source0: nghttp2-%{nghttp2_version}.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n nghttp2-%{nghttp2_version}

CPPFLAGS=-I%{buildprefix}/include


./configure \
    --prefix=%{prefix} \
    --enable-lib-only \
    CPPFLAGS="$CPPFLAGS"

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- nghttp2 -- development files
Group: other
AutoReqProv: no

%description
CFEngine Build Automation -- nghttp2

%description devel
CFEngine Build Automation -- nghttp2 -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*

%files devel
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*

%changelog


