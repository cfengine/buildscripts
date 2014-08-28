#!/bin/bash

# execute-wrapper
# This script tries to execute the given command, and retries in case of
# failure.
# Parameters:
# SLEEP: which sleep program to use
# TRIES: how many times to re try the execution
# PAUSE: number of seconds to pause, if a different sleep program is used the unit might be different.
# Sleep program to pause the execution
SLEEP=/bin/sleep
# Number of tries
TRIES=4
# We wait 5 seconds between each invocation
PAUSE=30

# 
# No user serviceable parts below
#
#


# We give it 10 chances to succeed
#SEQUENCE=`seq $TRIES`
SEQUENCE=
seq=0
while test $seq -lt $TRIES; do
	seq=$(($seq+1))
	SEQUENCE="$SEQUENCE $seq"
done
# The final result will be stored here
RESULT=0
# The operation and arguments
OPERATION=$@

# If no operation is specified we just exit
if [ -z "$OPERATION" ]; then
	echo "You need to specify the operation you want to execute"
	exit 0;
fi

echo "Operational parameters: "
echo "* operation: $OPERATION"
echo "* retries:   $TRIES"
echo "* pause:     $PAUSE" 
# We try to run the operation, if it fails then we wait and try again.
# After $SEQUENCE tries we give up.
for i in $SEQUENCE;
do
	echo "Trying operation: $OPERATION";
	$OPERATION
	if [ $? -eq 0 ]; then
		echo "Operation successful"
		RESULT=1
		break
	else
		echo "Operation failed, retrying after $PAUSE seconds.";
		`$SLEEP $PAUSE`
	fi
done

if [ $RESULT -eq 0 ]; then
	echo "We retried $SEQUENCE times without success, quitting.";
	exit 128
fi

exit 0

