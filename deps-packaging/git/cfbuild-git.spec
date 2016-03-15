Summary: CFEngine Build Automation -- git
Name: cfbuild-git
Version: %{version}
Release: 1
Source0: git-1.8.5.6.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n git-1.8.5.6

./configure --prefix=%{prefix} --with-libpcre=%{prefix} --with-openssl=%{prefix} --without-iconv --with-gitconfig=%{prefix} --with-gitattributes=%{prefix} --with-zlib=%{prefix} --with-curl=%{prefix}  --libexecdir=%{prefix}/lib

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/perl5
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/python*
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib64
rm -rf ${RPM_BUILD_ROOT}%{prefix}/perl5
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/perl5

%clean
rm -rf $RPM_BUILD_ROOT

%description
CFEngine Build Automation -- git

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/git
%{prefix}/bin/gitk
%{prefix}/bin/git-cvsserver
%{prefix}/bin/git-receive-pack
%{prefix}/bin/git-shell
%{prefix}/bin/git-upload-archive
%{prefix}/bin/git-upload-pack

%dir %{prefix}/share
%{prefix}/share/git-core
%{prefix}/share/git-gui
%{prefix}/share/gitk
%{prefix}/share/gitweb
%{prefix}/share/locale
%{prefix}/share/man

%dir %{prefix}/lib
%{prefix}/lib/git-core

%changelog
