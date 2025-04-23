%define diffutils_version 3.12

Summary: CFEngine Build Automation -- diffutils
Name: cfbuild-diffutils
Version: %{version}
Release: 1
Source0: diffutils-%{diffutils_version}.tar.xz
License: GPL3
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
export PATH=/opt/freeware/bin:$PATH # to use newer version of tar on aix platform
%setup -q -n diffutils-%{diffutils_version}

./configure --prefix=%{prefix}

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/

%clean
rm -rf $RPM_BUILD_ROOT

%description 
CFEngine Build Automation -- diffutils

%files
%defattr(755,root,root)
%dir %prefix/bin
%prefix/bin/diff
%prefix/bin/diff3
%prefix/bin/sdiff
%prefix/bin/cmp

%changelog
