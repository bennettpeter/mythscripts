#!/bin/bash
# put this in $HOME/bin as install.sh
scriptpath=$HOME/proj/github.com/MythTV/packaging/deb-light
set -e

projname=`basename $PWD`

case $projname in
    android)
        branch=`git branch|grep "^\* "|sed  "s/^\* //"`
        echo branch $branch
        if [[ "$branch" == fixes/30 ]] ; then
            ./mythbuild.sh "$@" fresh
        else
            make clean
        fi
        ;;
    *)
        "$scriptpath/config.sh" "$@"
        ;;
esac
