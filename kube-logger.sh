#!/bin/bash

source settings.env

if [ -z $LOGFILE ]; then
    LOGFILE=$2
fi

STATUS=$1

if [ -z $STATUS ]; then
    STATUS="debug"
fi    

case "$STATUS" in
    debug)
        if [ $LOGLEVEL == "debug" ];then
            log=1
        fi
        ;;    
    info)
        if [ $LOGLEVL == "debug"] || [ $LOGLEVEL == "info" ]; then
            log=1
        fi
        ;;
    warning)
        if [ $lOGLEVEL == "warning" ] || [ $LOGLEVEL == "debug" ] || [ $LOGLEVEL == "info" ]; then
            log=1
        fi
        ;;
    error)
        if [ ! -z $LOGLEVEL ] || [ $LOGLEVEL != "off" ]; then
            log=1
        fi    
        ;;    
    *)
        log=0
        ;;
esac  

if [ $log == 1 ]; then
    while read data; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$STATUS] $data" | tee "$LOGFILE" 
    done
fi
