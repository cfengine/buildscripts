if ! echo ${PATH} | /bin/grep -q /var/cfengine/bin ; then
    export PATH=$PATH:/var/cfengine/bin
fi

if ! echo ${MANPATH} | /bin/grep -q /var/cfengine/share/man ; then
    export MANPATH=$MANPATH:/var/cfengine/share/man
fi
