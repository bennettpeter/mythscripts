#!/bin/bash

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

cd $scriptpath/
set -e

chmod 775 `find . -type f -name '*.sh'`
find . -type f -not -name '*.sh' -exec chmod 664 {} + 
# chmod 664 `find . -type f -not -name '*.sh'`
chmod 775 `find . -type f -name '*.sh'`
chmod 775 `find . -type f -name '*.pl'`
chmod 775 `find . -type f -name '*.py'`
chmod 775 `find . -type d`
chgrp -R mythtv *

