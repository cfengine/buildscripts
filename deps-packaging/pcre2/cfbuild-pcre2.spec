%define pcre2_version 10.45

Summary: CFEngine Build Automation -- pcre2
Name: cfbuild-pcre2
Version: %{version}
Release: 1
Source0: pcre2-%{pcre2_version}.tar.gz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n pcre2-%{pcre2_version}

./configure --prefix=%{prefix} --enable-shared --disable-static

%build

if [ -z $MAKE ]; then
  MAKE_PATH=`which MAKE`
  export MAKE=$MAKE_PATH
fi

$MAKE

SYS=`uname -s`
if ! [ "z$SYS" = "zAIX" ]; then
%if %{?with_testsuite:1}%{!?with_testsuite:0}
$MAKE check
%endif
fi

%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/pcre2grep
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/pcre2test
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpcre2-8.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libpcre2-posix.*
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig/libpcre2-posix.pc
rm -f ${RPM_BUILD_ROOT}%{prefix}/include/pcre2posix.h
# Do not merge those lines into single one -- any new file in share should trigger an error
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/man
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/doc
rmdir ${RPM_BUILD_ROOT}%{prefix}/share

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- pcre2 -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- pcre2

%description devel
CFEngine Build Automation -- pcre2 -- development files

%files
%defattr(-,root,root)

%dir %prefix/lib
%prefix/lib/libpcre2-8.so.0.*.*
%prefix/lib/libpcre2-8.so.0
%prefix/lib/libpcre2-8.so

%files devel
%defattr(-,root,root)

%dir %prefix/bin
%{prefix}/bin/pcre2-config

%dir %prefix/include
%prefix/include/pcre2.h

%dir %prefix/lib/pkgconfig
%prefix/lib/pkgconfig/libpcre2-8.pc

%changelog
