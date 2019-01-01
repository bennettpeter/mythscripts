#!/bin/bash
# /etc/cron.weekly/mythtv-database script - check and backup mythconverg tables
# Copyright 2005/12/02 2006/10/08 Paul Andreassen 
#                      2010 Mario Limonciello

# Copied from /etc/cron.weekly/mythtv-database
# That file must be removed and this is used instead
# Called from myth_dailyrun.sh

set -e
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

echo "Started ${scriptname} on `date`" 

if [[ "$MYTHTVDIR" == "" ]] ; then
    MYTHTVDIR=/usr
fi

# get DB details
. $scriptpath/getconfig.sh

$MYTHTVDIR/share/mythtv/mythconverg_backup.pl --rotateglob "$DBName-????-??????????????.sql*"

$scriptpath/optimize_mythdb.sh

echo "Successfully Ended ${scriptname} on `date`" 

# End of file.
