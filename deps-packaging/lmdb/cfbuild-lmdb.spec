Summary: CFEngine Build Automation -- lmdb
Name: cfbuild-lmdb
Version: %{version}
Release: 1
Source0: ad8488cfac644d7a289e428ab3c403c859d844cb.tar.gz
License: OpenLDAP
Group: Other
Url: http://symas.com/mdb
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

Patch0: mdb.patch

%define prefix %{buildprefix}
%define srcdir lmdb-ad8488cfac644d7a289e428ab3c403c859d844cb/libraries/liblmdb

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
rm -f ${RPM_BUILD_ROOT}/var/cfengine/lib/liblmdb.la

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
%{prefix}/bin/lmdump
%{prefix}/bin/lmmgr

%dir %{prefix}/lib%{lbits}
%{prefix}/lib%{lbits}/*.so*

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%changelog
