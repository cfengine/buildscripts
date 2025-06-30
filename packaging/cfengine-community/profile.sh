if ! echo ${PATH} | /bin/grep /var/cfengine/bin > /dev/null ; then
    export PATH=$PATH:/var/cfengine/bin
fi
