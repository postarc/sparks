#!/bin/bash
# checkdaemon.sh
# Make sure the daemon is not stuck.
# Add the following to the crontab (i.e. crontab -e)
# */30 * * * * ~/sparks/checkdaemon.sh

previousBlock=$(cat ~/sparks/blockcount)
currentBlock=$(/usr/local/bin/sparks-cli $1 $2 getblockcount)

/usr/local/bin/sparks-cli $1 $2 getblockcount > ~/sparks/blockcount

if [ "$previousBlock" == "$currentBlock" ]; then
  /usr/local/bin/sparks-cli $1 $2 stop
  sleep 5
  /usr/local/bin/sparksd -daemon $1 $2 
fi 
