#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 00_setup_os_db.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to configure OEL for Oracle Database installations.
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
curl -f https://codeload.github.com/oehrlis/oradba_init/zip/master -o oradba_init.zip

# - Environment Variables ---------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}     # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-/u01}     # Oracle data folder eg volume for docker
export ORACLE_ARCH=${ORACLE_ARCH:-/u02}     # Oracle arch folder eg volume for docker
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
groupadd --gid 1020 osdba
groupadd --gid 1030 osoper
groupadd --gid 1040 osbackupdba
groupadd --gid 1050 oskmdba
groupadd --gid 1060 osdgdba
groupadd --gid 1070 osracdba

# create the oracle OS user
useradd --create-home --gid oinstall \
    --groups osdba,osoper,osbackupdba,oskmdba,osdgdba,osracdba \
    --shell /bin/bash oracle

# create the directory tree
install --owner oracle --group oinstall --mode=775 --verbose --directory \
        ${ORACLE_ROOT} \
        ${ORACLE_DATA} \
        ${ORACLE_ARCH} \
        ${ORACLE_BASE} \
        ${ORADBA_BASE} \
        ${SOFTWARE} \
        ${DOWNLOAD}

# create a softlink for init script usually just used for docker init
ln -s ${ORACLE_DATA}/scripts /docker-entrypoint-initdb.d && \

# limit installation language / locals to EN
echo "%_install_langs   en" >>/etc/rpm/macros.lang && \

# upgrade the installation
yum upgrade -y

# install basic utilities
yum install -y zip unzip gzip tar which

# install the oracle preinstall stuff
yum install -y \
    oracle-rdbms-server-11gR2-preinstall \
    oracle-rdbms-server-12cR1-preinstall \
    oracle-database-server-12cR2-preinstall \
    oracle-database-preinstall-18c

# remove the groups created by oracle
for i in dba oper backupdba dgdba kmdba racdba; do
    echo "removing group $i"
    groupdel $i
done

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
mkdir -p ${ORACLE_DATA}/scripts
mkdir -p ${ORADBA_BIN}
mkdir -p ${ORADBA_RSP}

# create a softlink for oratab
touch ${ORACLE_BASE}/etc/oratab
ln -sf ${ORACLE_BASE}/etc/oratab /etc/oratab

# change owner of ORACLE_BASE
chown -R oracle:oinstall ${ORACLE_BASE}

# --- EOF --------------------------------------------------------------------