# CIS Debian 7 Hardening Utility functions

#
# Sysctl 
#

has_sysctl_param_expected_result() {
    local SYSCTL_PARAM=$1
    local EXP_RESULT=$2

    if [ "$($SUDO_CMD sysctl $SYSCTL_PARAM 2>/dev/null)" = "$SYSCTL_PARAM = $EXP_RESULT" ]; then
        FNRET=0
    elif [ $? = 255 ]; then
        debug "$SYSCTL_PARAM does not exist"
        FNRET=255
    else
        debug "$SYSCTL_PARAM should be set to $EXP_RESULT"
        FNRET=1
    fi
}

does_sysctl_param_exists() {
    local SYSCTL_PARAM=$1
    if [ "$($SUDO_CMD sysctl -a 2>/dev/null |grep "$SYSCTL_PARAM" -c)" = 0 ]; then
        FNRET=1
    else
        FNRET=0
    fi
}


set_sysctl_param() {
    local SYSCTL_PARAM=$1
    local VALUE=$2
    debug "Setting $SYSCTL_PARAM to $VALUE"
    if [ "$(sysctl -w $SYSCTL_PARAM=$VALUE 2>/dev/null)" = "$SYSCTL_PARAM = $VALUE" ]; then
		echo "$SYSCTL_PARAM = $VALUE" >> /etc/sysctl.conf
        FNRET=0
    elif [ $? = 255 ]; then
        debug "$SYSCTL_PARAM does not exist"
        FNRET=255
    else
        warn "$SYSCTL_PARAM failed!"
        FNRET=1
    fi
}

#
# Dmesg 
#

does_pattern_exist_in_dmesg() {
    local PATTERN=$1
    if $($SUDO_CMD dmesg | grep -qE "$PATTERN"); then
        FNRET=0
    else
        FNRET=1
    fi
}

#
# File 
#

does_file_exist() {
    local FILE=$1
    if $SUDO_CMD [ -e $FILE ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_correct_ownership() {
    local FILE=$1
    local USER=$2
    local GROUP=$3
    local USERID=$(id -u $USER)
    local GROUPID=$(getent group $GROUP | cut -d: -f3)
    debug "$SUDO_CMD stat -c '%u %g' $FILE"
    if [ "$($SUDO_CMD stat -c "%u %g" $FILE)" = "$USERID $GROUPID" ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_correct_permissions() {
    local FILE=$1
    local PERMISSIONS=$2
    
    if [ $($SUDO_CMD stat -L -c "%a" $1) = "$PERMISSIONS" ]; then
        FNRET=0
    else
        FNRET=1
    fi 
}

does_pattern_exist_in_file() {
    local FILE=$1
    local PATTERN=$2

    debug "Checking if $PATTERN is present in $FILE"
    if $SUDO_CMD [ -r "$FILE" ] ; then
        debug "$SUDO_CMD grep -qE -- '$PATTERN' $FILE"
        if $($SUDO_CMD grep -qE -- "$PATTERN" $FILE); then
            FNRET=0
        else
            FNRET=1
        fi
    else
        debug "File $FILE is not readable!"
        FNRET=2
    fi

}

add_end_of_file() {
    local FILE=$1
    local LINE=$2

    debug "Adding $LINE at the end of $FILE"
    backup_file "$FILE"
    echo "$LINE" >> $FILE
}
    
add_line_file_before_pattern() {
    local FILE=$1
    local LINE=$2
    local PATTERN=$3

    backup_file "$FILE"
    debug "Inserting $LINE before $PATTERN in $FILE"
    PATTERN=$(sed 's@/@\\\/@g' <<< $PATTERN)
    debug "sed -i '/$PATTERN/i $LINE' $FILE"
    sed -i "/$PATTERN/i $LINE" $FILE
    FNRET=0
}

add_line_file_after_pattern() {
    local FILE=$1
    local LINE=$2
    local PATTERN=$3

    backup_file "$FILE"
    debug "Inserting $LINE before $PATTERN in $FILE"
    PATTERN=$(sed 's@/@\\\/@g' <<< $PATTERN)
    debug "sed -i '/$PATTERN/a $LINE' $FILE"
    sed -i "/$PATTERN/a $LINE" $FILE
    FNRET=0
}

replace_in_file() {
    local FILE=$1
    local SOURCE=$2
    local DESTINATION=$3

    backup_file "$FILE"
    debug "Replacing $SOURCE to $DESTINATION in $FILE"
    SOURCE=$(sed 's@/@\\\/@g' <<< $SOURCE)
    debug "sed -i 's/$SOURCE/$DESTINATION/g' $FILE"
    sed -i "s/$SOURCE/$DESTINATION/g" $FILE
    FNRET=0
}

delete_line_in_file() {
    local FILE=$1
    local PATTERN=$2

    backup_file "$FILE"
    debug "Deleting lines from $FILE containing $PATTERN"
    PATTERN=$(sed 's@/@\\\/@g' <<< $PATTERN)
    debug "sed -i '/$PATTERN/d' $FILE"
    sed -i "/$PATTERN/d" $FILE
    FNRET=0
}

#
# Users and groups
#

does_user_exist() {
    local USER=$1
    if $(getent passwd $USER >/dev/null 2>&1); then
        FNRET=0
    else
        FNRET=1
    fi
}

does_group_exist() {
    local GROUP=$1
    if $(getent group $GROUP >/dev/null 2>&1); then
        FNRET=0
    else
        FNRET=1
    fi
}

#
# Service Boot Checks
#

is_service_enabled() {
    local SERVICE=$1
    if [ $($SUDO_CMD find /etc/rc?.d/ -name "S*$SERVICE" -print | wc -l) -gt 0 ]; then
        debug "Service $SERVICE is enabled"
        FNRET=0
    else
        debug "Service $SERVICE is disabled"
        FNRET=1
    fi
}


#
# Kernel Options checks
#

is_kernel_option_enabled() {
    local KERNEL_OPTION="$1"
    local MODULE_NAME=""
    if [ $# -ge 2 ] ; then
        MODULE_NAME="$2"
    fi
    if $SUDO_CMD [ -r "/proc/config.gz" ] ; then
        RESULT=$($SUDO_CMD zgrep "^$KERNEL_OPTION=" /proc/config.gz) || :
    elif $SUDO_CMD [ -r "/boot/config-$(uname -r)" ] ; then
        RESULT=$($SUDO_CMD grep "^$KERNEL_OPTION=" "/boot/config-$(uname -r)") || :
    fi
    ANSWER=$(cut -d = -f 2 <<< "$RESULT")
    if [ "x$ANSWER" = "xy" ]; then
        debug "Kernel option $KERNEL_OPTION enabled"
        FNRET=0
    elif [ "x$ANSWER" = "xn" ]; then
        debug "Kernel option $KERNEL_OPTION disabled"
        FNRET=1
    else
        debug "Kernel option $KERNEL_OPTION not found"
        FNRET=2 # Not found
    fi

    if $SUDO_CMD [ "$FNRET" -ne 0 -a -n "$MODULE_NAME" -a -d "/lib/modules/$(uname -r)" ] ; then
        # also check in modules, because even if not =y, maybe
        # the admin compiled it separately later (or out-of-tree)
        # as a module (regardless of the fact that we have =m or not)
        debug "Checking if we have $MODULE_NAME.ko"
        local modulefile=$($SUDO_CMD find "/lib/modules/$(uname -r)/" -type f -name "$MODULE_NAME.ko")
        if $SUDO_CMD [ -n "$modulefile" ] ; then
            debug "We do have $modulefile!"
            # ... but wait, maybe it's blacklisted? check files in /etc/modprobe.d/ for "blacklist xyz"
            if grep -qRE "^\s*blacklist\s+$MODULE_NAME\s*$" /etc/modprobe.d/ ; then
                debug "... but it's blacklisted!"
                FNRET=1 # Not found (found but blacklisted)
                # FIXME: even if blacklisted, it might be present in the initrd and
                # be insmod from there... but painful to check :/ maybe lsmod would be enough ?
            fi
            FNRET=0 # Found!
        fi
    fi
}

#
# Mounting point 
#

# Verify $1 is a partition declared in fstab
is_a_partition() {

    local PARTITION=$1
    FNRET=128
    if $(grep "[[:space:]]*${PARTITION}[[:space:]]*" /etc/fstab | grep -vqE "^#"); then
        debug "$PARTITION found in fstab"
        FNRET=0
    else
        debug "Unable to find $PARTITION in fstab"
        FNRET=1
    fi
}

# Verify that $1 is mounted at runtime
is_mounted() {
    local PARTITION=$1
    if $(grep -q "[[:space:]]$1[[:space:]]" /proc/mounts); then
        debug "$PARTITION found in /proc/mounts, it's mounted"
        FNRET=0
    else
        debug "Unable to find $PARTITION in /proc/mounts"
        FNRET=1
    fi
}

# Verify $1 has the proper option $2 in fstab
has_mount_option() {
    local PARTITION=$1
    local OPTION=$2
    if $(grep "[[:space:]]$1[[:space:]]" /etc/fstab | grep -vE "^#" | awk {'print $4'} | grep -q "$2"); then
        debug "$OPTION has been detected in fstab for partition $PARTITION"
        FNRET=0
    else
        debug "Unable to find $OPTION in fstab for partition $PARTITION"
        FNRET=1
    fi
}

# Verify option $2 in $1 service
has_mount_option_systemd() {
    local SERVICENAME=$1
    local OPTION=$2
    if $(grep -i "options" "$SERVICENAME" | grep -vE "^#" | grep -q "$2"); then
        debug "$OPTION has been detected in systemd service $SERVICENAME"
        FNRET=0
    else
        debug "Unable to find $OPTION in systemd service $SERVICENAME"
        FNRET=1
    fi
}

# Verify $1 has the proper option $2 at runtime
has_mounted_option() {
    local PARTITION=$1
    local OPTION=$2
    if $(grep "[[:space:]]$1[[:space:]]" /proc/mounts | awk {'print $4'} | grep -q "$2"); then
        debug "$OPTION has been detected in /proc/mounts for partition $PARTITION"
        FNRET=0
    else
        debug "Unable to find $OPTION in /proc/mounts for partition $PARTITION"
        FNRET=1
    fi
}

# Setup mount option in fstab
# Notice: The format of the entry in the fstab file must be in the format shown in the following example, otherwise an error may occur.
add_option_to_fstab() {
    local PARTITION=$1
    local OPTION=$2
    debug "Setting $OPTION for $PARTITION in fstab"
    backup_file "/etc/fstab"
    # For example :
    # local PARTITION="/home"
    # local OPTION="nosuid"
    # UUID=40327bc9-f9d1-5816-a312-df307cc8732e /home               ext4  errors=remount-ro 0       2
    # UUID=40327bc9-f9d1-5816-a312-df307cc8732e /home               ext4  errors=remount-ro,nosuid 0       2
#    debug "Sed command :  sed -ie \"s;\(.*\)\(\s*\)\s\($PARTITION\)\s\(\s*\)\(\w*\)\(\s*\)\(\w*\)*;\1\2 \3 \4\5\6\7,$OPTION;\" /etc/fstab"
#    sed -ie "s;\(^[^#].*${PARTITION}\)\(\s.*\)\(\s\w.*\)\(\s[0-2]\s*[0-2]\);\1\2\3,${OPTION}\4;" /etc/fstab
    MOUNT_OPTION=$(grep -v "^#" /etc/fstab | awk '$2=="'${PARTITION}'" {print $4}')
    CURLINE=$(grep -v "^#" /etc/fstab -n | grep "${PARTITION}" | awk -F: '{print $1}')
    #This case is for option of starting with "no", example: nosuid noexec nodev
    NOTNOOPTION=$(echo $OPTION | cut -c 3-)

    if [ "${MOUNT_OPTION}" == "defaults" ]; then
        if [ "$OPTION" == "noexec" ]; then
       	    NEWOP='rw,nosuid,nodev,noexec,auto,async'
        else
       	    NEWOP='rw,nosuid,nodev,auto,async'
        fi
       	sed -i "${CURLINE}s/$MOUNT_OPTION/$NEWOP/" /etc/fstab
	#This case is for option of starting with "no", example: nosuid noexec nodev
    elif [ $(echo $MOUNT_OPTION | grep -cw ${NOTNOOPTION}) -gt 0 ]; then
	    sed -i "${CURLINE}s/${NOTNOOPTION}/${OPTION}/" /etc/fstab 
    elif [ $(echo $MOUNT_OPTION | grep -cw $OPTION) -eq 0 ]; then
	    sed -i "${CURLINE}s/${MOUNT_OPTION}/${MOUNT_OPTION},${OPTION}/" /etc/fstab
    fi    
}

remount_partition() {
    local PARTITION=$1
    debug "Remounting $PARTITION"
    mount -o remount $PARTITION
}

# Setup mount option in systemd
add_option_to_systemd() {
    local SERVICEPATH=$1
    local OPTION=$2
    local SERVICENAME=$3
    debug "Setting $OPTION for in systemd"
    backup_file "$SERVICEPATH"
    systemctl stop $SERVICENAME
    # For example : 
    # Options=mode=1777,strictatime,nosuid
    # Options=mode=1777,strictatime,nosuid,nodev
    #debug "Sed command : sed -ie "s;\(^Options.*=mode=[1,2,4,7][1,2,4,7][1,2,4,7][1,2,4,7].*\);\1,$OPTION;\" $SERVICEPATH"
    sed -ie "s;\(^Options.*=mode=[1,2,4,7][1,2,4,7][1,2,4,7][1,2,4,7].*\);\1,$OPTION;" $SERVICEPATH
    systemctl daemon-reload
    systemctl start $SERVICENAME
}

remount_partition_by_systemd() {
    local SERVICENAME=$1
    local PARTITION=$2
    debug "Remounting $PARTITION by systemd"
    systemctl start $SERVICENAME
}

#
# APT 
#

apt_update_if_needed() 
{
    if [ -e /var/cache/apt/pkgcache.bin ]
    then
        UPDATE_AGE=$(( $(date +%s) - $(stat -c '%Y'  /var/cache/apt/pkgcache.bin)  ))

        if [ $UPDATE_AGE -gt 3600 ]
        then
            # update too old, refresh database
            $SUDO_CMD apt-get update -y >/dev/null 2>/dev/null
        fi
    else
        $SUDO_CMD apt-get update -y >/dev/null 2>/dev/null
    fi
}

apt_check_updates()
{
    local NAME="$1"
    local DETAILS="/dev/shm/${NAME}"
    $SUDO_CMD apt-get upgrade -s 2>/dev/null | grep -E "^Inst" > $DETAILS || : 
    local COUNT=$(wc -l < "$DETAILS")
    FNRET=128 # Unknown function return result
    RESULT="" # Result output for upgrade
    if [ $COUNT -gt 0 ]; then
        RESULT="There is $COUNT updates available :\n$(cat $DETAILS)"
        FNRET=1
    else
        RESULT="OK, no updates available"
        FNRET=0
    fi
    rm $DETAILS
}

apt_install() 
{
    local PACKAGE=$1
    DEBIAN_FRONTEND='noninteractive' apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install $PACKAGE -y
    FNRET=0
}


#
#   Returns if a package is installed
#

is_pkg_installed()
{
    PKG_NAME=$1
    if $(dpkg -s $PKG_NAME 2> /dev/null | grep -q '^Status: install ') ; then
        debug "$PKG_NAME is installed"
        FNRET=0
    else
        debug "$PKG_NAME is not installed"
        FNRET=1
    fi
}

is_debian_9()
{
    if $(cat /etc/debian_version | grep -q "^9.[0-9]"); then
        debug "Debian version is 9.*."
        FNRET=0
    else
        debug "Debian version is not 9.*."
        FNRET=1
    fi
}

verify_integrity_all_packages()
{
	dpkg -V > /dev/shm/dpkg_verify_ret
    if [ $(cat /dev/shm/dpkg_verify_ret | wc -l) -gt 0 ]; then
        debug "Verify integrity all packages is fail"
		cat /dev/shm/dpkg_verify_ret
        FNRET=1
    else
        debug "Verify integrity all packages is OK"
        FNRET=0
    fi
}

check_param_pair_by_pam()
{   
    LOCATION=$1
    KEYWORD=$2
    OPTION=$3
    COMPARE=$4
    CONDITION=$5

    #Example:
    #LOCATION="/etc/pam.d/common-password"
    #LOCATION="/etc/pam.d/login"
    #KEYWORD="pam_cracklib.so"
    #OPTION="ocredit"
    #COMPARE="gt"
    #CONDITION="-1"
    if [ -f "$LOCATION" ];then
        RESULT=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' $LOCATION | grep -w "$KEYWORD.*$OPTION" | wc -l)
        echo $RESULT
        if [ "$RESULT" -eq 1 ]; then
            debug "$KEYWORD $OPTION is conf"
            cndt_value=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' $LOCATION | grep "$KEYWORD.*$OPTION" | tr "\t" " " | tr " " "\n" | sed -n "/$OPTION/p" | awk -F "=" '{print $2}')
            if [ "$cndt_value" "-$COMPARE" "$CONDITION" ]; then
                debug "$cndt_value -$COMPARE  $CONDITION is ok"
                FNRET=0
            else
                debug "$cndt_value -$COMPARE  $CONDITION is not ok"
                FNRET=5
            fi 
            
        else
            debug "$KEYWORD $OPTION is not conf"
            FNRET=4
        fi
    else
        debug "$LOCATION is not exist"
        FNRET=3   
    fi
}

# Only check option name 
check_no_param_option_by_pam()
{   
    KEYWORD=$1
    OPTION=$2
    LOCATION=$3

    #Example:
    #KEYWORD="pam_unix.so"
    #OPTION="sha512"
    #LOCATION="/etc/pam.d/common-password"
    
    if [ -f "$LOCATION" ];then
        RESULT=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' $LOCATION | grep "$KEYWORD.*$OPTION" | wc -l)
        echo $RESULT
        if [ "$RESULT" -eq 1 ]; then
            debug "$KEYWORD $OPTION is conf"
            FNRET=0
        else
            debug "$KEYWORD $OPTION is not conf"
            FNRET=4
        fi
    else
        debug "$LOCATION is not exist"
        FNRET=3   
    fi
}

# Add password check option 
add_option_to_password_check() 
{
    #Example:
    #local PAMPWDFILE="/etc/pam.d/common-password"
    #local KEYWORD="pam_cracklib.so"
    #local OPTIONSTR="retry=3"
    local PAMPWDFILE=$1
    local KEYWORD=$2
    local OPTIONSTR=$3
    debug "Setting $OPTIONSTR for $KEYWORD"
    backup_file "$PAMPWDFILE"
    # For example : 
    # password  requisite           pam_cracklib.so  minlen=8 difok=3
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=3
    sed -i "s;\(^password.*$KEYWORD.*\);\1 $OPTIONSTR;" $PAMPWDFILE  
}

# Add session check option 
add_option_to_session_check() 
{
    #Example:
    #local PAMPWDFILE="/etc/pam.d/login"
    #local KEYWORD="pam_lastlog.so"
    #local OPTIONSTR="showfailed"
    local PAMPWDFILE=$1
    local KEYWORD=$2
    local OPTIONSTR=$3
    debug "Setting $OPTIONSTR for $KEYWORD"
    backup_file "$PAMPWDFILE"
    # For example : 
    # password  requisite           pam_cracklib.so  minlen=8 difok=3
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=3
    sed -i "s;\(^session.*$KEYWORD.*\);\1 $OPTIONSTR;" $PAMPWDFILE  
}


# Add auth check option 
add_option_to_auth_check() 
{
    #Example:
    #local PAMPWDFILE="/etc/pam.d/common-auth"
    #local KEYWORD="pam_cracklib.so"
    #local OPTIONSTR="retry=3"
    local PAMPWDFILE=$1
    local KEYWORD=$2
    local OPTIONSTR=$3
    debug "Setting $OPTIONSTR for $KEYWORD"
    backup_file "$PAMPWDFILE"
    # For example : 
    # password  requisite           pam_cracklib.so  minlen=8 difok=3
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=3
    sed -i "s;\(^auth.*$KEYWORD.*\);\1 $OPTIONSTR;" $PAMPWDFILE  
}

# Reset password check option value when option is not set a correct value 
reset_option_to_password_check()
{
    #Example:
    #local PAMPWDFILE="/etc/pam.d/common-password"
    #local KEYWORD="pam_cracklib.so"
    #local OPTIONNAME="retry"
    #local OPTIONVAL="3"
    local PAMPWDFILE=$1
    local KEYWORD=$2
    local OPTIONNAME=$3
    local OPTIONVAL=$4
    debug "Setting $OPTION for $KEYWORD reset option value to $OPTIONVAL"
    backup_file "$PAMPWDFILE"
    # For example : 
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=1
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=3
    sed -i "s/${OPTIONNAME}=./${OPTIONNAME}=${OPTIONVAL}/" $PAMPWDFILE
}

# Reset auth check option value when option is not set a correct value 
reset_option_to_auth_check()
{
    #Example:
    #local PAMPWDFILE="/etc/pam.d/common-password"
    #local KEYWORD="pam_cracklib.so"
    #local OPTIONNAME="retry"
    #local OPTIONVAL="3"
    local PAMPWDFILE=$1
    local KEYWORD=$2
    local OPTIONNAME=$3
    local OPTIONVAL=$4
    debug "Setting $OPTION for $KEYWORD reset option value to $OPTIONVAL"
    backup_file "$PAMPWDFILE"
    # For example : 
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=1
    # password  requisite           pam_cracklib.so  minlen=8 difok=3 retry=3
    sed -i "s/${OPTIONNAME}=.*/${OPTIONNAME}=${OPTIONVAL}/" $PAMPWDFILE
}

# Only check option name 
check_auth_option_nullok_by_pam()
{   
    KEYWORD=$1
    OPTION1=$2
    OPTION2=$3

    LOCATION="/etc/pam.d/common-auth"

    #Example:
    #KEYWORD="pam_unix.so"
    #OPTION1="nullok"
    #OPTION2="nullok_secure"
    
    if [ -f "$LOCATION" ];then
        RESULT=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' $LOCATION | grep "$KEYWORD.*$OPTION2" | wc -l)
        if [ "$RESULT" -eq 1 ]; then
            debug "$KEYWORD $OPTION2 is conf, that is error conf"
            FNRET=5
        else
            debug "$KEYWORD $OPTION2 is not conf, that is ok"
            RESULT=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' $LOCATION | grep "$KEYWORD.*$OPTION1" | wc -l)
            if [ "$RESULT" -eq 1 ]; then
                debug "$KEYWORD $OPTION1 is conf, that is error conf"
                FNRET=4
            else
                debug "$KEYWORD $OPTION1 is not conf, that is ok"
                FNRET=0
            fi
        fi
    else
        debug "$LOCATION is not exist"
        FNRET=3   
    fi
}

