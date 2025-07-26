#!/bin/bash
# leancomm.sh - commskip from leanrec log

. /etc/opt/mythtv/mythtv.conf
. /etc/opt/mythtv/private.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
#~ date

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`
numdate=`date "+%Y%m%d"`

# parameters
# logfile title SnnEnn

logfile="$1"
title="$2"
seasep="$3"

set -e

awk -v outfile=$HOME/video_commskip.sh \
  -v title="$title" -v seasep="$seasep" '

function gettime(timestamp) {
    gsub(/_|-/," ",timestamp)
    return mktime(timestamp)
}

function printcmd() {
    if (length(skiplist) > 0) {
        # \42 is a double quote
        print "mythutil --video \42" filename  "\42 --setskiplist \42" skiplist "\42 -q"
        print "mythutil --video \42" filename  "\42 --setskiplist \42" skiplist "\42 -q" > outfile
    }
}


BEGIN {
    start = 0
    found = 0
    screen = 0
    strttime=0
    adstart = 0
    adend = 0
    print "<" title ">", "<" seasep ">"
    fps = 60
    skiplist = ""
    scrntime = 0
}

/ Start of run \*\*\*/ {
    printcmd()
    start = 1
    found = 0
    skiplist = ""
    strttime = 0
    adstart = 0
    adend = 0
    scrntime = 0
    count = 0
    next
}

/ RECORD: / {
    if (start) {
        fndtitle = substr($0,29,length($0)-8-28)
        if (match(fndtitle,/Movies/)) {
            fndtitle = substr($0,37,length($0)-36)
            fndseasep = "Movie"
        }
        else
            fndseasep = $(NF)
        start = 0
        if ( (fndtitle == title || title == "") \
          && (fndseasep == seasep || seasep == "") ) {
            print $0
            found = 1
            #~ print "Match Found"
        }
    }
}

{
    if (!found)
        next
}

/ Starting recording of / {
    fullfilename = substr($0,43)
    num = split(fullfilename,arr,"/")
    filename = arr[num-1] "/" arr[num] 
    print filename
    strttime = gettime($1) + 10
}

/ Screen from adb/ {
    scrntime = gettime($2)
}

/^[0-9]:[0-9][0-9]$/ {
    if (!adstart && scrntime)
        adstart = scrntime
    if (adstart) {
        count++
        num = split($1,arr,":")
        if (num == 2) {
            adtm = arr[1] * 60 + arr[2]
            adend = scrntime + adtm
        }
    }
}

/^Ad$/ {
    if (!adstart)
        adstart = scrntime
}
    
/^20[0-9][0-9]-[0-9][0-9]/ {
    scrntime = gettime($1)
}

{
    if (!adend)
        next
    if (scrntime > adend) {
        if (adend - adstart < 480 && count > 1) {
            entry = (adstart-strttime)*fps "-" (adend-strttime)*fps
            if (length(skiplist) > 0)
                skiplist = skiplist "," 
            skiplist = skiplist entry
        }
        adstart=0
        adend=0
        count=0
    }
}


END {
    printcmd()
}

' $logfile

