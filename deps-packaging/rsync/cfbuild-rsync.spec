%define rsync_version 3.4.1

Summary: CFEngine Build Automation -- rsync
Name: cfbuild-rsync
Version: %{version}
Release: 1
Source0: rsync-%{rsync_version}.tar.gz
Patch0: fix-buffer-overflow.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n rsync-%{rsync_version}

%patch0 -p1

# liblz4, libxxhash, libzstd, and libssl give rsync extra compression
# algorithms, extra checksum algorithms, and allow use of openssl's crypto lib
# for (potentially) faster MD4/MD5 checksums.
./configure --prefix=%{prefix} --with-included-zlib=%{prefix} CPPFLAGS="-I%{prefix}/include" --disable-xxhash --disable-zstd --disable-lz4

%build

make 

%install

rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/
rm ${RPM_BUILD_ROOT}%{prefix}/bin/rsync-ssl

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- rsync -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- rsync

%description devel
CFEngine Build Automation -- rsync -- development files

%files
%defattr(755,root,root)
%dir %prefix/bin
%prefix/bin/rsync

%changelog
