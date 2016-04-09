#!/bin/sh
# /etc/cron.weekly/mythtv-database script - check and backup mythconverg tables
# Copyright 2005/12/02 2006/10/08 Paul Andreassen 
#                      2010 Mario Limonciello

# Copied from /etc/cron.weekly/mythtv-database
# That file must be removed and this is used instead
# Called from myth_dailyrun.sh

set -e -u
scriptname=`readlink -e "$0"`
# DBNAME="mythconverg"
# DEBIAN="--defaults-extra-file=/etc/mysql/debian.cnf"

# /usr/bin/mysqlcheck $DEBIAN -s $DBNAME

echo "Started ${scriptname} on `date`" 

/usr/share/mythtv/mythconverg_backup.pl

# /usr/bin/logger -p daemon.info -i -t${0##*/} "$DBNAME checked and backedup."

/opt/mythtv/bin/optimize_mythdb.sh

echo "Successfully Ended ${scriptname} on `date`" 

# End of file.
