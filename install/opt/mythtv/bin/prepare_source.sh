#!/bin/bash
# Prepare source for build
set -e
gitbasedir=`git rev-parse --show-toplevel`
if [[ `arch` == arm* ]] ; then
    mount /srv/ahome || true
    git checkout .
    rm -f $gitbasedir/../testing.patch
    if [[ -f $gitbasedir/../../abennettpeter/testing.patch ]] ; then
        cp $gitbasedir/../../abennettpeter/testing.patch $gitbasedir/../
        git apply $gitbasedir/../testing.patch
    fi
else
    git diff > $gitbasedir/../testing.patch
fi
