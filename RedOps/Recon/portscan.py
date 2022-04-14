#!/bin/python3
# portscan.py
# syntax: ./portscan.py <target>

# dependencies
import sys
from datetime import datetime as time
import os
import socket

# validate target input
if len(sys.argv) == 2:
    target = socket.gethostbyname(sys.argv[1]) 
else:
    print("Invalid amount of arguments.")
    print("Syntax: python3 /.portscan.py <target>")

# scan header
print("-" * 50)
print("Scanning target " + target)
print("Start time: " + str(time.now()))
print("-" * 50)

# try to scan target in port range 50-85
try:
        for port in range(79,81):
            print("Scanning port {}".format(port))
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            socket.setdefaulttimeout(1)
            result = s.connect_ex((target,port))
            if result == 0:
                print("Port {} is open.".format(port))
            s.close()

except KeyboardInterrupt:
        print("\nExiting scan.")
        sys.exit()

except scoket.gaierror:
        print("\nHostname could not be resolved.")
        sys.exit()

except socket.error:
        print("\nCouldn't connect to the target.")
        sys.exit()
