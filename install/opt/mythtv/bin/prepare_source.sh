#!/bin/bash
# Prepare source for build
set -e
gitbasedir=`git rev-parse --show-toplevel`
if [[ `arch` == arm* ]] ; then
    mount /srv/ahome || true
    git checkout $gitbasedir
    git clean
    rm -f $gitbasedir/../testing.patch
    if [[ -s $gitbasedir/../patch/testing.patch ]] ; then
        cp $gitbasedir/../patch/testing.patch $gitbasedir/../
        git apply -v $gitbasedir/../testing.patch
    fi
else
    gitdiff.sh build > $gitbasedir/../patch/testing.patch
fi
