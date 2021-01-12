#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 02_setup_oracle_volume.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2021.01.11
# Revision...: 
# Purpose....: Script to configure a volume group and lvs for oracle .
# Notes......: Script would like to be executed as root :-).
# Reference..: --
# License....: Licensed under the Universal Permissive License v 1.0 as 
#              shown at http://oss.oracle.com/licenses/upl.
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------

# - Environment Variables ---------------------------------------------------
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}       # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}       # Oracle data folder eg volume for docker
export ORACLE_ARCH=${ORACLE_ARCH:-"/u02"}       # Oracle arch folder eg volume for docker
export MOUNT_POINTS="${ORACLE_ROOT} ${ORACLE_DATA} ${ORACLE_ARCH}" # list of mount points
export VOLUME_GROUP="vgora"
# - EOF Environment Variables -----------------------------------------------

# Make sure only root can run our script
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# create a unique list of mount points
UNIQUE_MOUNT_POINTS=$(echo "${MOUNT_POINTS}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

# create partition
echo "INFO: Check for additional disk device -----------------------------------"
DISK_DEV=$(lsblk -o NAME,FSTYPE -pdsn | awk '$2 == "" {print $1}')
if [ ! -z ${DISK_DEV} ]; then
    echo "INFO: Found additional disk device ${DISK_DEV}"
    mkdir -vp /u99
    echo "INFO: Create partition"
    sfdisk ${DISK_DEV} <<EOF
,,8e
EOF
    echo "INFO: List partitions for ${DISK_DEV}"
    fdisk -l ${DISK_DEV}
    echo "INFO: List block devices"
    lsblk

    DISK_DEV_PARTITION="${DISK_DEV}1"
    echo "INFO: Create a physical volume on ${DISK_DEV_PARTITION}."
    pvcreate ${DISK_DEV_PARTITION}
    pvs
    pvdisplay ${DISK_DEV_PARTITION}

    echo "INFO: Create volume group vgora"
    vgcreate ${VOLUME_GROUP} ${DISK_DEV_PARTITION}
    vgdisplay ${VOLUME_GROUP}

    for i in ${UNIQUE_MOUNT_POINTS}; do
        echo "INFO: move existing ${i} folder to /u99"
        vol_name="vol_$(echo ${i}|sed 's/^\///')"
        mv -v ${i} /u99
        echo "INFO: Create logical volume ${vol_name} in ${VOLUME_GROUP}"
        lvcreate -n ${vol_name} -l 30%VG ${VOLUME_GROUP}  
        echo "INFO: Create filesystem for ${vol_name}"
        mkfs.ext4 /dev/${VOLUME_GROUP}/${vol_name}
        mkdir -vp ${i}
        echo "INFO: Update fstab for mountpoint ${i}"
        echo "$(blkid /dev/${VOLUME_GROUP}/${vol_name}|cut -d' ' -f2|tr -d '"')   ${i}    ext4   defaults,noatime,_netdev     0   0" >>/etc/fstab
        mount ${i}
        echo "INFO: Move existing stuff to ${i}"
        mv -v /u99/${i}/* ${i}/
        rm -rvf /u99/${i}
    done
    echo "INFO: remove /u99"
    rm -rf /u99
else
    echo "INFO: No additional disk device found"
fi
# --- EOF --------------------------------------------------------------------