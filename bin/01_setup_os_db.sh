#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 01_setup_os_db.sh 
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
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}
export ORACLE_INVENTORY=${ORACLE_INVENTORY:-"${ORACLE_ROOT}/app/oraInventory"}

# define generic variables for software, download etc
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-true}                 # Flag to set yum clean up
export YUM="yum"
export DEFAULT_PASSWORD=${default_password:-"LAB01schulung"}
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
    --groups oinstall,osdba,osoper,osbackupdba,oskmdba,osdgdba,osracdba \
    --shell /bin/bash oracle

# add oracle to sudo
if [ -f "/etc/sudoers.d/90-cloud-init-users" ]; then
    echo "oracle ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/90-cloud-init-users
fi

# do some stuff on none docker environments
if [ ! running_in_docker ]; then
    # set the default password for the oracle user
    echo "LAB01schulung" | passwd --stdin oracle

    # copy autorized keys 
    mkdir -p /home/oracle/.ssh/
    cp ${HOME}/.ssh/authorized_keys /home/oracle/.ssh/
    chown oracle:oinstall -R /home/oracle/.ssh
    chmod 700 /home/oracle/.ssh/
    # workaround for issue #131 https://github.com/oracle/vagrant-boxes/issues/131
    export YUM="yum --disablerepo=ol7_developer"
fi

# show what we will create later on...
echo "ORACLE_ROOT       =${ORACLE_ROOT}" && \
echo "ORACLE_DATA       =${ORACLE_DATA}" && \
echo "ORACLE_ARCH       =${ORACLE_ARCH}" && \
echo "ORACLE_BASE       =${ORACLE_BASE}" && \
echo "ORACLE_INVENTORY  =${ORACLE_INVENTORY}" && \
echo "ORADBA_BASE       =${ORADBA_BASE}" && \
echo "SOFTWARE          =${SOFTWARE}" && \
echo "DOWNLOAD          =${DOWNLOAD}" 

install --owner oracle --group oinstall --mode=775 --verbose --directory \
        ${ORACLE_ROOT} \
        ${ORACLE_DATA} \
        ${ORACLE_ARCH} \
        ${ORACLE_BASE} \
        ${ORACLE_INVENTORY} \
        ${ORADBA_BASE} \
        ${SOFTWARE} \
        ${DOWNLOAD}

# create a softlink for init script usually just used for docker init
running_in_docker && ln -s ${ORACLE_DATA}/scripts /docker-entrypoint-initdb.d

# limit installation language / locals to EN
echo "%_install_langs   en" >>/etc/rpm/macros.lang

# upgrade the installation
${YUM} upgrade -y

# check for legacy yum upgrade
if [ -f "/usr/bin/ol_yum_configure.sh" ]; then
    echo "found /usr/bin/ol_yum_configure.sh "
    /usr/bin/ol_yum_configure.sh
    ${YUM} upgrade -y
fi

# Disable the oci repo
running_in_docker && yum-config-manager --disable ol7_ociyum_config

# install basic utilities
${YUM} install -y zip unzip gzip tar which

# install the oracle preinstall stuff
${YUM} install -y make passwd \
    oracle-rdbms-server-11gR2-preinstall \
    oracle-rdbms-server-12cR1-preinstall \
    oracle-database-server-12cR2-preinstall \
    oracle-database-preinstall-18c \
    oracle-database-preinstall-19c \
    elfutils-libelf-devel

# remove the groups created by oracle
for i in dba oper backupdba dgdba kmdba racdba; do
    echo "removing group $i"
    groupdel $i
done

# clean up yum repository
if [ "${CLEANUP^^}" == "TRUE" ]; then
    echo "clean up yum cache"
    ${YUM} clean all
    rm -rf /var/cache/yum
else
    echo "yum cache is not cleaned up"
fi

# - add PDB OS user ---------------------------------------------------------
# add an restricted group
groupadd restricted

# add a users
useradd --create-home --gid restricted --shell /bin/bash oracdb
useradd --create-home --gid restricted --shell /bin/bash orapdb
useradd --create-home --gid restricted --shell /bin/bash orasec

# set the password
echo ${DEFAULT_PASSWORD} | passwd oracdb --stdin
echo ${DEFAULT_PASSWORD} | passwd orapdb --stdin
echo ${DEFAULT_PASSWORD} | passwd orasec --stdin
# - EOF add PDB OS user -----------------------------------------------------

# create a bunch of other directories
mkdir -p ${ORACLE_BASE}/archive
mkdir -p ${ORACLE_BASE}/etc
mkdir -p ${ORACLE_BASE}/tmp
mkdir -p ${ORACLE_DATA}/scripts
mkdir -p ${ORADBA_BIN}
mkdir -p ${ORADBA_RSP}

# create a softlink for oratab
touch ${ORACLE_BASE}/etc/oratab
ln -sf ${ORACLE_BASE}/etc/oratab /etc/oratab

# change owner of ORACLE_BASE and ORACLE_INVENTORY
chown -R oracle:oinstall ${ORACLE_BASE} ${ORACLE_INVENTORY} ${SOFTWARE}
# --- EOF --------------------------------------------------------------------