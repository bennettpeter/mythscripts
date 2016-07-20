#!/bin/bash

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

cd $scriptpath/
set -e

find . -type f -not -name '*.sh' -exec chmod 664 {} + 
chmod 775 `find . -type f -name '*.sh'`
chmod 775 `find . -type f -name '*.pl'`
chmod 775 `find . -type f -name '*.py'`
chmod 775 `find . -type d`
chmod 775 install/opt/mythtv/bin/*
chgrp -R mythtv *

