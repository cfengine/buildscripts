Summary: CFEngine Build Automation -- libvirt
Name: cfbuild-libvirt
Version: %{version}
Release: 1
Source0: libvirt-1.1.3.9.tar.gz
License: MIT
Group: Other
Url: http://example.com/
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot
Patch0: 0001-fix-inet-oldkernel.patch

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n libvirt-1.1.3.9
%patch0 -p1


# FIXME: is there any other way to have RPATH?
LDFLAGS=-Wl,--rpath=%{prefix}/lib

#
# Newer ld(1) does not allow implicit linking through intermediate
# libraries. Add -lxml2 explicitly.
#
# https://fedoraproject.org/wiki/UnderstandingDSOLinkChange
#
LDFLAGS="$LDFLAGS -L%prefix/lib -lxml2"

LDFLAGS="$LDFLAGS" \
PKG_CONFIG_PATH=%prefix/lib/pkgconfig \
./configure --prefix=%{prefix}\
            --localstatedir=/var \
            --with-remote \
            --without-curl \
            --without-hal \
            --without-udev \
            --without-python \
            --without-xen \
            --without-dtrace \
            --without-qemu \
            --without-openvz \
            --without-lxc \
            --without-sasl \
            --without-avahi \
            --without-esx \
            --without-test \
            --without-uml \
            --without-libvirtd \
            --without-storage-mpath \
            --without-storage-scsi \
            --without-storage-iscsi \
            --without-storage-lvm \
            --without-storage-fs \
            --without-macvtap \
            --without-gnutls \
            --without-selinux \
            --with-libxml=%{prefix} \
            --without-numactl \
            --without-numad
%build

make

%install
rm -rf ${RPM_BUILD_ROOT}

make install DESTDIR=${RPM_BUILD_ROOT}

# Removing unused files

rm -rf ${RPM_BUILD_ROOT}%{prefix}/bin
rm -rf ${RPM_BUILD_ROOT}%{prefix}/etc
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/libvirt/drivers
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.a
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/*.la
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libvirt-qemu*
rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libvirt-lxc*
rm -rf ${RPM_BUILD_ROOT}%{prefix}/libexec
rm -rf ${RPM_BUILD_ROOT}%{prefix}/sbin
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/libvirt
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/doc
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/gtk-doc
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/locale
rm -rf ${RPM_BUILD_ROOT}%{prefix}/share/man
rm -rf ${RPM_BUILD_ROOT}%{prefix}/var

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- libvirt -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- libvirt

%description devel
CFEngine Build Automation -- libvirt -- development files

%files
%defattr(-,root,root)

%dir %{prefix}/lib
%{prefix}/lib/*.so.*

%files devel
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib
%{prefix}/lib/*.so
%{prefix}/lib/pkgconfig

%changelog
