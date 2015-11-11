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
        if test -z "$default"; then
            echo -n "$message: " >&2
        else
            echo -n "$message [$default]: " >&2
        fi
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

collect_scriptdir() {
    local SCRIPTDIR
    while true
    do
        SCRIPTDIR=$(ask "script directory" "$DEFAULT_SCRIPTDIR")
        if test ! -e "$SCRIPTDIR"; then
            echo "not exists: $SCRIPTDIR" >&2
            continue
        elif test ! -w "$SCRIPTDIR"; then
            echo "not writable: $SCRIPTDIR" >&2
            continue
        elif ! echo "$PATH" | grep -qE "$SCRIPTDIR"; then
            echo "not in PATH: $SCRIPTDIR" >&2
            continue
        else
            break
        fi
    done
    echo "$SCRIPTDIR"
}

collect_gpgkeyid() {
    local GPGKEYID
    while true
    do
        GPGKEYID=$(ask "gpg key id" "$DEFAULT_GPGKEYID")
        if ! gpg --list-key | grep -qE "$GPGKEYID"; then
            echo "not exists: $GPGKEYID" >&2
            continue
        else
            break
        fi
    done
    echo "$GPGKEYID"
}

# collect information from the user and the system
collect_info() {
cat << EOF
---------------- NOTECE -----------------------
Text in the square bracket is the default
value, press enter to accept it, empty value
is not allowed. 

'base directory': you shall accept the default
unless the path already exists.

'sending server': support SMTP only.

'receiving server': not used for backup, you
can accept the same value as the sending one.

'script directory': shall be in you PATH, and
you shall have write permission to it.

'gpg key id': key for mail encryption, it
shall exist in you system.
-----------------------------------------------
EOF

    MSMTP=$(which msmtp)
    PROCMAIL=$(which procmail)

    BASEDIR=$(collect_basedir)
    EMAILADDR=$(ask "sending email address")
    USERNAME=$(ask "user name" "$EMAILADDR")
    PASSWORD=$(ask -s "password")
    local domain_name=$(awk -F@ '{print $2}' <<< "$EMAILADDR")
    SMTPSERVER=$(ask "sending server" "smtp.$domain_name")
    POPSERVER=$(ask "receiving server" "$SMTPSERVER")

    SCRIPTDIR=$(collect_scriptdir)
    RECIPIENT=$(ask "receiving email address")
    GPGKEYID=$(collect_gpgkeyid)
}

copy_structure() {
    cp -fr data/structure $BASEDIR
    if test $? -ne 0; then
        echo "failed to copy structural data" >&2
        exit 1
    fi
    chmod 600 $BASEDIR/conf/msmtprc
}

update_configs() {
    sed -i \
        -e "s#{{MSMTP}}#$MSMTP#g" \
        -e "s#{{PROCMAIL}}#$PROCMAIL#g" \
        -e "s#{{BASEDIR}}#$BASEDIR#g" \
        -e "s#{{EMAILADDR}}#$EMAILADDR#g" \
        -e "s#{{USERNAME}}#$USERNAME#g" \
        -e "s#{{PASSWORD}}#$PASSWORD#g" \
        -e "s#{{SMTPSERVER}}#$SMTPSERVER#g" \
        -e "s#{{POPSERVER}}#$POPSERVER#g" \
        $BASEDIR/conf/getmailrc \
        $BASEDIR/conf/msmtprc \
        $BASEDIR/conf/muttrc \
        $BASEDIR/conf/procmailrc
}

copy_scripts() {
    cp data/b2e data/fb2e $SCRIPTDIR/

    local B2E=$SCRIPTDIR/b2e
    sed -i \
        -e "s#{{RECIPIENT}}#$RECIPIENT#g" \
        -e "s#{{GPGKEYID}}#$GPGKEYID#g" \
        -e "s#{{BASEDIR}}#$BASEDIR#g" \
        -e "s#{{B2E}}#$B2E#g" \
        $SCRIPTDIR/b2e \
        $SCRIPTDIR/fb2e
}

DEP="mutt msmtp gpg getmail"
DEFAULT_BASEDIR="$HOME/.backup_to_mail"
DEFAULT_SCRIPTDIR="$HOME/bin"
cd $(dirname $0)

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

exit 0
