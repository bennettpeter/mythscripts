#!/bin/bash
# Save changes for later
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
desc="$1"
set -e

$scriptpath/prepare_source.sh
while [[ "$desc" == "" ]] ; do
    echo "Please provide description"
    read -e desc
done
desc=`echo "$desc" | sed "s/ /_/g"`
gitbasedir=`git rev-parse --show-toplevel`
timestamp=`date +%Y%m%d_%H%M`
mv $gitbasedir/../patch/build.patch "$gitbasedir/../patch/${timestamp}_${desc}.patch"
