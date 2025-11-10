%define git_version 2.51.2

Summary: CFEngine Build Automation -- git
Name: cfbuild-git
Version: %{version}
Release: 1
Source0: git-%{git_version}.tar.gz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n git-%{git_version}

./configure --prefix=%{prefix} --with-openssl=%{prefix} --without-iconv --with-gitconfig=%{prefix}/config/gitconfig --with-gitattributes=%{prefix}/config/gitattributes --with-zlib=%{prefix} --with-curl=%{prefix}  --libexecdir=%{prefix}/lib --with-python=%{prefix}/bin/python

%build

case "$OS" in
    rhel|centos)
        if [ $(echo $OS_VERSION | cut -d. -f1) = 7 ]
        then
            # Fixes the following compilation error on rhel 7:
            # 15:05:28 compat/posix.h:159:24: fatal error: sys/random.h: No such file or directory
            # 15:05:28  #include <sys/random.h>
            # 15:05:28                         ^
            # 15:05:28 compilation terminated.
            patch -p1 < %{_topdir}/SOURCES/fix_git_on_rhel7.patch
        fi
        ;;
esac

make CURL_LDFLAGS="-lcurl"

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/perl5
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/python*
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib64
rm -rf ${RPM_BUILD_ROOT}%{prefix}/perl5
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/perl5
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/bash-completion
rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin/scalar

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

%dir %{prefix}/lib
%{prefix}/lib/git-core

%changelog
