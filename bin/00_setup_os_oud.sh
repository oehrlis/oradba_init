#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 00_setup_os_oud.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to configure OEL for Oracle Unified Directory installations.
# Notes......: Script would like to be executed as root :-).
# Reference..: --
# License....: Licensed under the Universal Permissive License v 1.0 as 
#              shown at http://oss.oracle.com/licenses/upl.
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------
# - Customization -----------------------------------------------------------
 
# - End of Customization ----------------------------------------------------

# - Environment Variables ---------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}     # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-/u01}     # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-$ORACLE_ROOT/app/oracle}
export SOFTWARE="/opt/stage"
export DOWNLOAD="/tmp/download"
export CLEANUP=${CLEANUP:-true}             # Flag to set yum clean up

# - EOF Environment Variables -----------------------------------------------

# Make sure only root can run our script
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# create necessary groups
groupadd --gid 1010 oinstall

# create the oracle OS user
useradd --create-home --gid oinstall \
    --shell /bin/bash oracle

# set the default password for the oracle user
echo "manager" | passwd --stdin oracle

# create the directory tree
install --owner oracle --group oinstall --mode=775 --verbose --directory \
        ${ORACLE_ROOT} \
        ${ORACLE_DATA} \
        ${ORACLE_BASE} \
        ${SOFTWARE} \
        ${DOWNLOAD}

# create a softlink for init script usually just used for docker init
ln -s ${ORACLE_DATA}/scripts /docker-entrypoint-initdb.d && \

# limit installation language / locals to EN
echo "%_install_langs   en" >>/etc/rpm/macros.lang && \

# upgrade the installation
yum upgrade -y

# install basic utilities
yum install -y libaio gzip tar

# clean up yum repository
if [ "${CLEANUP^^}" == "TRUE" ]; then
    echo "clean up yum cache"
    yum clean all 
    rm -rf /var/cache/yum
else
    echo "yum cache is not cleaned up"
fi

# create a bunch of other directories
mkdir -p ${ORACLE_BASE}/etc
mkdir -p ${ORACLE_BASE}/tmp
mkdir -p ${ORADBA_BIN}
mkdir -p ${ORADBA_RSP}

# change owner of ORACLE_BASE
chown -R oracle:oinstall ${ORACLE_BASE} ${SOFTWARE}

# add 3DES_EDE_CBC for Oracle EUS
JAVA_SECURITY=$(find /usr/java -name java.db 2>/dev/null)
if [ ! -z ${JAVA_SECURITY} ] && [ -f ${JAVA_SECURITY} ]; then
    sed -i 's/, 3DES_EDE_CBC//' ${JAVA_SECURITY}
fi

# --- EOF --------------------------------------------------------------------