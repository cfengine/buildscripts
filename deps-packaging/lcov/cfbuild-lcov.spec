Summary: CFEngine Build Automation -- lcov
Name: cfbuild-lcov
Version: 1.16
Release: 1
License: GPL
Group: Development/Tools
URL: http://ltp.sourceforge.net/coverage/lcov.php
Source0: lcov-1.16.tar.gz
BuildRoot: %{_topdir}/BUILD/%{name}-%{version}-root
BuildArch: noarch
Requires: perl >= 5.8.8

%description
LCOV is a graphical front-end for GCC's coverage testing tool gcov. It collects
gcov data for multiple source files and creates HTML pages containing the
source code annotated with coverage information. It also adds overview pages
for easy navigation within the file structure.

%prep
%setup -q -n lcov-%{version}

%build
exit 0

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT PREFIX=/usr CFG_DIR=/etc

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/etc/lcovrc
/usr/bin/gendesc
/usr/bin/genhtml
/usr/bin/geninfo
/usr/bin/genpng
/usr/bin/lcov
/usr/share/man/man1
/usr/share/man/man1/gendesc.1.gz
/usr/share/man/man1/genhtml.1.gz
/usr/share/man/man1/geninfo.1.gz
/usr/share/man/man1/genpng.1.gz
/usr/share/man/man1/lcov.1.gz
/usr/share/man/man5
/usr/share/man/man5/lcovrc.5.gz

%changelog
* Mon May 07 2012 Peter Oberparleiter (Peter.Oberparleiter@de.ibm.com)
- added dependency on perl 5.8.8 for >>& open mode support
* Wed Aug 13 2008 Peter Oberparleiter (Peter.Oberparleiter@de.ibm.com)
- changed description + summary text
* Mon Aug 20 2007 Peter Oberparleiter (Peter.Oberparleiter@de.ibm.com)
- fixed "Copyright" tag
* Mon Jul 14 2003 Peter Oberparleiter (Peter.Oberparleiter@de.ibm.com)
- removed variables for version/release to support source rpm building
- added initial rm command in install section
* Mon Apr 7 2003 Peter Oberparleiter (Peter.Oberparleiter@de.ibm.com)
- implemented variables for version/release
* Fri Oct 8 2002 Peter Oberparleiter (Peter.Oberparleiter@de.ibm.com)
- created initial spec file

