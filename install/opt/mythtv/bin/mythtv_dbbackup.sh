#!/bin/bash
# /etc/cron.weekly/mythtv-database script - check and backup mythconverg tables
# Copyright 2005/12/02 2006/10/08 Paul Andreassen 
#                      2010 Mario Limonciello

# Copied from /etc/cron.weekly/mythtv-database
# That file must be removed and this is used instead
# Called from myth_dailyrun.sh

set -e -u
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

# DBNAME="mythconverg"
# DEBIAN="--defaults-extra-file=/etc/mysql/debian.cnf"

# /usr/bin/mysqlcheck $DEBIAN -s $DBNAME

echo "Started ${scriptname} on `date`" 

if [[ "$MYTHTVDIR" == "" ]] ; then
    MYTHTVDIR=/usr
fi

$MYTHTVDIR/share/mythtv/mythconverg_backup.pl

# /usr/bin/logger -p daemon.info -i -t${0##*/} "$DBNAME checked and backedup."

$scriptpath/optimize_mythdb.sh

echo "Successfully Ended ${scriptname} on `date`" 

# End of file.
