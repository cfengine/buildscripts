%define lmdb_version 0.9.35

Summary: CFEngine Build Automation -- lmdb
Name: cfbuild-lmdb
Version: %{version}
Release: 1
Source0: openldap-LMDB_%{lmdb_version}.tar.gz
License: OpenLDAP
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

Patch0: mdb.patch

%define prefix %{buildprefix}
%define srcdir openldap-LMDB_%{lmdb_version}/libraries/liblmdb

%if %{?with_debugsym}%{!?with_debugsym:0}
%define debug_package %{nil}
%define cflags CFLAGS="-ggdb3"
%else
%define cflags CFLAGS=""
%endif

%ifarch %ix86
%define lbits %{nil}
%else
%define lbits %{nil}
%endif

%prep
SYS=`uname -s`
mkdir -p %{_builddir}
%setup -q -n %{srcdir}
for i in %{_topdir}/SOURCES/00*.patch; do
    $PATCH -p3 < $i
done
# Executable files taken from mdb-autoconf-generated.patch, which is generated
# from Git, and contains permission info, but patch -p1 cannot apply it.
# Use the following command to list the files.
#   grep -B1 '^new file mode.*755' mdb-autoconf-generated.patch
chmod 755 config.guess
chmod 755 config.sub
chmod 755 configure
chmod 755 depcomp
chmod 755 install-sh
chmod 755 missing

# Workaround for automake being sensitive to the order in which the generated
# files are applied. If Makefile.in is patched before aclocal.m4 (which it is,
# following natural file order), then it will try to rebuild Makefile.in, which
# it can't without automake. Work around it by touching that file.
touch Makefile.in

%build

SYS=`uname -s`

if [ -z $MAKE ]; then
  MAKE_PATH=`which make`
  export MAKE=$MAKE_PATH
fi

%{cflags} ./configure --prefix=%{prefix} --libdir=%{buildprefix}/lib
$MAKE

%install
rm -rf ${RPM_BUILD_ROOT}
$MAKE DESTDIR=${RPM_BUILD_ROOT} install
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/liblmdb.la

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

%dir %{prefix}/bin
%{prefix}/bin/mdb_stat
%{prefix}/bin/mdb_copy
%{prefix}/bin/mdb_dump
%{prefix}/bin/mdb_load
%{prefix}/bin/lmdump
%{prefix}/bin/lmmgr

%dir %{prefix}/lib%{lbits}
%{prefix}/lib%{lbits}/*.so*

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%changelog


