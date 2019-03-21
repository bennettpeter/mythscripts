#!/bin/bash

# Run a version of software from /opt/<project>/<branch>
# run_opt.sh <location> <program> [params]
# e.g. run_opt.sh mythtv/master mythfrontend -O IgnoreSchemaVerMismatch=1

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname"`
location=$1
pgm=$2
shift
shift
set -e

branch=$(basename "$location")
project=$(basename $(dirname "$location"))
destdir=/opt/$location
shortname=$branch

case $project in
    mythtv|mythplugins)
        basedir=$destdir/usr
        set -x
        export PATH=$basedir/bin:$basedir/local/bin:$PATH
        export MYTHTVDIR=$basedir
        export LD_LIBRARY_PATH=$basedir/lib:$basedir/share/mythtv/lib:$LD_LIBRARY_PATH
        # commented out to use default config dir
        export MYTHCONFDIR=$HOME/.mythtv-$shortname
        # dist-packages if installed by debian
        export PYTHONPATH=$basedir/local/lib/python2.7/dist-packages
        export PERL5LIB=`ls -d $basedir/local/share/perl/*`${PERL5LIB:+:${PERL5LIB}}
        exec $pgm "$@"
        ;;
    *)
        basedir=$destdir/usr
        export PATH=$basedir/bin:$PATH
        exec $pgm "$@"
        ;;
esac
