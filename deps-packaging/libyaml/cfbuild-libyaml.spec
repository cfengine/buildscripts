%define yaml_version 0.2.5

Summary: CFEngine Build Automation -- libyaml
Name: cfbuild-libyaml
Version: %{version}
Release: 1
Source0: yaml-%{yaml_version}.tar.gz
License: MIT
Group: Other
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}
%define srcdir yaml-%{yaml_version}

%prep
mkdir -p %{_builddir}
%setup -q -n %{srcdir}

%build

SYS=`uname -s`

if [ -z $MAKE ]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

./configure --prefix=%{prefix}
$MAKE

%install
rm -rf ${RPM_BUILD_ROOT}
$MAKE DESTDIR=${RPM_BUILD_ROOT} install
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libyaml.la

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- lmdb -- development files
Group: Other

AutoReqProv: no

%description
CFEngine Build Automation -- lmdb


%description devel
CFEngine Build Automation -- lmdb -- development files

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
%{prefix}/lib/*.a

%changelog


