#!/bin/bash
# Export files for transcoding

# -----------------------------------
# Note this is not used by daily runs
# -----------------------------------

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

MAXNUMSHOWS="$1"
TITLE="$2"
RECGROUP="$3"
NUMSKIP=$4

#if [[ "$RECGROUP" == "" ]] ; then
#    RECGROUP=Default
#fi

if [[ "$MAXNUMSHOWS" == "" ]] ; then
    echo "Export files for transcoding"
    echo  "Input parameters "
    echo "1 Maximum number of Shows to copy"
    echo "2 Title (optional). Default is all titles"
    echo "3 Recording group (optional). Default is all groups except Archive and Deleted"
    echo "4 Number of oldest shows to skip (optional). Default is 2"
    echo "5 Override mount directory (optional). Default is $TCMOUNTDIR"
    exit 2
fi

mountdir="$TCMOUNTDIR"

if [[ "$5" != "" ]] ; then
    mountdir="$5"
fi

mount "$mountdir" || true
mkdir -p "$TCSTORAGEDIR/$TCSUBDIR/hostlock/"
hostname=`cat /etc/hostname`
echo "hold" > "$TCSTORAGEDIR/$TCSUBDIR/hostlock/$hostname"

echo make links to shows ...
$scriptpath/mythlinks.sh

files=0

cd "$LINKSDIR/origdate/"

srchgrp=
if [[ "$RECGROUP" == "" ]] ; then
    srchgrp='*'
fi

srchtitle=
if [[ "$TITLE" == "" ]] ; then
    srchtitle='*'
fi

if [[ "$NUMSKIP" == "" ]] ; then
    NUMSKIP=2
fi
for grpdir in $srchgrp "$RECGROUP" ; do
    if [[ "$grpdir" == "" || "$grpdir" == Deleted || "$grpdir" == Archive ]] ; then
        continue
    fi
    cd "$LINKSDIR/origdate/$grpdir/"

    for titledir in $srchtitle "$TITLE" ; do
        if [[ "$titledir" == "" ]] ; then
            continue
        fi
        cd "$LINKSDIR/origdate/$grpdir/$titledir"
        # cd "$LINKSDIR/origdate/$grpdir/$TITLE"
        numshows=`ls -1 | wc -l`
        if (( numshows > NUMSKIP )) ; then
            counter=0
            for episode in * ; do
                # echo "Title: $titledir, Episode: $episode"
                let counter=counter+1
                if (( counter > NUMSKIP )) ; then
                    if [[ "$episode" == *.mpg ]] ; then
                        echo "Title: $titledir, Episode: $episode"
                        cp -fv `readlink "$episode"` "$TCSTORAGEDIR/$TCSUBDIR/"
                        let files=files+1
                    fi
                fi
                if (( files >= MAXNUMSHOWS )) ; then
                    break 3
                fi
            done
        fi
    done
done
echo $files files copied to "$TCSTORAGEDIR/$TCSUBDIR/"
rm -f "$TCSTORAGEDIR/$TCSUBDIR/hostlock/$hostname"

