#!/usr/bin/ksh

set -e

export PATH=$PATH:/usr/local/bin
VERSION=$1

BASEDIR=$2
LPPBASE=$2/..

#create necessary directory skeleton
sudo rm -rf $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION
mkdir -p $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION
cd $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION

# Create package layout using generated RPM.
# Default AIX cpio does not handle rpm2cpio output.
echo rpm2cpio $BASEDIR/cfengine-nova/RPMS/*/*.rpm \| /opt/freeware/bin/cpio -idv
rpm2cpio $BASEDIR/cfengine-nova/RPMS/*/*.rpm | /opt/freeware/bin/cpio -idv

mkdir -p $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/etc/rc.d/init.d
mkdir -p $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info
mkdir -p $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/usr/lpp/cfengine.cfengine-nova/

mkdir -p $LPPBASE/lppdir/bff

#create a output dir
sudo rm -rf $LPPBASE/lppdir/out
mkdir -p $LPPBASE/lppdir/out


cat > $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/etc/rc.d/init.d/cfengine3 << EOF;
#!/usr/bin/ksh
 
ulimit -c 0

case "\$1" in
 
	start)
	   ps -ef | grep -v grep | grep cf-execd > /dev/null
	   ret=\$?
	   if [ \$ret -gt 0 ]; then
	   /var/cfengine/bin/cf-execd
	   fi
	   ;;
	 
	stop)
	    PID=\$\$
	    for i in cf-execd cf-serverd cf-monitord cf-agent; do
	    ps -ef | grep \$i | grep -v grep | awk '{print \$2}' >> /tmp/cfengine3.\$PID
	    done
	    
	    while read line; do
	        kill \$line
	    done < /tmp/cfengine3.\$PID
	 
	    rm /tmp/cfengine3.\$PID
	 
	     ;;
	 
	* )
	     echo "Usage: \$0 (start | stop)"
	    exit 1
	 
esac
EOF

chmod 755 $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/etc/rc.d/init.d/cfengine3 
# Create the info file
env LD_LIBRARY_PATH=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/var/cfengine/lib CFENGINE_TEST_OVERRIDE_EXTENSION_LIBRARY_DIR=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/var/cfengine/lib $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/var/cfengine/bin/cf-agent -V > $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.copyright

# Detect build machine versions of important libraries so we can compare with
# the install machine.
PTHREAD_VERSION=`lslpp -l bos.rte.libpthreads | grep bos.rte.libpthreads | head -n1 | sed -e 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`
LIBC_VERSION=`lslpp -l bos.rte.libc | grep bos.rte.libc | head -n1 | sed -e 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`

#Create the lpp_name file
cat >  $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/lpp_name << EOF; 
4 R I cfengine.cfengine-nova {
cfengine.cfengine-nova $VERSION.0 01 N U en_US Cfengine Nova, Data Center Automation
[
*prereq bos.rte.libpthreads $PTHREAD_VERSION
*prereq bos.rte.libc $LIBC_VERSION
%
INSTWORK 70 70
% 
%
%
%
]
}
EOF




# Create the post install script
cat > $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.post_i << EOF;
#!/usr/bin/ksh
 
if [ -x /var/cfengine/bin/cf-key ]; then
        /var/cfengine/bin/cf-key
fi
 
ret=0
 
STARTUP=/etc/rc.d/init.d/cfengine3
if [ -x /etc/rc.d/init.d/cfengine3 ];then
        for link in /etc/rc.d/rc2.d/K05cfengine3 /etc/rc.d/rc2.d/S97cfengine3; do
                /usr/bin/ln -fs \$STARTUP \$link
        done
fi

/usr/bin/mkdir -p /usr/local/sbin
for i in cf-agent cf-execd cf-key cf-monitord cf-promises cf-runagent cf-serverd; do
        /usr/bin/ln -sf /var/cfengine/bin/\$i /usr/local/sbin/\$i
done
 
exit 0
EOF


# Make the pre uninstall script
 
cat > $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.unpre_i << EOF;
#!/usr/bin/ksh

PID=\$\$
	for i in cf-execd cf-serverd cf-monitord cf-hub cf-agent; do
	    ps -ef | grep \$i | grep -v grep | awk '{print \$2}' >> /tmp/cfengine3.\$PID 
	done
 
while read line; do
   kill \$line
done < /tmp/cfengine3.\$PID
 
rm /tmp/cfengine3.\$PID
 
if [ -d /usr/local/sbin ]; then
        /usr/bin/rm -f /usr/local/sbin/cf-agent /usr/local/sbin/cf-execd \
        /usr/local/sbin/cf-key /usr/local/sbin/cf-know /usr/local/sbin/cf-monitord \
        /usr/local/sbin/cf-promises /usr/local/sbin/cf-report /usr/local/sbin/cf-runagent \
        /usr/local/sbin/cf-serverd /usr/local/sbin/cf-twin /usr/local/sbin/cf-hub > /dev/null 2>&1
 
fi
 
/usr/bin/rm -f /etc/rc.d/rc2.d/K05cfengine3 /etc/rc.d/rc2.d/S97cfengine3
 
exit 0
EOF


cp /usr/lpp/bos/liblpp.a  $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/usr/lpp/cfengine.cfengine-nova/

# -hR needed as only -R will change the original files and folders but -h will changes the ownership of symlinks as well that are inside the lib directory
sudo chown -hR root:system $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION

# Make the LPP
cd $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION
 
# sometimes the following command needs to be done twice
sudo mklpp || sudo mklpp
