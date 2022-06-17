#!/bin/bash
# initRecon.sh
# Validates a target IP then scans

# validate target IP
if [ "$1" == "" ]
then
	# target IP was not specified
	echo "Enter a target IP to continue."
	echo "Syntax: ./initRecon.sh 127.0.0.1"
else
	echo "Beginning initial recon on target $1"

	echo "Pinging..."
	target=$(ping -c 1 $1 |  grep "64 bytes" | cut -d " " -f 4 | tr -d ":")

	# if target was unreachable/unset, exit. Else, continue to scans.
	if [ "$target" == "" ] 
	then
		echo "Target is not reachable. Exiting."
		exit
	else
		echo "Target $target is reachable."
		echo "Starting NMAP scans."
	
		# inital scan
		echo "Starting initial scan. Results at $1/initial" 
		sudo nmap -v -sV -O --top-ports 49 --open -oA $2/initial $target

		# full scan
		echo "Starting full scan. Results at $1/full"
		sudo nmap -v -A --open -p- -T3 -oA $2/full $target 

		# udp scan
		echo "Starting UDP scan. Results at $1/udp"
		#sudo nmap -v -sU -T3 -p- -oA $2/udp $target
	fi
fi
