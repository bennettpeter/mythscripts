#!/bin/bash
# This configures, builds and creates a package for
# the project represented by the current directory
# or a directory specified in the first parameter
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e

while (( $# > 0 )) ; do
  case $1 in
    --sourcedir|-d)
        dirname="$2"
        cd $dirname
        shift 2
        ;;
    --configopt|-c)
        configopt="$2"
        shift 2
    *)
        echo ERROR invalid option "$1"
        exit 2
        ;;
  esac
done

projname=`basename $PWD`

"$scriptpath/config.sh" $configopt

"$scriptpath/build.sh"

"$scriptpath/install.sh"

"$scriptpath/package.sh"

