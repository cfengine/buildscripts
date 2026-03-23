%define openssl_version 3.6.1

Summary: CFEngine Build Automation -- openssl
Name: cfbuild-openssl
Version: %{version}
Release: 1
Source0: openssl-%{openssl_version}.tar.gz
Patch0: 0006-Add-latomic-on-AIX-7.patch
Patch1: 0008-Define-_XOPEN_SOURCE_EXTENDED-as-1.patch
License: MIT
Group: Other
Url: https://cfengine.com
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-%{release}-buildroot

AutoReqProv: no

%define prefix %{buildprefix}

%prep
mkdir -p %{_builddir}
%setup -q -n openssl-%{openssl_version}

%patch0 -p1
%patch1 -p1

%build

if [ -z "$MAKE" ]
then
    export MAKE=`which make`
fi

SYS=`uname -s`


echo ==================== BUILD_TYPE is $BUILD_TYPE ====================

test -d %{prefix} || ( sudo mkdir %{prefix} && sudo chmod 777 %{prefix} )
mkdir -p %{prefix}/include

DEBUG_CONFIG_FLAGS=
DEBUG_CFLAGS=
if [ $BUILD_TYPE = "DEBUG" ]
then
    DEBUG_CONFIG_FLAGS="no-asm -DPURIFY"
    DEBUG_CFLAGS="-g2 -O1 -fno-omit-frame-pointer"
    # Workaround for OpenSSL build issue on our old SuSE buildslave, see:
    # https://www.mail-archive.com/openssl-dev@openssl.org/msg39231.html
elif [ "$OS" = sles ]
then
    DEBUG_CONFIG_FLAGS=no-asm
fi

# Work around platform-specific issues
HACK_FLAGS=
if [ $OS = centos ]  ||  [ $OS = rhel ]
then
    if [ "$OS_VERSION_MAJOR" = "4" ]
    then
        HACK_FLAGS=-D_GNU_SOURCE                              # CentOS 4 issue
    fi
fi

if [ x$SYS = "xAIX" ]; then
  # This flag is needed because the AIX linker doesn't export symbols starting
  # with underscore by default (and some are needed in OpenSSL's ASM tricks).
  # See https://www.ibm.com/developerworks/aix/library/au-gnu.html for
  # details.
  LDFLAGS="$LDFLAGS -Wl,-bexpfull"
  # for some reason, Configure on AIX doesn't auto-detect target
  if [ "$(uname -v)" -eq 7 ]; then
    target=aix7-gcc
  else
    target=aix-gcc
  fi
fi

# Note: as of now, config_flags_hub.txt and config_flags_agent.txt files are the same.
# CFE-4042 is the ticket to further investigate what can be added to both of them.
GLOBAL_CONFIG_FLAGS=$(<../../SOURCES/config_flags_$ROLE.txt)

$PERL ./Configure $target $GLOBAL_CONFIG_FLAGS \
         $DEBUG_CONFIG_FLAGS \
         --prefix=%{prefix} \
         $HACK_FLAGS   \
         $DEBUG_CFLAGS \
         $LDFLAGS \
         --libdir=lib

$PERL configdata.pm --dump

# Remove -O3 and -fomit-frame-pointer from debug builds
if [ $BUILD_TYPE = "DEBUG" ]
then
    sed -e '/^CFLAG=/{s/ -O3//;s/ -fomit-frame-pointer//}'   \
        Makefile > Makefile.cfe \
        && mv Makefile.cfe Makefile
fi

$MAKE depend
$MAKE

# %if %{?with_testsuite}%{!?with_testsuite:0}
#     $MAKE test
# %endif


%install
rm -rf ${RPM_BUILD_ROOT}

$MAKE DESTDIR=${RPM_BUILD_ROOT} install_sw
$MAKE DESTDIR=${RPM_BUILD_ROOT} install_ssldirs

# Removing unused files

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/c_rehash
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/misc/CA.pl
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/misc/tsget
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/openssl.cnf.dist
rm -rf ${RPM_BUILD_ROOT}%{prefix}/ssl/misc/tsget.pl
rm -rf ${RPM_BUILD_ROOT}%{prefix}/lib/cmake/OpenSSL

SYS=`uname -s`
if [ x$SYS = "xAIX" ]; then
  # we need to keep these files in place on AIX, they are archives containing
  # shared objects and the runtime linker needs them
  echo %{prefix}/lib/libssl.a > extra-lib-files
  echo %{prefix}/lib/libcrypto.a >> extra-lib-files

  # no devel files for libraries on AIX
  echo > devel-lib-files
else
  # .a files are static libraries on other platforms, let's get rid of them
  rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libssl.a
  rm -f ${RPM_BUILD_ROOT}%{prefix}/lib/libcrypto.a

  # no extra library files
  echo > extra-lib-files

  # but make sure devel symlinks are packaged
  echo %{prefix}/lib/libssl.so > devel-lib-files
  echo %{prefix}/lib/libcrypto.so >> devel-lib-files
fi

%clean
rm -rf $RPM_BUILD_ROOT

%package devel
Summary: CFEngine Build Automation -- openssl -- development files
Group: Other
AutoReqProv: no

%description
CFEngine Build Automation -- openssl

%description devel
CFEngine Build Automation -- openssl -- development files

%files -f extra-lib-files
%defattr(-,root,root)

%dir %{prefix}/bin
%{prefix}/bin/openssl

%dir %{prefix}/lib
%{prefix}/lib/libssl.so.3
%{prefix}/lib/libcrypto.so.3
%{prefix}/ssl/openssl.cnf
%{prefix}/ssl/ct_log_list.cnf
%{prefix}/ssl/ct_log_list.cnf.dist

%files devel -f devel-lib-files
%defattr(-,root,root)

%{prefix}/include

%dir %{prefix}/lib

%{prefix}/lib/pkgconfig

%changelog

