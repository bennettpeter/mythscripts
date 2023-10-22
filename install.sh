#!/bin/bash
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
datetime=`date +%Y%m%d_%H%M`
set -e

if [[ "$SUDO_USER" == "" || "$SUDO_USER" == "root" ]] ; then
    echo "This must run under sudo"
    exit 2
fi

if ! grep '^mythtv:' /etc/group ; then
    addgroup --gid 200 mythtv
    adduser $SUDO_USER mythtv
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
    # Param 3 optional is owner:group
    owner=$3
    if [[ "$perm" == "" ]] ; then
        perm=775
    fi
    mkdir -pv "$1"
    if [[ "$3" != "" ]] ; then
        chown "$3" "$1" || true
    fi
    chmod $perm "$1"
}

# mythver=`mythutil --version|grep "MythTV Version"|sed -e "s/MythTV Version : v//"`

$scriptpath/fixpermissions.sh

if [[ "$IS_BACKEND" == true ]] ; then
    create_dir $VIDEODIR 2775 mythtv:mythtv
fi
create_dir $DATADIR 2775 mythtv:mythtv
create_dir /opt/mythtv
create_dir /opt/mythtv/bin
create_dir /etc/opt/mythtv
#~ create_dir /etc/rc_keymaps
# create_dir $MOUNTDIR
create_dir $LOGDIR 2775 mythtv:mythtv
create_dir /var/log/mythtv 2775 mythtv:adm
#~ mkdir -p /var/log/mythtv
#~ chgrp adm /var/log/mythtv
#~ chmod 2775 /var/log/mythtv

if [[ "$IS_BACKEND" == true ]] ; then
    create_dir $VIDEODIR/video1 2775 mythtv:mythtv
    create_dir $VIDEODIR/video2 2775 mythtv:mythtv
    create_dir $VIDEODIR/video3 2775 mythtv:mythtv
    create_dir $VIDEODIR/video4 2775 mythtv:mythtv
    create_dir $LOCALVIDEODIR 2775 mythtv:mythtv
fi

# This cannot work becuase remote user is not allowed root access through nfs
#if [[ `echo "$TCMOUNTDIR"/*` != "$TCMOUNTDIR/*" ]] ; then
#    create_dir $TCMOUNTDIR/keepalive 2775
#fi

if [[ "$CAN_TRANSCODE" == Y ]] ; then
    create_dir $TCSTORAGEDIR/keepalive 2775 mythtv:mythtv
fi

mkdir -p $scriptpath/backup/
if [[ -f /etc/opt/mythtv/mythtv.conf ]] ; then
    if ! diff install/etc/opt/mythtv/${hostname}_mythtv.conf /etc/opt/mythtv/mythtv.conf ; then
        cp -p /etc/opt/mythtv/mythtv.conf $scriptpath/backup/${hostname}_${datetime}_mythtv.conf
    fi
fi

## mythtv config files
pushd install/etc/opt/mythtv/
# Remove old options files
rm -f /etc/opt/mythtv/*.options
for file in ${hostname}_* ; do
    cp -v "$file" /etc/opt/mythtv/${file#*_}
done
for file in all_* ; do
    cp -v "$file" /etc/opt/mythtv/${file#*_}
done
popd

#~ chgrp mythtv /etc/opt/mythtv/mythtv.conf
cd install/opt/mythtv/bin
# Remove old script files
rm -f /opt/mythtv/bin/*
cp -v --preserve=mode `find . -maxdepth 1 -type f` /opt/mythtv/bin/
if [[ -d $ver ]] ; then
    cp -v  --preserve=mode $ver/* /opt/mythtv/bin/
fi
#~ chgrp mythtv /opt/mythtv/bin/*
cd $scriptpath/
# xmltv
rm -f /usr/local/bin/tv_grab_zz_sdjson_sqlite
# Need to move this not link it so it is not in the path twice
mv -f /opt/mythtv/bin/tv_grab_zz_sdjson_sqlite \
  /usr/local/bin/tv_grab_zz_sdjson_sqlite
daemonrestart=N
if [[ "$IS_BACKEND" == true ]] ; then
    if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
        # The script does not enable these.
        # It should be done manually when ready
        if ! diff install/etc/systemd/system/mythtv-backend.service /etc/systemd/system/mythtv-backend.service ; then
            cp install/etc/systemd/system/mythtv-backend.service /etc/systemd/system/mythtv-backend.service
            daemonrestart=Y
        fi
    #~ else
        #~ cp install/etc/init/mythtv-backend.conf /etc/init/mythtv-backend.conf
    fi
    
fi

# Do we need to install monitor (Y or N)
if [[ "$USE_MONITOR" == Y ]] ; then
    if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
        if ! diff install/etc/systemd/system/mythtv-monitor.service /etc/systemd/system/mythtv-monitor.service ; then
            cp install/etc/systemd/system/mythtv-monitor.service /etc/systemd/system/mythtv-monitor.service
            daemonrestart=Y
        fi
        if ! systemctl is-enabled mythtv-monitor.service ; then
            systemctl enable mythtv-monitor.service 
        fi
    #~ else
        #~ cp install/etc/init/mythtv-monitor.conf /etc/init/
    fi
fi
# Do we need to install vnc (Y or N)
if [[ "$USE_VNC" == Y ]] ; then
    if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
        if ! diff install/etc/systemd/system/peter-vnc.service /etc/systemd/system/peter-vnc.service ; then
            cp install/etc/systemd/system/peter-vnc.service /etc/systemd/system/peter-vnc.service
            daemonrestart=Y
        fi
        # Do not enable by default - it may be causing crashes.
#        if ! systemctl is-enabled peter-vnc.service ; then
#            systemctl enable peter-vnc.service
#        fi
    fi
fi
# Do we need to shutdown at 1 AM (Y or N)
if [[ "$USE_PROXY" == Y ]] ; then
    if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
        if ! diff install/etc/systemd/system/peter-proxy.service /etc/systemd/system/peter-proxy.service ; then
            cp install/etc/systemd/system/peter-proxy.service /etc/systemd/system/peter-proxy.service
            daemonrestart=Y
        fi
        if ! systemctl is-enabled peter-proxy.service ; then
            systemctl enable peter-proxy.service
        fi
    fi
fi

#systemd
if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
    if ! diff install/etc/systemd/system/peter-suspend.service /etc/systemd/system/peter-suspend.service ; then
        cp install/etc/systemd/system/peter-suspend.service /etc/systemd/system/peter-suspend.service
        daemonrestart=Y
    fi
    if ! systemctl is-enabled peter-suspend.service ; then
        systemctl enable peter-suspend.service 
    fi

    if ! diff install/etc/systemd/system/peter-resume.service /etc/systemd/system/peter-resume.service ; then
        cp install/etc/systemd/system/peter-resume.service /etc/systemd/system/peter-resume.service
        daemonrestart=Y
    fi
    if ! systemctl is-enabled peter-resume.service ; then
        systemctl enable peter-resume.service
    fi

#    os=`cat /etc/issue|sed "s/ .*//"`
#    if [[ "$os" == Raspbian ]] ; then
#        if ! diff install/etc/systemd/system/peter-addips.service /etc/systemd/system/peter-addips.service ; then
#            cp install/etc/systemd/system/peter-addips.service /etc/systemd/system/peter-addips.service
#            daemonrestart=Y
#        fi
#        if ! systemctl is-enabled peter-addips.service ; then
#            systemctl enable peter-addips.service
#        fi
#    fi

    # Core dumps
    if [[ "$ENABLE_COREDUMPS" == Y ]] ; then
        cp install/etc/sysctl.d/60-coredump /etc/sysctl.d/
        if grep enabled=1 /etc/default/apport  ; then
            sed -i s/enabled=1/enabled=0/ /etc/default/apport
        fi
    else
        rm -f /etc/sysctl.d/60-coredump
        if grep enabled=0 /etc/default/apport  ; then
            sed -i s/enabled=0/enabled=1/ /etc/default/apport
        fi
    fi
 
    if [[ "$WEBCAM" == Y ]] ; then
        if ! diff install/etc/systemd/system/peter-webcam.service /etc/systemd/system/peter-webcam.service ; then
            cp install/etc/systemd/system/peter-webcam.service /etc/systemd/system/peter-webcam.service
            daemonrestart=Y
        fi
        if ! systemctl is-enabled peter-webcam.service ; then
            systemctl enable peter-webcam.service
        fi
    fi

    if [[ "$IRC" == Y ]] ; then
        if ! diff install/etc/systemd/system/peter-irc.service /etc/systemd/system/peter-irc.service ; then
            cp install/etc/systemd/system/peter-irc.service /etc/systemd/system/peter-irc.service
            daemonrestart=Y
        fi
        if ! systemctl is-enabled peter-irc.service ; then
            systemctl enable peter-irc.service
        fi
    fi

    if ! grep ^HandlePowerKey /etc/systemd/logind.conf ; then
        echo "HandlePowerKey=ignore" | tee -a /etc/systemd/logind.conf
        daemonrestart=Y
    fi
else
    cp install/etc/pm/sleep.d/* /etc/pm/sleep.d/
    if [[ -d /etc/acpi/events/ ]] ; then
        cp install/etc/acpi/events/* /etc/acpi/events/
    fi    
fi

#syslog
cp install/etc/rsyslog.d/10-peter.conf /etc/rsyslog.d/10-peter.conf

#sudoers
cp install/etc/sudoers.d/* /etc/sudoers.d/
sudo chown root:root /etc/sudoers.d/*
sudo chmod 440 /etc/sudoers.d/*

#exports
create_dir /etc/exports.d 2775 root:root
pushd install/etc/exports.d/
found=0
for file in `ls ${hostname}_* 2>/dev/null` ; do
    cp -v "$file" /etc/exports.d/${file#*_}
    found=1
done
popd
if (( found )) ; then exportfs -rav ; fi

if [[ "$daemonrestart" == Y ]] ; then
    systemctl restart rsyslog.service
    systemctl daemon-reload
fi

if ! grep '^catch22:' /etc/group ; then
    addgroup --gid 1099 catch22
fi
if ! grep "^$SOFT_USER" /etc/passwd ; then
    adduser --ingroup catch22 $SOFT_USER
fi
if ! grep "^mythtv" /etc/passwd ; then
    adduser --ingroup mythtv --system --uid 200 --home /home/mythtv mythtv 
fi
if ! grep "^mythtv:.*$SOFT_USER" /etc/group ; then
    adduser $SOFT_USER mythtv
fi
if ! grep "^video:.*mythtv" /etc/group ; then
    adduser mythtv audio
    adduser mythtv video
fi

mygroup=`id -ng $SUDO_USER`

if [[ "$mygroup" != catch22 && "$SUDO_USER" != root ]] ; then
    usermod -g catch22 $SUDO_USER
fi

if ! grep "^mythtv:.*$SUDO_USER" /etc/group ; then
    adduser $SUDO_USER mythtv
fi

if [[ $ARCH == arm* ]] ; then
    if ! grep "^video:.*$SOFT_USER" /etc/group ; then
        adduser $SOFT_USER audio 
        adduser $SOFT_USER video 
        adduser $SOFT_USER dialout 
        adduser $SOFT_USER plugdev 
        adduser $SOFT_USER input 
    fi
fi


if [[ "$AMPLIFY" == Y ]] ; then
#    if [[ -f $MYTHTVDIR/bin/mythfrontend ]] ; then
#        cp -av install/home/.config /home/$SOFT_USER/
#        chown -R $SOFT_USER /home/$SOFT_USER/.config
#        chgrp -R $SOFT_USER /home/$SOFT_USER/.config
#    fi
    cp -v install/home/.asoundrc_arm /home/$SOFT_USER/.asoundrc
    chown -R $SOFT_USER /home/$SOFT_USER/.asoundrc
    chgrp -R $SOFT_USER /home/$SOFT_USER/.asoundrc
else
    rm -f /home/$SOFT_USER/.asoundrc
fi

cp -avf install/home/bin /home/$SUDO_USER/

# Remove automatic weekly db backup
if [[ -f /etc/cron.weekly/mythtv-database ]] ; then
    mkdir -p /etc/cron.removed/
    mv -f /etc/cron.weekly/mythtv-database /etc/cron.removed/
fi

#Remove obsoletes
rm -f /lib/systemd/system-sleep/mythtv_sleep.sh

# Check for presence of ccextractor
#~ if [[ "$CAN_TRANSCODE" == Y ]] ; then
    #~ if [[ ! -x /usr/local/bin/ccextractor ]] ; then
        #~ yes "XXXXXXXX PLEASE INSTALL /usr/local/bin/ccextractor XXXXXXXX" | head -5
        #~ exit 2
    #~ fi
#~ fi

# Disable guest logon (after next reboot)
if [[ -d /etc/lightdm/lightdm.conf.d ]] ; then
    sh -c 'printf "[Seat:*]\nallow-guest=false\n" >/etc/lightdm/lightdm.conf.d/50-no-guest.conf'
fi

if [[ "$EMAIL1" != "" || "$EMAIL2" != "" ]] ; then
    if [[ ! -f /etc/opt/mythtv/private.conf ]] ; then
        echo XXXXX Please install private.conf
        echo "[ default ]"
        echo "SMTP_PASSWORD=xxxxxxxx"
    fi
fi
