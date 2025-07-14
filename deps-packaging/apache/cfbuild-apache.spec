%define apache_version 2.4.64
%global __os_install_post %{nil}

Summary: CFEngine Build Automation -- apache
Name: cfbuild-apache
Version: %{version}
Release: 1
Source0: httpd-%{apache_version}.tar.gz
Source1: httpd.conf
Patch0:  apachectl.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n httpd-%{apache_version}

%patch0 -p0

CPPFLAGS=-I%{buildprefix}/include


./configure \
    --prefix=%{prefix}/httpd \
    --enable-so \
    --enable-mods-shared="all ssl ldap authnz_ldap" \
    --enable-http2 \
    --with-z=%{prefix} \
    --with-ssl=%{prefix} \
    --with-ldap=%{prefix} \
    --with-apr=%{prefix} \
    --with-apr-util=%{prefix} \
    --with-pcre=%{prefix}/bin/pcre2-config \
    CPPFLAGS="$CPPFLAGS"

%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# ensure apache-created files are not readable by others, ENT-7948
echo "umask 0177" >> ${RPM_BUILD_ROOT}%{prefix}/httpd/bin/envvars

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/man
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/manual
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf/httpd.conf
rm -rf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf/extra/httpd-ssl.conf
cp ${RPM_BUILD_ROOT}/../../SOURCES/httpd.conf ${RPM_BUILD_ROOT}%{prefix}/httpd/conf

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- apache -- development files
Group: other
AutoReqProv: no

%description
CFEngine Build Automation -- apache

%description devel
CFEngine Build Automation -- apache -- development files

%files
%defattr(-,root,root)

%dir %prefix/httpd
%prefix/httpd/bin
%prefix/httpd/cgi-bin
%prefix/httpd/conf
%prefix/httpd/icons
%prefix/httpd/error
%prefix/httpd/logs
%prefix/httpd/modules
%prefix/httpd/htdocs
%prefix/httpd/

%files devel
%defattr(-,root,root)

%dir %prefix/httpd
%prefix/httpd/build
%prefix/httpd/include

%changelog



