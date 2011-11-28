#!/bin/bash

# plan
    echo 1..35

# settings/defines
    export rr=$HOME/gitpod-remote-repos

# basic necessities
    set -e
    die() { echo "$@" >&2; exit 1; }

# clean slate
    cd $HOME
    rm -rf $rr non-bare r[1234].git sub[1234] u .gitpod.rc

# check git-test and gitpod are in $PATH
    which git-test  >/dev/null || die 'git-test  not in PATH'
    which gitpod >/dev/null || die 'gitpod not in PATH'

# check login shell is also the same
    [ `/usr/bin/which gitpod` = `grep ^$USER: /etc/passwd | cut -f7 -d:` ] || die login shell is not the right one

# check ssh setup
    ssh -o preferredauthentications=publickey $USER@localhost info | grep hello,.this.is.gitpod >/dev/null || die ssh setup not complete

# prepare to create the "remote" repositories
    mkdir -p $rr/r{1,2,3,4}
    git config --get user.name &>/dev/null || {
        git config --global user.name 'git cephalopod'
        git config --global user.email 'git-cephalopod@example.com'
    }

# make 4 "remote" repositories
    for r in  r1 r2 r3 r4
    do
        cd $rr/$r
        git init --bare &>/dev/null

        cd $HOME
        rm -rf non-bare
        git clone $rr/$r non-bare &>/dev/null
        cd non-bare

        git-test "
            $r; m1; m2; branch AA; m3; m4
            checkout AA; a1; a2
            push --all origin
            /new.branch.*AA.*AA/
            /new.branch.*master.*master/
        "
    done

    cd $HOME
    mkdir sub2 sub4

# "clone" the first 2 repos using local commands
    gitpod clone file:///$rr/r1 r1 &>/dev/null
    gitpod clone file:///$rr/r2 sub2/r2 &>/dev/null

# now setup the other 2 using ssh
    ssh $USER@localhost clone file:///$rr/r3 r3 &>/dev/null
    ssh $USER@localhost clone file:///$rr/r4 sub4/r4 &>/dev/null

    git-test "
    ## check the repos
        git ls-remote r1.git
        /3ba846a/; /fc7a819/
        git ls-remote sub2/r2.git
        /c4c7d55/; /50d9881/

        git ls-remote r3.git
        /b499b19/; /e4cc88d/
        git ls-remote sub4/r4.git
        /af0f123/; /cd3734f/

        sh ssh $USER@localhost info
        /r1/
        /r3/
        /sub2/r2/
        /sub4/r4/

    ## empty fetch
        sh ssh $USER@localhost fetch r1; /fetching from/; !/From file/

    ## macro
    # define a macro for a frequently used sequence of steps
        DEF delete-AA = cd $HOME/r1.git; branch -D AA; /Deleted branch AA/; git gc --prune=now; cd $HOME

    ## non-empty fetch
        delete-AA; sh ssh $USER@localhost fetch r1; /fetching from/; /From file/

    ## userclone
        sh mkdir u
        git clone $USER@localhost:r1 u/r1; cd u/r1; git ls-remote origin; ok; /3ba846a/; /fc7a819/

    ## automatic fetch
    # it should fetch one automatically here
        delete-AA; cd $HOME/u/r1; git fetch; /new.branch.*AA.*AA/

    # and here it shouldn't
        cd u/r1; git fetch; !/new.branch.*AA.*AA/

    ## lazy mode
        sh echo LAZY = all > $HOME/.gitpod.rc

    # automatic fetch should fail due to lazy mode
        delete-AA; cd $HOME/u/r1; git fetch; !/new.branch.*AA.*AA/

    ## manual fetch
    # via ssh
        sh ssh $USER@localhost fetch r1; /new.branch.*AA.*AA/

    # from local shell
        delete-AA; sh gitpod fetch r1; /new.branch.*AA.*AA/

    " || die TEST FAILED

echo DONE
