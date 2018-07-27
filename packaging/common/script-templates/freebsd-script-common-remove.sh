/usr/sbin/service ldconfig restart >/dev/null 2>&1
[ ! -f @@PREFIX@@/lib/libcurl.so.4     ] && /bin/rm -f @@PREFIX@@/lib/libcurl.so.4
[ ! -f @@PREFIX@@/lib/libidn2.so.0     ] && /bin/rm -f @@PREFIX@@/lib/libidn2.so.0
[ ! -f @@PREFIX@@/lib/libpcre.so.1     ] && /bin/rm -f @@PREFIX@@/lib/libpcre.so.1
[ ! -f @@PREFIX@@/lib/libpromises.so.3 ] && /bin/rm -f @@PREFIX@@/lib/libpromises.so.3
[ ! -f @@PREFIX@@/lib/libxml2.so.2     ] && /bin/rm -f @@PREFIX@@/lib/libxml2.so.2
[ ! -f @@PREFIX@@/lib/libz.so.1        ] && /bin/rm -f 4@@PREFIX@@/lib/libz.so.1

