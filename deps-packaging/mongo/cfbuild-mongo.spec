%ifarch %ix86
%define archsuffix 32
%define mongoarch i686
%else
%define archsuffix 64
%define mongoarch x86_64
%endif

Summary: CFEngine Build Automation -- mongo
Name: cfbuild-mongo
Version: %{version}
Release: 1
Source0: mongodb-linux-%{mongoarch}-2.2.4.tgz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix /var/cfengine

%prep
%setup -q -n mongodb-linux-%{mongoarch}-2.2.4

%build

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/bin
cp bin/mongo* ${RPM_BUILD_ROOT}%{prefix}/bin

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- mongo

%files
%defattr(-,root,root)

%dir %prefix/bin
%prefix/bin/mongo*

%changelog
