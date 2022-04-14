#!/bin/python3
# simplesocket.py
# syntax: ./simplesocket.py [target] 

# dependencies
import sys
import datetime as time
import os
import socket

# var declarations
HOST = '127.0.0.1'
PORT = 7777
socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

socket.connect((HOST,PORT))
