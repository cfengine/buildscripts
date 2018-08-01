Summary: CFEngine Build Automation -- libyaml
Name: cfbuild-libyaml
Version: %{version}
Release: 1
Source0: yaml-0.2.1.tar.gz
License: MIT
Group: Other
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}
%define srcdir yaml-0.2.1

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
%{prefix}/lib/*.la

%changelog

