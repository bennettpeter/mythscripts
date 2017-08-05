#!/bin/bash

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

cd $scriptpath/
set -e
shopt -s extglob

find . -type f -not -name '*.sh' -exec chmod 664 {} + 
chmod 775 `find . -type f -name '*.sh'`
chmod 775 `find . -type f -name '*.pl'`
chmod 775 `find . -type f -name '*.py'`
chmod 775 `find . -type f -name 'tv_grab_*'`
chmod 775 `find . -type d`
chmod 775 install/opt/mythtv/bin/!(*.png|*.source)
chgrp -R mythtv *

