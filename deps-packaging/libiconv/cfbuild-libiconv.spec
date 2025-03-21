Summary: CFEngine Build Automation -- libiconv
Name: cfbuild-libiconv
Version: %{version}
Release: 1
Source0: libiconv-1.18.tar.gz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n libiconv-1.18

./configure --prefix=%{prefix} --disable-shared --enable-static


%build

make   
 
%install

rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libcharset.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libiconv.la


%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libiconv -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libiconv

%description devel
CFEngine Build Automation -- libiconv -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/*.a

%files devel
%defattr(-,root,root)

%prefix/include

%dir %prefix/lib
%prefix/lib/*.a

%changelog

