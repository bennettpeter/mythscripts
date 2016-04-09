#!/bin/bash
# Run MythTV on raspberry pi
# To run standalone use QT_QPA_PLATFORM=eglfs
# To run under startx use QT_QPA_PLATFORM=xcb

# xmodmap /etc/opt/mythtv/remote.xmodmap

MYTHTVDIR=~/mythtv-rpi-101
QT_QPA_EGLFS_FORCE888=1 QT_QPA_PLATFORM=eglfs\
 LD_LIBRARY_PATH=$MYTHTVDIR/lib:$MYTHTVDIR/lib/mysql\
 QT_PLUGIN_PATH=$MYTHTVDIR/plugins\
 QT_QPA_FONTDIR=$MYTHTVDIR/lib/fonts\
 MYSQL_UNIX_PORT=/var/run/mysqld/mysqld.sock\
 PYTHONPATH=$MYTHTVDIR/lib/python2.7/site-packages\
 $MYTHTVDIR/bin/mythfrontend

# force logout
# killall lxsession

# prompted logout
#lxde-logout
