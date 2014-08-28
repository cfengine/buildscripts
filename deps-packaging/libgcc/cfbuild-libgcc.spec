%define prefix %{buildprefix}

Summary: The CFEngine Configuration System
Name: cfbuild-libgcc
Version: 4.2.0
Release: 0
Vendor: IBM
License: Proprietary
Group: Applications/System
URL: http://ibm.com/
BuildRoot: %{_topdir}/%{name}-%{version}-%{release}-buildroot


AutoReqProv: no



%description
GCC provides a low-level runtime library, libgcc.a or libgcc_s.so.1 on some platforms. GCC generates calls to routines in this library automatically, whenever it needs to perform some operation that is too complicated to emit inline code for.

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT%{prefix}/lib


LIBGCC=`find /opt/freeware -name libgcc_s.a|head -1`
LIBSTDC=`find /opt/freeware -name libstdc++.a|head -1`

cp $LIBGCC $RPM_BUILD_ROOT%{prefix}/lib/
cp $LIBSTDC $RPM_BUILD_ROOT%{prefix}/lib/

cp  /opt/freeware/lib/gcc/powerpc-ibm-aix5.3.0.0/4.2.0/libgcc_s.a $RPM_BUILD_ROOT%{prefix}/lib/
cp  /opt/freeware/lib/gcc/powerpc-ibm-aix5.3.0.0/4.2.0/libstdc++.a $RPM_BUILD_ROOT%{prefix}/lib/
cp  /usr/ccs/lib/libpthdebug.a $RPM_BUILD_ROOT%{prefix}/lib/
cp  /usr/ccs/lib/libpthreads.a $RPM_BUILD_ROOT%{prefix}/lib/
cp  /usr/ccs/lib/libpthreads_compat.a $RPM_BUILD_ROOT%{prefix}/lib/
cp  /usr/lib/libc.a $RPM_BUILD_ROOT%{prefix}/lib/

%clean
rm -rf $RPM_BUILD_ROOT

%post


%preun


%files
%defattr(755,root,root)

# Libs
%dir %prefix
%dir %prefix/lib

%prefix/lib/libgcc_s.a
%prefix/lib/libstdc++.a
%prefix/lib/libpthdebug.a
%prefix/lib/libpthreads.a
%prefix/lib/libpthreads_compat.a
%prefix/lib/libc.a


%changelog
