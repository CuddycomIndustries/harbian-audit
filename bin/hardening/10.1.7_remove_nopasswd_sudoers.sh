#!/bin/bash

#
# harbian audit 7/8/9  Hardening
#

#
# 10.1.7 Remove nopasswd option from the sudoers configuration (Scored)
# Authors : Samson wen, Samson <sccxboy@gmail.com>
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3

NOPASSWD='NOPASSWD'
PASSWD='PASSWD'
FILE='/etc/sudoers'
INCLUDFILE='/etc/sudoers.d/*'

# This function will be called if the script status is on enabled / audit mode
audit () 
{
	does_file_exist $FILE 
    if [ $FNRET != 0 ]; then
		crit "$FILE is not exist!"
		FNRET=2
	else
    	does_pattern_exist_in_file $FILE $NOPASSWD
    	if [ $FNRET = 0 ]; then
        	crit "$NOPASSWD is set on $FILE, it's error conf"
        	FNRET=1
    	else
        	ok "$NOPASSWD is not set on $FILE, it's ok"
        	if [ $(grep -c $NOPASSWD $INCLUDFILE) -gt 0 ]; then 
            	crit "$NOPASSWD is set on $INCLUDFILE, it's error conf"
            	FNRET=1
        	else
            	ok "$NOPASSWD is not set on $INCLUDFILE, it's ok"
            	FNRET=0
        	fi
    	fi
	fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if [ $FNRET = 0 ]; then
        ok "APPLY: $NOPASSWD is not set on $FILE, it's ok"
    elif [ $FNRET = 1 ]; then
        info "$NOPASSWD is set on the $FILE or $INCLUDFILE, need remove"
        backup_file $FILE $INCLUDFILE
        chmod 640 $FILE $INCLUDFILE &&  sed -i -e "s/$NOPASSWD/$PASSWD/g" $FILE $INCLUDFILE && chmod 440 $FILE $INCLUDFILE
    elif [ $FNRET = 2 ]; then
		warn "$FILE is not exist! Maybe sudo package not installed."
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
