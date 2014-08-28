Summary: CFEngine Build Automation -- libacl
Name: cfbuild-libacl
Version: %{version}
Release: 1
Source: acl-2.2.48.src.tar.gz
License: MIT
Group: Other
Url: http://example.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
mkdir -p %{_builddir}
%setup -q -n acl-2.2.48

zcat ../../SOURCES/acl.destdir.diff.gz | patch -p1 || true

./configure --prefix=%{prefix} --enable-gettext=no LDFLAGS="-L/var/cfengine/lib" CPPFLAGS="-I/var/cfengine/include" LD_LIBRARY_PATH="/var/cfengine/lib" LD_RUN_PATH="/var/cfengine/lib"

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install-dev install-lib DESTDIR=${RPM_BUILD_ROOT}

cp ${RPM_BUILD_ROOT}%{prefix}/include/sys/acl.h ${RPM_BUILD_ROOT}%{prefix}/include/

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -rf ${RPM_BUILD_ROOT}%{prefix}/libexec
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libacl development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libacl

%description devel
CFEngine Build Automation -- libacl devel

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.so.*

%files devel
%prefix/include

%dir %prefix/lib
%prefix/lib/*.so

%changelog
