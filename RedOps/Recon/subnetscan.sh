#!/bin/bash
# subnetscan.sh
# pings a given subnet for reachable hosts

# check for input
if [ "$1" == "" ]
then
echo "Please enter a subnet to scan."
echo "Syntax: ./subnetscan.sh 192.168.1"

else
echo "Scanning subnet $1.x"
for ip in `seq 1 254`; do
ping -c 1 $1.$ip | grep "64 bytes" | cut -d " " -f 4 | tr -d ":" &
done
fi
