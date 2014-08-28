#!/bin/sh 
# This script exists to bootstrap the hub after installation.

IFCONFIG=/sbin/ifconfig
# Introduce ourselves
echo "Bootstraping CFEngine hub"

if [ ! -x "/var/cfengine/bin/cf-agent" ];
then
	echo "No cfengine installation found, aborting ..."
	exit 0
fi

# Check the number of interfaces
echo -n "* checking network interfaces ... " 

# Find out how many interfaces do we have
RAW_INTERFACES=`$IFCONFIG -s|cut -f1 -d' '|grep -v "Iface"|grep -v "lo"`
if [ -z "$RAW_INTERFACES" ];
then
	echo "No network interfaces found, aborting..."
	echo "You will need to adjust your network settings and bootstrap the hub manually by running the following command\n"
	echo "/var/cfengine/bin/cf-agent --bootstrap <ip address>"
	exit 0
fi

NUMBER_RAW_INTERFACES=`echo $RAW_INTERFACES | wc -w`

echo " detected $NUMBER_RAW_INTERFACES interfaces"
echo "* checking network interfaces that are enabled and have a valid ip addresses"

# Get the ipaddresses of the corresponding interfaces
for i in $RAW_INTERFACES; do
	RAW_IPV4_DATA=`$IFCONFIG $i|grep "inet addr"`
	RAW_IPV6_DATA=`$IFCONFIG $i|grep "inet6 addr"`
	if [ ! -z "$RAW_IPV4_DATA" ];
	then
		for j in $RAW_IPV4_DATA;
		do
			RAW_IPV4=`echo $j|grep "addr:"` 
			if [ ! -z "$RAW_IPV4" ];
			then
				IPV4=`echo "$RAW_IPV4"|cut -f2 -d':'`
				echo " -> $i = $IPV4"
			fi
		done
	fi
	if [ ! -z "$RAW_IPV6_DATA" ];
	then
        for j in $RAW_IPV6_DATA;
		do
			RAW_IPV6_WITH_SCOPE=`echo $j|grep "::"`
			if [ ! -z "$RAW_IPV6_WITH_SCOPE" ];
			then
				IPV6=`echo "$RAW_IPV6_WITH_SCOPE"|cut -f1 -d'/'`	
				echo " -> $i = $IPV6"
			fi
		done
	fi
done
echo -n "* Please choose one ip address to use as the hub ip address: "
hub_ip_address=""
read hub_ip_address
if [ -z "$hub_ip_address" ];
then
	echo "No ip address specified, aborting ..."
	echo "You will need to manually bootstrap the hub using the following command:\n"
	echo "/var/cfengine/bin/cf-agent --bootstrap <ip address>"
	exit 0
fi
echo " bootstraping the hub using "$hub_ip_address" as the ip address"
echo "/var/cfengine/bin/cf-agent --bootstrap $hub_ip_address"
/var/cfengine/bin/cf-agent --bootstrap $hub_ip_address

exit 0
