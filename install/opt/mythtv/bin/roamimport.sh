#!/bin/bash
# Import database for roaming MythTV

# Run from command line this way
# run_opt.sh mythtv/prd roamimport.sh
# or
# roamimport.sh

set -e
. /etc/opt/mythtv/mythtv.conf
. /etc/opt/mythtv/private.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1
# date

if [[ "$MYTHTVDIR" == "" ]]   ; then
  MYTHTVDIR=/usr
fi

if [[ "$MYTHCONFDIR" == "" ]] ; then
    export MYTHCONFDIR=$HOME/.mythtv
fi

# Removable drive is mounted on default location
# and a link is in /srv/mythtv/video4
if ! mountpoint /srv/mythroam ; then
    mount /srv/mythroam
fi
sudo mkdir -p /srv/mythtv
sudo ln -fs /srv/mythroam /srv/mythtv/video4
sudo mkdir -p /srv/mythtv/video3
sudo ln -fs /srv/mythroam/videos /srv/mythtv/video3/videos
mkdir -p $MYTHCONFDIR/channels
cp /srv/mythroam/channels/* $MYTHCONFDIR/channels/

sudo cp -fv /srv/mythroam/etc/comskip_shows.txt /etc/opt/mythtv/

#restore
backupdir=/srv/mythtv/video4/dbbackup
backupfile=`ls -1 $backupdir/ | tail -1`
backupfile=$backupdir/$backupfile

. $scriptpath/getconfig.sh
mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

if [[ "$DBName" != mythdbroam ]] ; then
    echo "Incorrect Database name $DBName"
    read test
    exit 2
fi

hostname=$(cat /etc/hostname)

now=$(date -u '+%Y=%m-%d %H:%M:%S')

echo "drop database if exists $DBName;
create database $DBName;" | \
sudo mysql

$MYTHTVDIR/share/mythtv/mythconverg_restore.pl --verbose --filename "$backupfile"

if [[ "$ROAM_GROUPS" != "" ]] ; then
  sql1="delete from recorded where recgroup not in ($ROAM_GROUPS);"
fi
if [[ "$ROAM_LIVECHANS" != "" ]] ; then
  sql2="update channel set visible = 0 where channum not in ($ROAM_LIVECHANS);"
fi

echo "
update recordedartwork set host = '$hostname';
update recorded set hostname = '$hostname';
update videometadata set host = '$hostname';
update storagegroup set hostname = '$hostname';
update videometadata set host = '$hostname';
update capturecard set hostname = '$hostname';
update settings set data = '0' where value = 'idleTimeoutSecs' and hostname is null;
$sql1
update record set inactive = 1;
update record set inactive = 0, filter = 0 where type = 11 and category= 'Default';
delete from settings where value = 'DeletedMaxAge' and hostname is null;
delete from settings where value = 'MasterServerIP' and hostname is null;
delete from settings where value = 'BackendServerIP' and hostname = '$hostname';
delete from settings where value = 'BackendServerAddr' and hostname = '$hostname';
delete from settings where value = 'MasterServerName' and hostname is null;
delete from settings where value = 'ListenOnAllIps' and hostname = '$hostname';
delete from settings where value = 'AllowConnFromAll' and hostname = '$hostname';
delete from settings where value = 'SecurityPin' and hostname = '$hostname';
$sql2
insert into settings (value,data,hostname) values
  ('DeletedMaxAge','-1',null),
  ('MasterServerIP','$ROAM_IPADDRESS',null),
  ('BackendServerIP','$ROAM_IPADDRESS','$hostname'),
  ('BackendServerAddr','$ROAM_IPADDRESS','$hostname'),
  ('MasterServerName','$hostname',null),
  ('ListenOnAllIps','1','$hostname'),
  ('AllowConnFromAll','1','$hostname'),
  ('SecurityPin','frednurke','$hostname');
select * from settings
where value in ('DeletedMaxAge','MasterServerIP','MasterServerName',
'ListenOnAllIps','SecurityPin','BackendServerIP','BackendServerAddr');
" | \
$mysqlcmd

# move index.html to <phone-number>.html to prevent snooping
if [[ -f $MYTHTVDIR/share/mythtv/html/apps/backend/index.html ]] ; then
    mv -f $MYTHTVDIR/share/mythtv/html/apps/backend/index.html $MYTHTVDIR/share/mythtv/html/apps/backend/index-xxx.html
fi
# Remove old passwords
rm -f $MYTHTVDIR/share/mythtv/html/*([0-9]).html
# Add new password
cp -f $MYTHTVDIR/share/mythtv/html/apps/backend/index-xxx.html $MYTHTVDIR/share/mythtv/html/$HTML_PASSWORD.html

echo "Check results. Enter to exit."
read test
