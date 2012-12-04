#!/bin/bash

version=0.7
action=share
move=false
outfile=.
everyone=false
needsfn=true

TEMP=`getopt -o +f:g::d::mo:eu:n:lvh --long file:,get::,outfile:,delete::,move,everyone,users:,negative:,list,ls,update,version,help -n ${0##*/} -- "$@"`

if [ $? != 0 ]; then
    exit 1
fi

eval set -- "$TEMP"

while true; do
    case "$1" in
        -f|--file)
            fn=$2
            shift
            ;;
        -g|--get)
            action=get
            [ ! -z $2 ] && fn=$2
            shift
            ;;
        -m|--move)
            move=true
            ;;
        -d|--delete)
            action=remove
            [ ! -z $2 ] && fn=$2
            shift
            ;;
        -o|--output)
            outfile=$2
            shift
            ;;
        -e|--everyone)
            everyone=true
            ;;
        -u|--users)
            users=${2//,/\ }
            shift
            ;;
        -n|--negative)
            negusers=${2//,/\ }
            shift
            ;;
        -l|--list|--ls)
            action=list
            needsfn=false
            ;;
        --update)
            action=update
            needsfn=false
            ;;
        -v|--version)
            action=version
            needsfn=false
            ;;
        -h|--help)
            action=help
            needsfn=false
            ;;
        --)
            shift
            break;;
        *)
            echo "${0##*/}: not configured for option -- $1" >&2
            exit 1
            ;;
    esac
    shift
done

[ ! -z $1 ] && fn=$1 && shift

if $needsfn && [ -z $fn ]; then
    echo "${0##*/}: no filename specified" >&2
    exit 1
fi

case $action in
    share)
        if [ ! -e $fn ]; then
            echo "${0##*/}: file does not exist -- $fn" >&2
            exit 1
        fi
        if [ -d $fn ]; then
            echo "${0##*/}: file is a directory -- $fn" >&2
            exit 1
        fi
        if [ $outfile == '.' ]; then
            dir=~/.share/${fn##*/}
        else
            dir=~/.share/$outfile
        fi
        if [ -d $dir ]; then
            echo "${0##*/}: file is already shared -- $fn" >&2
            exit 1
        fi
        mkdir -p $dir
        touch $dir/.share_opts
        if $everyone; then
            fs sa $dir system:anyuser read
        fi
        if [ ! -z users ]; then
            for user in $users; do
                fs sa $dir $user read
            done
        fi
        if [ ! -z negusers ]; then
            for user in $negusers; do
                fs sa $dir $user -negative read
            done
        fi
        if $move; then
            mv $fn $dir/$outfile
            case $fn in
                /*)
                    echo "$mvfrom $fn" >> $dir/.share_opts
                    ;;
                *)
                    echo "$mvfrom $PWD/$fn" >> $dir/.share_opts
                    ;;
            esac
        else
            cp $fn $dir/$outfile
        fi
        ;;
    get)
        case $fn in
            *:*)
                user=$(cut -d: -f1 <<< $fn)
                fn=$(cut -d: -f2 <<< $fn)
                ;;
            *)
                echo "${0##*/}: specify get requests as user:file" >&2
                exit 1
                ;;
        esac
        home=$(finger -lm $user 2>&1 | head -2 | tail -1 | cut -f1 | cut -d\  -f2)
        if [ $home == $user: ]; then
            echo "${0##*/}: invalid user -- $user" >&2
            exit 1
        fi
        dir=$home/.share/$fn
        cp -i $dir/$fn $outfile
        ;;
    remove)
        dir=~/.share/$fn
        if [ ! -e $dir/$fn ]; then
            echo "${0##*/}: file does not exist -- $fn" >&2
            exit 1
        fi
        while read $line; do
            var=$(cut -d\  -f1 <<< $line)
            if [ var == 'mvfrom' ]; then
                mv $dir $(cut -d\  -f1 <<< $line)
                break
            fi
        done < $dir/.share_opts
        rm -rf $dir
        ;;
    list)
        if [ "$(ls -A ~/.share/)" ]; then
            for fn in ~/.share/{.,}*; do
                if [ ${fn##*/} != '.' -a ${fn##*/} != '..' ]; then
                    echo ${fn##*/}
                fi
            done
        fi
        ;;
    update)
        differences="`diff $0 ~2013cberman/.share/share/share 2>&1`"
        if [ $? == 0 ]; then
            echo "Up to date"
        else
            echo "Updating..."
            cp ~2013cberman/.share/share/share $0
            echo -n "Done.  View changes? "
            answered=false
            until $answered; do
                read ans
                case $ans in
                    y|yes)
                        echo -e "$differences"
                        answered=true
                        ;;
                    n|no)
                        answered=true
                        ;;
                    *)
                        echo -n "View chagnges (y/n)? "
                        ;;
                esac
            done
        fi
        ;;
    version)
        echo "share $version \
            Collin Berman wrote this"
        ;;
    help)
        echo "I'm working on this"
        ;;
    *)
        echo "${0##*/}: invalid action -- $action" >&2
        exit 1
        ;;
esac
exit 0
