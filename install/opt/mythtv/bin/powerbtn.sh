#!/bin/bash
# replacement for /etc/acpi/powerbtn.sh
# This is called by the system when the power button is pressed
# That is controlled by setting the script name in /etc/acpi/events/powerbtn
# This runs under root

. /etc/opt/mythtv/mythtv.conf
#scriptname=`readlink -e "$0"`
#scriptpath=`dirname "$scriptname"`
#scriptname=`basename "$scriptname" .sh`

#exec 1>>$LOGDIR/${scriptname}.log
#exec 2>&1
#date

#if [[ "$IS_BACKEND" == false ]] ; then 
#    if su mythtv -c "$scriptpath/mythshutdown.sh powerbtn" ; then
#        su mythtv -c $scriptpath/systemshutdown.sh
#    fi
#fi

if ps -u "$SOFT_USER" ; then 
    pkill -U "$SOFT_USER" 
    exit
fi

/etc/acpi/powerbtn.sh
