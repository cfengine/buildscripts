#!/usr/bin/ksh

set -e

export PATH=$PATH:/usr/local/bin
VERSION=$1

# --=== Convert version number into AIX format ===--
# Split version into parts:
# * first and Second parts together (They are called Major.Minor in Linux or Version.Release in AIX)
# * third part (Patch or Modification)
# * forth part (Build or FixLevel)
VER12=$(echo $VERSION | cut -d. -f1-2)
VER3=$(echo $VERSION | cut -d. -f3)
VER4=$(echo $VERSION | cut -d. -f4)
# In third field: change 'a' to '88', 'b' to '99', delete leading zeroes if followed by a number
VER3=$(echo $VER3 | sed -e 's/a/88/;s/b/99/;s/^0\(.\)/\1/')
# If third field contains '-' (happens during release builds) - remove it, adding stuff after dash to the beginning of 4th field.
# i.e. from $VER3=1-2 $VER4=3 go to $VER3=1 $VER4=23
# Note that currently, when third field contains '-', 4th field is empty
if echo $VER3 | grep - >/dev/null; then
    VER4="$(echo $VER3 | cut -d- -f2)$VER4"
    VER3="$(echo $VER3 | cut -d- -f1)"
fi
# In 4th field: delete all non-numeric characters, delete leading zeroes if followed by a number, limit length to 4
VER4=$(echo $VER4 | sed -e 's/[^0-9]//g;s/^0\(.\)/\1/;s/^\(....\).*/\1/')
# If 4th field is empty, set it to 0
test -z "$VER4" && VER4=0
# Build resulted version number
VERSION="$VER12.$VER3.$VER4"

BASEDIR=$2
LPPBASE=$2/..
P="$BASEDIR/buildscripts/packaging/cfengine-nova"

PREFIX="$3"

# Clean up old build artifacts.
for i in bff lpp out
do
    sudo rm -rf $LPPBASE/lppdir/$i/*
    sudo rm -rf $HOME/lppdir/$i/*
done

# Create necessary directory skeleton.
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


# Create install/remove scripts.
PREINSTALL=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.pre_i
POSTINSTALL=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.post_i
# Note the reverse pre <-> post relationship on the AIX platform.
# unpost_i is called before unpre_i.
PREREMOVE=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.unpost_i
POSTREMOVE=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.unpre_i
$P/../common/produce-script cfengine-nova preinstall bff > $PREINSTALL
$P/../common/produce-script cfengine-nova postinstall bff > $POSTINSTALL
$P/../common/produce-script cfengine-nova preremove bff > $PREREMOVE
$P/../common/produce-script cfengine-nova postremove bff > $POSTREMOVE

# In addition AIX has pre_rm, which we will treat the same as preinstall.
# See the actual scripts for more details on this
PRE_RM=$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.pre_rm
$P/../common/produce-script cfengine-nova preinstall bff > $PRE_RM

# Create the info file
env LD_LIBRARY_PATH="$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION$PREFIX/lib" CFENGINE_TEST_OVERRIDE_EXTENSION_LIBRARY_DIR="$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION$PREFIX/lib" "$LPPBASE/lppdir/lpp/cfengine-nova-$VERSION$PREFIX/bin/cf-agent" -V > $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/.info/cfengine.cfengine-nova.copyright

# Detect build machine versions of important libraries so we can compare with
# the install machine.
PTHREAD_VERSION=`lslpp -l bos.rte.libpthreads | grep bos.rte.libpthreads | head -n1 | sed -e 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`
LIBC_VERSION=`lslpp -l bos.rte.libc | grep bos.rte.libc | head -n1 | sed -e 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`

#Create the lpp_name file
cat >  $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/lpp_name << EOF; 
4 R I cfengine.cfengine-nova {
cfengine.cfengine-nova $VERSION 01 N U en_US Cfengine Nova, Data Center Automation
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

cp /usr/lpp/bos/liblpp.a  $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION/usr/lpp/cfengine.cfengine-nova/

# -hR needed as only -R will change the original files and folders but -h will changes the ownership of symlinks as well that are inside the lib directory
sudo chown -hR root:system $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION

# Make the LPP
cd $LPPBASE/lppdir/lpp/cfengine-nova-$VERSION

# sometimes the following command needs to be done twice
sudo -E mklpp || sudo -E mklpp

# Remove extra 'cfengine.' from filename
cd $HOME/lppdir/out/
NEW_NAME="$(echo *.bff | sed 's/cfengine.cfengine/cfengine/')"
sudo mv *.bff "$NEW_NAME"
