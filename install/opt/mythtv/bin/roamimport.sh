#!/bin/bash
# Import database for roaming MythTV

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1
# date

#restore
backupdir=/srv/mythtv/video1/dbbackup
backupfile=`ls -1 $backupdir/ | tail -1`
backupfile=$backupdir/$backupfile

. $scriptpath/getconfig.sh
mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

if [[ "$DBName" != mythdbroam ]] ; then
    echo "Incorrect Database name $DBName"
    exit 2
fi

hostname=$(cat /etc/hostname)

echo "drop database $DBName;
create database $DBName;" | \
sudo mysql

$MYTHTVDIR/share/mythtv/mythconverg_restore.pl --verbose --filename "$backupfile"

echo "
update recordedartwork set host = '$hostname';
update storagegroup set hostname = '$hostname';
update videometadata set host = '$hostname';
delete from settings where value = 'DeletedMaxAge' and hostname is null;
delete from settings where value = 'MasterServerIP' and hostname is null;
delete from settings where value = 'BackendServerIP' and hostname = '$hostname';
delete from settings where value = 'BackendServerAddr' and hostname = '$hostname';
delete from settings where value = 'MasterServerName' and hostname is null;
delete from settings where value = 'ListenOnAllIps' and hostname = '$hostname';
delete from settings where value = 'SecurityPin' and hostname = '$hostname';
insert into settings (value,data,hostname) values
  ('DeletedMaxAge','-1',null),
  ('MasterServerIP','$ROAM_IPADDRESS',null),
  ('BackendServerIP','$ROAM_IPADDRESS','$hostname'),
  ('BackendServerAddr','$ROAM_IPADDRESS','$hostname'),
  ('MasterServerName','$hostname',null),
  ('ListenOnAllIps','1','$hostname'),
  ('SecurityPin','0000','$hostname');
select * from settings
where value in ('DeletedMaxAge','MasterServerIP','MasterServerName',
'ListenOnAllIps','SecurityPin','BackendServerIP','BackendServerAddr');
" | \
$mysqlcmd
echo "Check results. Enter to exit."
read test
