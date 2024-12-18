#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Data Platforms
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 01_setup_os_db.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Script to configure OEL for Oracle Database installations.
# Notes......: Script would like to be executed as root :-).
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
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
export DEFAULT_PASSWORD=${default_password:-"LAB01schulung"}

# - EOF Environment Variables -----------------------------------------------

# Make sure only root can run our script
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# create necessary groups
getent group oinstall || groupadd --gid 1010 oinstall
getent group osdba || groupadd --gid 1020 osdba
getent group osoper || groupadd --gid 1030 osoper
getent group osbackupdba || groupadd --gid 1040 osbackupdba
getent group oskmdba || groupadd --gid 1050 oskmdba
getent group osdgdba || groupadd --gid 1060 osdgdba
getent group osracdba || groupadd --gid 1070 osracdba

# create/modify the oracle OS user
if id "oracle" &>/dev/null; then
    usermod --gid oinstall \
        --groups oinstall,osdba,osoper,osbackupdba,oskmdba,osdgdba,osracdba \
        --shell /bin/bash oracle
else
    useradd --create-home --gid oinstall \
        --groups oinstall,osdba,osoper,osbackupdba,oskmdba,osdgdba,osracdba \
        --shell /bin/bash oracle
fi

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
    chown oracle:oinstall -vR /home/oracle/.ssh
    chmod 700 /home/oracle/.ssh/
    # workaround for issue #131 https://github.com/oracle/vagrant-boxes/issues/131
    export YUM="yum --disablerepo=ol7_developer"
fi

# show what we will create later on...
echo " - Prepare DB server OS> installation ---------------------------------"
echo " - ORACLE_ROOT       = ${ORACLE_ROOT}" 
echo " - ORACLE_DATA       = ${ORACLE_DATA}" 
echo " - ORACLE_ARCH       = ${ORACLE_ARCH}" 
echo " - ORACLE_BASE       = ${ORACLE_BASE}" 
echo " - ORACLE_INVENTORY  = ${ORACLE_INVENTORY}" 
echo " - ORADBA_BASE       = ${ORADBA_BASE}" 
echo " - SOFTWARE          = ${SOFTWARE}" 
echo " - DOWNLOAD          = ${DOWNLOAD}" 

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

# check if we do have yum installed. If not we assume that we do have to install it using microdnf
if [ -z $(command -v yum) ]; then  
    echo " - yum not found. try to install it using microdnf"
    microdnf install -y yum
    yum install -y yum-utils
else 
    echo " - yum is here"
fi

# limit installation language / locals to EN
echo "%_install_langs   en" >>/etc/rpm/macros.lang

if [ $(grep -ic "7\." /etc/redhat-release) -eq 1 ]; then 
    # Disable the oci repo
    running_in_docker && yum-config-manager --disable ol7_ociyum_config
elif [ $(grep -ic "8\." /etc/redhat-release) -eq 1 ]; then
    yum install -y oracle-epel-release-el8
    yum-config-manager --enable ol8_addons
    running_in_docker &&  echo "tsflags=nodocs" >>/etc/yum.conf # set nodocs in docker
elif [ $(grep -ic "9\." /etc/redhat-release) -eq 1 ]; then
    yum install -y oracle-epel-release-el9
    yum-config-manager --enable ol9_addons
    running_in_docker &&  echo "tsflags=nodocs" >>/etc/yum.conf # set nodocs in docker
fi

# update and upgrade the installation
yum update -y
yum upgrade -y

# check for legacy yum upgrade
if [ -f "/usr/bin/ol_yum_configure.sh" ]; then
    echo " - found /usr/bin/ol_yum_configure.sh "
    /usr/bin/ol_yum_configure.sh
    yum upgrade -y
fi

# install basic utilities
yum install -y zip unzip gzip tar which pwgen
yum install -y make passwd elfutils-libelf-devel rlwrap
# install the oracle preinstall stuff
for i in $(yum list available oracle-database-preinstall*|grep -iv 23c|grep -i $(uname -p)|cut -d' ' -f1); do
    echo " - install $i";
    yum install -y $i;
done

# remove the groups created by oracle
for i in dba oper backupdba dgdba kmdba racdba; do
    getent group $i && echo " - removing group $i" && groupdel $i
done

# clean up yum repository
if [ "${CLEANUP^^}" == "TRUE" ]; then
    echo " - clean up yum cache"
    yum clean all
    rm -rf /var/cache/yum
else
    echo " - yum cache is not cleaned up"
fi

# - add PDB OS user ---------------------------------------------------------
# add an restricted group
getent group restricted || groupadd restricted

# add a users
for i in oracdb orapdb orasec; do
    if ! id "$i" &>/dev/null; then
        useradd --create-home --gid restricted --shell /bin/bash $i
        # set the password
        echo ${DEFAULT_PASSWORD} | passwd $i --stdin
    fi
done

# - EOF add PDB OS user -----------------------------------------------------

# create a bunch of other directories
mkdir -vp ${ORACLE_BASE}/archive
mkdir -vp ${ORACLE_BASE}/audit
mkdir -vp ${ORACLE_BASE}/cfgtoollogs
mkdir -vp ${ORACLE_BASE}/etc
mkdir -vp ${ORACLE_BASE}/tmp
mkdir -vp ${ORACLE_DATA}/scripts
mkdir -vp ${ORADBA_BIN}
mkdir -vp ${ORADBA_RSP}

# create a softlink for oratab
touch ${ORACLE_BASE}/etc/oratab
ln -sf ${ORACLE_BASE}/etc/oratab /etc/oratab

# change owner of ORACLE_BASE and ORACLE_INVENTORY
chown -vR oracle:oinstall ${ORACLE_BASE} ${ORACLE_INVENTORY} ${SOFTWARE}
# --- EOF --------------------------------------------------------------------