#!/bin/bash
# Optimize database

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`


OPT_MYTHDB='/usr/share/doc/mythtv-backend/contrib/maintenance/optimize_mythdb.pl'
LOG='/var/log/mythtv_scripts/optimize_mythdb.log'

echo "Started ${OPT_MYTHDB} on `date`" >> ${LOG}
${OPT_MYTHDB} >> ${LOG}
echo "Finished ${OPT_MYTHDB} on `date`" >> ${LOG} 

