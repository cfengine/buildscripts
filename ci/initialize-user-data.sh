#!/bin/false

# This file should be sourced, not run.

# This script will do build slave setup, including creating credentials for the
# jenkins user, based on root's credentials (will copy its keys). The script is
# expected to be sourced early in the user-data phase after provisioning.

# Make sure error detection and verbose output is on, if they aren't already.
set -x -e

# Add jenkins user and copy credentials.
useradd -m -u 1010 jenkins || true
mkdir -p /home/jenkins/.ssh
# copy /root/.ssh/authorized_keys to /home/jenkins/.ssh, removing everything
# before 'ssh-rsa'. Some platforms have forcecommand='echo "root access disabled"'
# there.
sed 's/.*ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys >/home/jenkins/.ssh/authorized_keys || true

# Enable sudo access for jenkins.
echo "jenkins ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# Disable TTY requirement.
sed -i -e 's/^\( *Defaults *requiretty *\)$/# \1/' /etc/sudoers

# Copy the buildscripts repository to jenkins user.
cp -r /root/buildscripts /home/jenkins
# was copying build-artifacts-cache known host entry
#cp /root/mender-qa/data/known_hosts                    /home/jenkins/.ssh/known_hosts


# add authorized_keys file before chowning, so that initialize-build-host.sh can manage
touch /home/jenkins/.ssh/authorized_keys

# Make sure everything in jenkins' folder has right owner.
chown -R jenkins:jenkins /home/jenkins

groupadd -r kvm || true # In case it already exists.
usermod -a -G kvm jenkins

# change hostname to localhost
# it will fix sudo complaining "unable to resolve host digitalocean",
# and some tests
hostname localhost
# Ensure reverse hostname resolution is correct and 127.0.0.1 is always 'localhost'.
# There's no nice shell command to test it but this one:
# python -c 'import socket;print socket.gethostbyaddr("127.0.0.1")'
if test -f /etc/hosts; then
    sed -i -e '1s/^/127.0.0.1 localhost localhost.localdomain\n/' /etc/hosts
else
    echo '127.0.0.1 localhost localhost.localdomain' >/etc/hosts
fi

apt_get() {
    # Work around apt-get not waiting for a lock if it's taken. We want to wait
    # for it instead of bailing out. No good return code to check unfortunately,
    # so we just have to look inside the log.

    pid=$$
    # Maximum five minute wait (30 * 10 seconds)
    attempts=30

    while true
    do
        ( /usr/bin/apt-get "$@" 2>&1 ; echo $? > /tmp/apt-get-return-code.$pid.txt ) | tee /tmp/apt-get.$pid.log
        if [ $attempts -gt 0 ] && \
               [ "$(cat /tmp/apt-get-return-code.$pid.txt)" -ne 0 ] && \
               fgrep "Could not get lock" /tmp/apt-get.$pid.log > /dev/null
        then
            attempts=$(expr $attempts - 1 || true)
            sleep 10
        else
            break
        fi
    done

    ret_code=$(cat /tmp/apt-get-return-code.$pid.txt)
    rm -f /tmp/apt-get-return-code.$pid.txt /tmp/apt-get.$pid.log

    return $ret_code
}
alias apt=apt_get
alias apt-get=apt_get
