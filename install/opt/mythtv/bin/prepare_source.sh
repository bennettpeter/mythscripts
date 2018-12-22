#!/bin/bash
# Prepare source for build
set -e
option="$1"
rc=0
gitbasedir=`git rev-parse --show-toplevel`
mkdir -p $gitbasedir/../patch/ 2>/dev/null || true
project=`basename "$PWD"`
for file in $gitbasedir/../patch/Peter/${project}_*.patch ; do
    if [[ -s "$file" ]] ; then
        echo Reverse $file
        git apply --reverse $file || true
    fi
done
if [[ "$option" == done ]] ; then
    exit $rc
fi
if [[ `arch` == arm* ]] ; then
    mount /srv/ahome || true
    git checkout $gitbasedir
    git clean -f
    if [[ -s $gitbasedir/../patch/build.patch ]] ; then
        git apply -v $gitbasedir/../patch/build.patch
    fi
else
    gitdiff.sh build > $gitbasedir/../patch/build.patch || rc=$?
fi
for file in $gitbasedir/../patch/Peter/${project}_*.patch ; do
    if [[ -s "$file" ]] ; then
        echo Apply $file
        git apply -v $file || rc=$?
    fi
done
if [[ "$rc" != 0 ]] ; then
    echo ERROR - type Y to ignore the error. >&2
    read xxxx
    if [[ "$xxxx" == Y ]] ; then
        rc=0
    fi
fi

exit $rc
