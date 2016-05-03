#!/bin/bash

# This is to setup display for lightdm logon, if needed
# Especially needed for multi-display systems
# Edit /etc/lightdm/lightdm.conf, add a line
# display-setup-script=/opt/mythtv/bin/lightdmsetup.sh

#/usr/bin/xrandr --output VGA1 --left-of HDMI1
#/usr/bin/xrandr --output VGA1 --mode 1280x800
#/usr/bin/xrandr --output VGA1 --auto --output HDMI1 --off
# /usr/bin/xrandr --output VGA1 --auto --output HDMI1 --auto
# /usr/bin/xrandr --output VGA-2 --auto --output DVI-I-1 --auto
#if /usr/bin/xrandr|grep '3200x1080' ; then
#    /usr/bin/xrandr -r 51 -s 1280x1024
#fi

if [[ `cat /etc/hostname` == cougar ]] ; then
    /usr/bin/xrandr --output VGA-0 --auto --output DVI-I-1 --auto || echo RC is $?
fi

# This had better return 0 or the logon screen never gets displayed,
# lightdm fails.
exit 0
