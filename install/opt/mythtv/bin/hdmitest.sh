# File to help with testing hdmifuncs
# source this file
VID_RECDIR=/home/storage/Video/recordings
recname=hdmirec1
. /etc/opt/mythtv/mythtv.conf

scriptpath=$PWD
#scriptpath=/home/peter/proj/github.com/bennettpeter/mythscripts/install/opt/mythtv/bin
scriptname=testfuncs

source $scriptpath/hdmifuncs.sh
ADB_ENDKEY=
#TESSPARM="-c tessedit_char_whitelist=0123456789"
#adb connect fire-office-eth
