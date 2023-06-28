# setup build host on ubuntu 20
apt-get -qy update
apt-get -qy install git

PREFIX=/var/cfengine

# Github Actions provides machines with various packages installed,
# what confuses our build system into thinking that it's an RPM distro.
sudo rm -f /bin/rpm
export EXPLICIT_ROLE=hub

# Install dependencies
sudo apt-get update -y

# Install Python2 and psycopg2
sudo apt-get -qy install python2
wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O get-pip.py
sudo python2 get-pip.py
sudo pip install psycopg2-binary

# Remove libltdl
sudo apt-get -qy purge 'libltdl*'

# remove unwanted packages
sudo apt-get -qq purge apache* "postgresql*" redis*

(
if test -f "mission-portal/public/scripts/package.json"; then
	# packages needed for installing Mission portal dependencies
	sudo apt-get -qq -y install npm
	cd mission-portal/public/scripts
	# install dependencies from npmjs
	npm i
fi
)

# install composer and friends
sudo apt-get -qq -y install curl php php-curl php-zip php-mbstring php-xml php-gd composer

(
if test -f "mission-portal/composer.json"; then
	cd mission-portal
	# install PHP dependencies from composer
	composer install
fi
)

(
if test -f "nova/api/http/composer.json"; then
	cd nova/api/http/
	# install PHP dependencies from composer
	composer install --ignore-platform-reqs
fi
)

(
if test -f "mission-portal/public/themes/default/bootstrap/cfengine_theme.less"; then
	sudo apt-get -qq -y install npm
	cd mission-portal/public/themes/default/bootstrap
	npx -p less lessc --compress ./cfengine_theme.less ./compiled/css/cfengine.less.css
fi
)

(
if test -f "mission-portal/ldap/composer.json"; then
	sudo apt-get -qq -y install php-ldap
	cd mission-portal/ldap
	# install PHP dependencies from composer
	composer install
fi
)

# packages needed for autogen
sudo apt-get -qy install git autoconf automake m4 make bison flex \
	binutils libtool gcc g++ libc-dev libpam0g-dev python2 python3 psmisc \
	libtokyocabinet-dev libssl-dev libpcre3-dev default-jre-headless

NO_CONFIGURE=1 PROJECT=nova ./buildscripts/build-scripts/autogen

# packages needed for building
sudo apt-get -qy install bison flex binutils build-essential fakeroot ntp \
	dpkg-dev libpam0g-dev python2 python3 debhelper pkg-config psmisc nfs-common \
	dpkg-dev debhelper g++ libncurses5 pkg-config build-essential libpam0g-dev fakeroot rsync gcc make sudo wget

# remove unwanted dependencies
sudo apt-get -qy purge libltdl-dev libltdl7 #libtool

# needed for cfengine-nova-hub.deb packaging
sudo apt-get install -qy python3-pip
