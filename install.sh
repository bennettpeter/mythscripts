#!/bin/bash
set -x
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
datetime=`date +%Y%m%d_%H%M`
set -e

if ! grep '^mythtv:' /etc/group ; then
    sudo addgroup --gid 200 mythtv
    sudo adduser `id -nu` mythtv
fi

$scriptpath/fixpermissions.sh

ARCH=`arch`

if [[ -f /etc/lsb-release ]] ; then
    . /etc/lsb-release
fi
ver=${DISTRIB_ID}_${DISTRIB_RELEASE}_${ARCH}
hostname=`cat /etc/hostname`

cd $scriptpath/

if [[ ! -f install/etc/opt/mythtv/${hostname}_mythtv.conf ]] ; then
    echo "Please set up install/etc/opt/mythtv/${hostname}_mythtv.conf"
    exit 2
fi
. install/etc/opt/mythtv/${hostname}_mythtv.conf

if [[ "$SOFT_USER" == "" ]] ; then
    SOFT_USER=catch22
fi

create_dir() {
    perm=$2
    if [[ "$perm" == "" ]] ; then
        perm=775
    fi
    sudo mkdir -pv "$1"
    sudo chown mythtv "$1" || true
    sudo chgrp mythtv "$1"
    sudo chmod $perm "$1"
}

mythver=`mythutil --version|grep "MythTV Version"|sed -e "s/MythTV Version : v//"`

$scriptpath/fixpermissions.sh

if [[ "$IS_BACKEND" == true ]] ; then
    create_dir $VIDEODIR 2775
fi
create_dir $DATADIR 2775
create_dir /opt/mythtv
create_dir /opt/mythtv/bin
create_dir /etc/opt/mythtv
create_dir /etc/rc_keymaps
# create_dir $MOUNTDIR
create_dir $LOGDIR 2775
if [[ "$IS_BACKEND" == true ]] ; then
    create_dir $VIDEODIR/video1 2775
    create_dir $VIDEODIR/video2 2775
    create_dir $VIDEODIR/video3 2775
    create_dir $VIDEODIR/video4 2775
fi

# This cannot work becuase remote user is not allowed root access through nfs
#if [[ `echo "$TCMOUNTDIR"/*` != "$TCMOUNTDIR/*" ]] ; then
#    create_dir $TCMOUNTDIR/keepalive 2775
#fi

mkdir -p $scriptpath/backup/
if [[ -f /etc/opt/mythtv/mythtv.conf ]] ; then
    if ! diff install/etc/opt/mythtv/${hostname}_mythtv.conf /etc/opt/mythtv/mythtv.conf ; then
        cp -p /etc/opt/mythtv/mythtv.conf $scriptpath/backup/${hostname}_${datetime}_mythtv.conf
    fi
fi
if [[ "$IS_BACKEND" == true ]] ; then
    if ! diff install/etc/init/mythtv-backend.conf /etc/init/mythtv-backend.conf ; then
        cp -p /etc/init/mythtv-backend.conf $scriptpath/backup/${hostname}_${datetime}_mythtv-backend.conf
    fi
fi
pushd install/etc/opt/mythtv/
# Remove old options files
rm -f /etc/opt/mythtv/*.options
for file in ${hostname}_* ; do
    cp -pv "$file" /etc/opt/mythtv/${file#*_}
done
for file in all_* ; do
    cp -pv "$file" /etc/opt/mythtv/${file#*_}
done
popd

chgrp mythtv /etc/opt/mythtv/mythtv.conf
cd install/opt/mythtv/bin
# Remove old script files
rm -f /opt/mythtv/bin/*
cp -pv `find . -maxdepth 1 -type f` /opt/mythtv/bin/
if [[ -d $ver ]] ; then
    cp -pv $ver/* /opt/mythtv/bin/
fi
chgrp mythtv /opt/mythtv/bin/*
cd $scriptpath/
daemonrestart=N
if [[ "$IS_BACKEND" == true ]] ; then
    if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
        if ! diff install/etc/systemd/system/mythtv-backend.service /etc/systemd/system/mythtv-backend.service ; then
            sudo cp install/etc/systemd/system/mythtv-backend.service /etc/systemd/system/mythtv-backend.service
            daemonrestart=Y
        fi
        if ! systemctl is-enabled mythtv-backend.service ; then
            sudo systemctl enable mythtv-backend.service 
        fi
    else
        sudo cp install/etc/init/mythtv-backend.conf /etc/init/mythtv-backend.conf
    fi
fi

# Do we need to install monitor (Y or N)
if [[ "$USE_MONITOR" == Y ]] ; then
    if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
        if ! diff install/etc/systemd/system/mythtv-monitor.service /etc/systemd/system/mythtv-monitor.service ; then
            sudo cp install/etc/systemd/system/mythtv-monitor.service /etc/systemd/system/mythtv-monitor.service
            daemonrestart=Y
        fi
        if ! systemctl is-enabled mythtv-monitor.service ; then
            sudo systemctl enable mythtv-monitor.service 
        fi
    else
        sudo cp install/etc/init/mythtv-monitor.conf /etc/init/
    fi
fi
if [[ "$mythver" == 0.27* ]] ; then
    sudo rsync -rv install/usr/ /usr/
else
    sudo rsync -rv install/usr/share/mythtv/themes/petermenu/ /usr/share/mythtv/themes/petermenu/
fi

#systemd
if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
    if ! diff install/etc/systemd/system/peter-suspend.service /etc/systemd/system/peter-suspend.service ; then
        sudo cp install/etc/systemd/system/peter-suspend.service /etc/systemd/system/peter-suspend.service
        daemonrestart=Y
    fi
    if ! systemctl is-enabled peter-suspend.service ; then
        sudo systemctl enable peter-suspend.service 
    fi
    if ! diff install/etc/systemd/system/peter-resume.service /etc/systemd/system/peter-resume.service ; then
        sudo cp install/etc/systemd/system/peter-resume.service /etc/systemd/system/peter-resume.service
        daemonrestart=Y
    fi
    if ! systemctl is-enabled peter-resume.service ; then
        sudo systemctl enable peter-resume.service 
    fi
    if ! grep ^HandlePowerKey /etc/systemd/logind.conf ; then
        echo "HandlePowerKey=ignore" | sudo tee -a /etc/systemd/logind.conf
        daemonrestart=Y
    fi
else
    sudo cp install/etc/pm/sleep.d/* /etc/pm/sleep.d/
    if [[ -d /etc/acpi/events/ ]] ; then
        sudo cp install/etc/acpi/events/* /etc/acpi/events/
    fi    
fi

#syslog
sudo cp install/etc/rsyslog.d/10-peter.conf /etc/rsyslog.d/10-peter.conf

if [[ "$daemonrestart" == Y ]] ; then
    sudo systemctl daemon-reload
fi

if ! grep '^catch22:' /etc/group ; then
    sudo addgroup --gid 1099 catch22
fi
if ! grep "^$SOFT_USER" /etc/passwd ; then
    sudo adduser --ingroup catch22 $SOFT_USER
fi
if ! grep "^mythtv" /etc/passwd ; then
    sudo adduser --ingroup mythtv --system --uid 200 mythtv 
fi
if ! grep "^mythtv:.*$SOFT_USER" /etc/group ; then
    sudo adduser $SOFT_USER mythtv
fi

if [[ $ARCH == arm* ]] ; then
    if ! grep "^video:.*$SOFT_USER" /etc/group ; then
        sudo adduser $SOFT_USER audio 
        sudo adduser $SOFT_USER video 
        sudo adduser $SOFT_USER dialout 
        sudo adduser $SOFT_USER plugdev 
        sudo adduser $SOFT_USER input 
    fi
fi

kodiver=`/usr/bin/kodi --version|head -1|cut -f 1 -d '.'`
if [[ "$kodiver" != "" ]] ; then
    sudo cp -av install/home/.kodi /home/$SOFT_USER/
    sudo cp -av install/home/.kodi/peter$kodiver/userdata /home/$SOFT_USER/.kodi/
    sudo chown -R $SOFT_USER /home/$SOFT_USER/.kodi
    sudo chgrp -R $SOFT_USER /home/$SOFT_USER/.kodi
    sudo chmod -R g+w /home/$SOFT_USER/.kodi
fi

if [[ $ARCH == arm* ]] ; then
#    if [[ -f $MYTHTVDIR/bin/mythfrontend ]] ; then
#        sudo cp -av install/home/.config /home/$SOFT_USER/
#        sudo chown -R $SOFT_USER /home/$SOFT_USER/.config
#        sudo chgrp -R $SOFT_USER /home/$SOFT_USER/.config
#    fi
    sudo cp -v install/home/.asoundrc_arm /home/$SOFT_USER/.asoundrc
    sudo chown -R $SOFT_USER /home/$SOFT_USER/.asoundrc
    sudo chgrp -R $SOFT_USER /home/$SOFT_USER/.asoundrc
fi

# Remove automatic weekly db backup
if [[ -f /etc/cron.weekly/mythtv-database ]] ; then
    sudo mkdir -p /etc/cron.removed/
    sudo mv -f /etc/cron.weekly/mythtv-database /etc/cron.removed/
fi

#Remove obsoletes
sudo rm -f /lib/systemd/system-sleep/mythtv_sleep.sh


