#!/bin/bash

# Install a package to /opt/<project>/<branch>
# deb-opt.sh <location> <filename.deb>
# e.g. deb_opt.sh mythtv/prd mythtv-light_35~Pre-331-g41b921c949-0_amd64_noble.deb

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname"`
location=$1
deb=$2
shift
shift
set -e

branch=$(basename "$location")
project=$(basename $(dirname "$location"))
destdir=/opt/$location
shortname=$branch

if [[ $location == "" || $deb == "" ]] ; then
    echo "Install a package to /opt/<project>/<branch>"
    echo "deb-opt.sh <location> <filename.deb>"
    echo "e.g. deb_opt.sh mythtv/prd mythtv-light_35~Pre-331-g41b921c949-0_amd64_noble.deb"
    exit 2
 fi
if [[ -e "$destdir" ]] ; then
    echo "Replace $destdir and its contents? Y|N"
    read resp
    if [[ $resp != Y && $resp != y ]] ; then exit 2 ; fi 
fi
sudo rm -rf $destdir
sudo dpkg-deb -x "$deb" $destdir
