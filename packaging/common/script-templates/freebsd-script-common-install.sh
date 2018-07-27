/usr/sbin/service ldconfig restart 2>&1 >/dev/null
[ -f @@PREFIX@@/lib/libcurl.so.4.5.0     ] && /bin/ln -fs @@PREFIX@@/lib/libcurl.so.4.5.0      @@PREFIX@@/lib/libcurl.so.4
[ -f @@PREFIX@@/lib/libidn2.so.0.3.4     ] && /bin/ln -fs @@PREFIX@@/lib/libidn2.so.0.3.4      @@PREFIX@@/lib/libidn2.so.0
[ -f @@PREFIX@@/lib/libpcre.so.1.2.10    ] && /bin/ln -fs @@PREFIX@@/lib/libpcre.so.1.2.10     @@PREFIX@@/lib/libpcre.so.1
[ -f @@PREFIX@@/lib/libpromises.so.3.0.6 ] && /bin/ln -fs @@PREFIX@@/lib/libpromises.so.3.0.6  @@PREFIX@@/lib/libpromises.so.3
[ -f @@PREFIX@@/lib/libxml2.so.2.9.8     ] && /bin/ln -fs @@PREFIX@@/lib/libxml2.so.2.9.8      @@PREFIX@@/lib/libxml2.so.2
[ -f @@PREFIX@@/lib/libz.so.1.2.11       ] && /bin/ln -fs @@PREFIX@@/lib/libz.so.1.2.11        @@PREFIX@@/lib/libz.so.1
