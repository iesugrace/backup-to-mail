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

collect_info() {
    MSMTP=$(which msmtp)
    PROCMAIL=$(which procmail)
    BASEDIR=$(ask "base directory" "$DEFAULT_BASEDIR")
    EMAILADDR=$(ask "email address")
    USERNAME=$(ask "user name" "$EMAILADDR")
    PASSWORD=$(ask -s "password")
    local domain_name=$(awk -F@ '{print $2}' <<< "$EMAILADDR")
    SMTPSERVER=$(ask -s "sending server" "smtp.$domain_name")
    POPSERVER=$(ask -s "receiving server" "pop.$domain_name")
}

DEP="mutt msmtp gpg getmail"
DEFAULT_BASEDIR="$HOME/.backup_to_mail"

if ! check_dep; then
    exit 1
fi

# collect info
collect_info

# copy the directory structure
copy_structure

# update the config file with the supplied info
update_configs

# copy the scripts
copy_scripts
