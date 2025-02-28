%define prefix %{buildprefix}

Summary: The CFEngine Configuration System
Name: cfbuild-libgcc
Version: 4.2.4
Release: 0
Vendor: IBM
License: Proprietary
Group: Applications/System
Url: http://ibm.com/
BuildRoot: %{_topdir}/%{name}-%{version}-%{release}-buildroot


AutoReqProv: no



%description
GCC provides a low-level runtime library, libgcc.a or libgcc_s.so.1 on some platforms. GCC generates calls to routines in this library automatically, whenever it needs to perform some operation that is too complicated to emit inline code for.

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT%{prefix}/lib

cp  /opt/freeware/lib/gcc/powerpc-ibm-aix*.0.0/*/libgcc_s.a $RPM_BUILD_ROOT%{prefix}/lib/

if [ "$(uname -v)" -eq 7 ]; then
  # we need libatomic.a (only) on AIX 7
  cp  /opt/freeware/lib/gcc/powerpc-ibm-aix*.0.0/*/libatomic.a $RPM_BUILD_ROOT%{prefix}/lib/
  echo %{prefix}/lib/libatomic.a > libatomic-files
else
  echo > libatomic-files
fi
#cp  /opt/freeware/lib/gcc/powerpc-ibm-aix*.0.0/4.*/libstdc++.a $RPM_BUILD_ROOT%{prefix}/lib/

%clean
rm -rf $RPM_BUILD_ROOT

%post


%preun


%files -f libatomic-files
%defattr(755,root,root)

# Libs
%dir %prefix
%dir %prefix/lib

%prefix/lib/libgcc_s.a
#%prefix/lib/libstdc++.a


%changelog
