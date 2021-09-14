case "`uname -s`" in
	Linux)
		if [ -f /etc/os-release ]; then
			OS_VERSION="$(sed '/VERSION_ID/!d;s/[^0-9]*\([0-9]\+\).*/\1/' /etc/os-release)"
			OS_NAME="$(sed '/^ID=/!d;s/.*=//;s/^"//;s/"$//' /etc/os-release)"
		elif [ -f /etc/redhat-release ]; then
			if cat /etc/redhat-release | grep -iq centos; then
				OS_NAME=centos
			else
				OS_NAME=rhel
			fi
			OS_VERSION="$(sed 's/[^0-9]*\([0-9]\+\).*/\1/' /etc/redhat-release)"
		fi
		;;
	SunOS)
		OS_NAME=solaris
		OS_VERSION=`uname -r | sed -e 's/^5\.//'`
		;;
	AIX)
		OS_NAME=aix
		OS_VERSION=`uname -v`
		;;
esac

cmp_version()
{
	# compares OS versions: where this script is running vs where the package was built.
	# pass extra third argument if it's *not* supported when these versions match.
	this_version="$1"
	built_on_version="$2"
	same_version_is_bad="$3"
	if [ -z "$this_version" -o -z "$built_on_version" ]; then
		echo "WARNING: error detecting version. Likely $OS_NAME $OS_VERSION is too new for this package."
		echo "This configuration might be unsupported, please consider downloading a proper package."
		echo "Press Ctrl+C within next 15 seconds to abort."
		sleep 15 || return 1
		return 0
	elif [ "$this_version" -gt "$built_on_version" ]; then
		echo "WARNING: this package was built on $BUILT_ON_OS $BUILT_ON_OS_VERSION, and you're installing it on $OS_NAME $OS_VERSION, which seems to be newer."
		echo "This configuration might be unsupported, please consider downloading a proper package."
		echo "Press Ctrl+C within next 15 seconds to abort."
		sleep 15 || return 1
		return 0
	elif [ -z "$same_version_is_bad" -a "$this_version" = "$built_on_version" ]; then
		return 0
	else
		return 1
	fi
}

# debian-to-ubuntu match
# From https://askubuntu.com/a/445496
deb2ubuntu()
{
	case "$1" in
		(6) echo 11;;
		(7) echo 13;;
		(8) echo 15;;
		(9) echo 17;;
		(10) echo 19;;
		(11) echo 21;;
	esac
	# TODO: or can it be simply Debian[N]=Ubuntu[2*N-1]?
}

# rhel-to-fedora match
# From https://docs.fedoraproject.org/en-US/quick-docs/fedora-and-red-hat-enterprise-linux/index.html#_history_of_red_hat_enterprise_linux_and_fedora
rhel2fedora()
{
	case "$1" in
		(6) echo 12;;
		(7) echo 19;;
		(8) echo 28;;
	esac
}

compatible()
{
	if [ "$OS_NAME" = "" -o "$OS_VERSION" = "" ]; then
		# no version checking
		return 0
	fi
	if [ "$OS_NAME" = "$BUILT_ON_OS" ]; then
		cmp_version "$OS_VERSION" "$BUILT_ON_OS_VERSION"
		return $?
	fi
	if [ "$BUILT_ON_OS-$OS_NAME" = "centos-rhel" -o "$BUILT_ON_OS-$OS_NAME" = "rhel-centos" ]; then
		cmp_version "$OS_VERSION" "$BUILT_ON_OS_VERSION"
		return $?
	fi
	if [ "$BUILT_ON_OS-$OS_NAME" = "centos-fedora" -o "$BUILT_ON_OS-$OS_NAME" = "rhel-fedora" ]; then
		build_compat="`rhel2fedora "$BUILT_ON_OS_VERSION"`"
		cmp_version "$OS_VERSION" "$build_compat" same_version_is_bad
		return $?
	fi
	if [ "$BUILT_ON_OS" = "sles" ] && expr "$OS_NAME" : ".*suse" >/dev/null; then
		cmp_version "$OS_VERSION" "$BUILT_ON_OS_VERSION"
		return $?
	fi
	if [ "$BUILT_ON_OS-$OS_NAME" = "debian-ubuntu" ]; then
		build_compat="`deb2ubuntu "$BUILT_ON_OS_VERSION"`"
		cmp_version "$OS_VERSION" "$build_compat" same_version_is_bad
		return $?
	fi
	if [ "$BUILT_ON_OS-$OS_NAME" = "ubuntu-debian" ]; then
		this_compat="`deb2ubuntu "$OS_VERSION"`"
		cmp_version "$this_compat" "$BUILT_ON_OS_VERSION" same_version_is_bad
		return $?
	fi
	# different platforms
	echo "WARNING: this package was built on $BUILT_ON_OS $BUILT_ON_OS_VERSION, and you're installing it on $OS_NAME $OS_VERSION."
	echo "Names differ! This configuration might be unsupported, please consider downloading a proper package."
	echo "Press Ctrl+C within next 15 seconds to abort."
	sleep 15 || return 1
	return 0
}


if [ -z "$IGNORE_VERSION_CHECK" ]; then
	if ! compatible; then
		echo "ERROR: this package was built on $BUILT_ON_OS $BUILT_ON_OS_VERSION, and this seems to be $OS_NAME $OS_VERSION."
		echo "This combination is not compatible. To override this check, export non-empty IGNORE_VERSION_CHECK variable."
		exit 1
	fi
fi
