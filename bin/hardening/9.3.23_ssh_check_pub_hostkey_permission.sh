#!/bin/bash

#
# harbian audit 7/8/9  Hardening
#

#
# 9.3.23 Check SSH public host key permission (Scored)
# Authors : Samson wen, Samson <sccxboy@gmail.com>
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2


# This function will be called if the script status is on enabled / audit mode
audit () {
    if [ $(find /etc/ssh/ -name "*.pub" -perm /133 | wc -l) -gt 0 ]; then
        crit "There are file file has a mode more permissive than "0644""
        FNRET=1
    else
        ok "Not any file has a mode more permissive than "0644""
		FNRET=0
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if [ $FNRET = 0 ]; then
        ok "any file has a mode more permissive than "0644""
    else
        warn "Set ssh public host key permission to 0644"
        find /etc/ssh/ -name "*.pub" -perm /133 -exec chmod 0644 {} \;
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
