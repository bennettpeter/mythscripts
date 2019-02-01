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
        # Reset timestamp on all the files after unpatching.
        # This is to make sure install does not try to build them again.
        filelist=`grep "^diff --git" "$file" | sed "s#diff --git ##;s#a/##;s# b/.*##"`
        pushd "$gitbasedir"
        mkdir /tmp/build$$/
        cp -p $filelist /tmp/build$$
        rrc=0
        git apply --reverse $file || rrc=$?
        for sfile in $filelist ; do
            if [[ "$rrc" == 0 ]] ; then
                touch $sfile -r /tmp/build$$/`basename $sfile`
            fi
            rm -f /tmp/build$$/`basename $sfile`
        done
        popd
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
if [[ "$option" == Peter }} ; then
    for file in $gitbasedir/../patch/Peter/${project}_*.patch ; do
        if [[ -s "$file" ]] ; then
            echo Apply $file
            git apply -v $file || rc=$?
        fi
    done
fi
if [[ "$rc" != 0 ]] ; then
    echo ERROR - type Y to ignore the error. >&2
    read xxxx
    if [[ "$xxxx" == Y ]] ; then
        rc=0
    fi
fi

exit $rc
