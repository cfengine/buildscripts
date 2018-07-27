if ! echo ${PATH} | /usr/bin/grep @@PREFIX@@/bin > /dev/null ; then
    export PATH=$PATH:@@PREFIX@@/bin
fi

if ! echo ${MANPATH} | /usr/bin/grep @@PREFIX@@/share/man > /dev/null ; then
    export MANPATH=$MANPATH:@@PREFIX@@/share/man
fi
