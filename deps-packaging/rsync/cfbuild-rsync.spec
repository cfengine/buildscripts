Summary: CFEngine Build Automation -- rsync
Name: cfbuild-rsync
Version: %{version}
Release: 1
Source0: rsync-3.1.3.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n rsync-3.1.3

./configure --prefix=%{prefix} --with-included-zlib=%{prefix}

%build

make 

%install

rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- rsync -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- rsync

%description devel
CFEngine Build Automation -- rsync -- development files

%files
%defattr(755,root,root)
%dir %prefix/bin
%prefix/bin/rsync

%changelog

