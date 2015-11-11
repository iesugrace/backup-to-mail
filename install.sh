#!/bin/bash
# Desc: check dependencies, setup directories, config files, and scripts

err() {
    echo "$*" >&2
}

check_dep() {
    for prog in $DEP
    do
        path=$(which $prog)
        if test -z "$path"; then
            err "$prog not found"
            return 1
        fi
        if test ! -x "$path"; then
            err "$path not executable"
            return 1
        fi
    done
    return 0
}

# prompt to the terminal and get input
ask() {
    local INVISIBLE message default input
    if test "$1" = "-s"; then
        INVISIBLE="-s"
        shift
    fi
    message=$1
    default=$2
    while true
    do
        # stdout been captured, we use stderr instead
        echo -n "$message [$default]: " >&2
        read $INVISIBLE input
        test -n "$INVISIBLE" && echo >&2   # output a newline when no-echo
        if test -z "$input"; then
            if test -z "$default"; then
                echo "invalid input" >&2
                continue
            else
                input=$default
            fi
        fi
        echo "$input"
        return 0
    done
}

collect_basedir() {
    local BASEDIR
    while true
    do
        BASEDIR=$(ask "base directory" "$DEFAULT_BASEDIR")
        if test -e "$BASEDIR"; then
            echo "already exists: $BASEDIR" >&2
            continue
        else
            break
        fi
    done
    echo "$BASEDIR"
}
# collect information from the user and the system
collect_info() {
    MSMTP=$(which msmtp)
    PROCMAIL=$(which procmail)
    BASEDIR=$(collect_basedir)
    EMAILADDR=$(ask "email address")
    USERNAME=$(ask "user name" "$EMAILADDR")
    PASSWORD=$(ask -s "password")
    local domain_name=$(awk -F@ '{print $2}' <<< "$EMAILADDR")
    SMTPSERVER=$(ask "sending server" "smtp.$domain_name")
    POPSERVER=$(ask "receiving server" "pop.$domain_name")
}

copy_structure() {
    cp -rv install-data/structure $BASEDIR
}

DEP="mutt msmtp gpg getmail"
DEFAULT_BASEDIR="$HOME/.backup_to_mail"
cd $(dirname $0)

if ! check_dep; then
    exit 1
fi

# collect info
collect_info

# copy the directory structure
copy_structure
#debug
exit

# update the config file with the supplied info
update_configs

# copy the scripts
copy_scripts
