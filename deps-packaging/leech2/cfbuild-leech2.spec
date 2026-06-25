%define leech2_version 5.2.0

Summary: CFEngine Build Automation -- leech2
Name: cfbuild-leech2
Version: %{version}
Release: 1
Source0: leech2-%{leech2_version}.tar.gz
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n leech2-%{leech2_version}

%build

# Use the system-wide Rust toolchain installed by the build host setup.
export RUSTUP_HOME=/opt/rust
export PATH=/opt/rust/bin:$PATH

# Embed an rpath of %{prefix}/lib in libleech2.so so it resolves co-bundled
# CFEngine libraries at runtime, matching the other bundled deps (enterprise's
# rpath_test.sh requires every /var/cfengine/lib/lib*.so to carry this rpath).
export RUSTFLAGS="-C link-arg=-Wl,-rpath,%{prefix}/lib"
cargo build --release

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{prefix}/bin
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/include

install -m 755 target/release/libleech2.so ${RPM_BUILD_ROOT}%{prefix}/lib/
install -m 755 target/release/lch ${RPM_BUILD_ROOT}%{prefix}/bin/
install -m 644 include/leech2.h ${RPM_BUILD_ROOT}%{prefix}/include/

sed -e 's|^prefix=.*|prefix=%{prefix}|' \
    -e 's|@LIBDIR@|lib|' \
    -e 's|@VERSION@|%{leech2_version}|' \
    leech2.pc.in > ${RPM_BUILD_ROOT}%{prefix}/lib/pkgconfig/leech2.pc

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- leech2 -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- leech2

%description devel
CFEngine Build Automation -- leech2 -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/lch

%dir %{prefix}/lib
%{prefix}/lib/*.so

%files devel
%defattr(-,root,root)

%dir %{prefix}/include
%{prefix}/include/*.h

%dir %{prefix}/lib
%dir %{prefix}/lib/pkgconfig
%{prefix}/lib/pkgconfig/*.pc

%changelog
