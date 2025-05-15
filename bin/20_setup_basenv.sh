#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 20_setup_basenv.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Script to setup and configure TVD-Basenv.
# Notes......: - Script would like to be executed as oracle :-)
#              - If the required software is not in /opt/stage, an attempt is
#                made to download the software package with curl from 
#                ${SOFTWARE_REPO} In this case, the environment variable must 
#                point to a corresponding URL.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
ORADBA_BIN=$(dirname ${BASH_SOURCE[0]})
# - End of Customization -------------------------------------------------------

# - Environment Variables ------------------------------------------------------
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define the software packages
export BASENV_PKG=${BASENV_PKG:-"basenv-21.05.final.b.zip"}
export BASENV_ORADBA=${BASENV_ORADBA:-"basenv-20.05.final.b.zip"}
export BACKUP_PKG=${BACKUP_PKG:-"tvdbackup-se-21.05.final.a.tar.gz"}
export TVDPERL_PKG=${TVDPERL_PKG:-""}
export PROCESSOR=$(uname -m)

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder
export ORADBA_DEBUG=${ORADBA_DEBUG:-"FALSE"}    # enable debug mode

export DEFAULT_DOMAIN=${DEFAULT_DOMAIN:-$(domainname 2>/dev/null ||cat /etc/domainname ||echo "postgasse.org")}

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}       # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}       # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-$ORACLE_ROOT/app/oracle}
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}
export ETC_BASE=${ETC_BASE:-${ORACLE_LOCAL}/dba}

# set the default ORACLE_HOME based on find results for oraenv
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product -name oraenv |sort -r|head -1)))}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-$(basename ${ORACLE_HOME})}

# define generic variables for software, download etc
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-"true"}               # Flag to set yum clean up
# - EOF Environment Variables --------------------------------------------------

# - Initialization -------------------------------------------------------------

# Make sure root does not run our script
if [ ! $EUID -ne 0 ]; then
   echo " - ERROR: This script must not be run as root" 1>&2
   exit 1
fi

echo " - Prepare response file ----------------------------------------------"
echo " - ORACLE_BASE    = $ORACLE_BASE"
echo " - ORACLE_LOCAL   = $ORACLE_LOCAL"
echo " - ORACLE_HOME    = $ORACLE_HOME"
echo " - TNS_ADMIN      = $TNS_ADMIN"
echo " - ETC_BASE       = $ETC_BASE"
echo " - DEFAULT_DOMAIN = $DEFAULT_DOMAIN"

# prepare response file
cp ${ORADBA_RSP}/base_install.rsp.tmpl /tmp/base_install.rsp
sed -i -e "s|###ORACLE_BASE###|${ORACLE_BASE}|g"        /tmp/base_install.rsp
sed -i -e "s|###ORACLE_HOME###|${ORACLE_HOME}|g"        /tmp/base_install.rsp
sed -i -e "s|###TNS_ADMIN###|${TNS_ADMIN}|g"            /tmp/base_install.rsp
sed -i -e "s|###ORACLE_LOCAL###|${ORACLE_LOCAL}|g"      /tmp/base_install.rsp
sed -i -e "s|###DEFAULT_DOMAIN###|${DEFAULT_DOMAIN}|g"  /tmp/base_install.rsp
sed -i -e "s|###ETC_BASE###|${ETC_BASE}|g"              /tmp/base_install.rsp

# enable tvd Perl in response file
if [ -n "$TVDPERL_PKG" ]; then 
    sed -i -e 's/Use_Tvdperl=.*/Use_Tvdperl="YES"/'     /tmp/base_install.rsp
    sed -i -e 's/Use_Oracleperl=.*//'                   /tmp/base_install.rsp

    if [ -f ${SOFTWARE}/${TVDPERL_PKG} ]; then
        mkdir -p ${ORACLE_LOCAL}
        cp -v ${SOFTWARE}/${TVDPERL_PKG} ${ORACLE_LOCAL}
    fi
fi

mkdir -p ${DOWNLOAD}
# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------
# - Install Trivadis toolbox ---------------------------------------------------
echo " - Install Trivadis toolbox -------------------------------------------"
if [ -n "${BASENV_PKG}" ]; then
    INSTALL_PATH=${SOFTWARE}
    if ! get_software "${BASENV_PKG}" ; then
        echo "- WARNING: Fallback to oradba..."
        curl -f http://docker.oradba.ch/${BASENV_ORADBA} -o ${DOWNLOAD}/${BASENV_ORADBA}
        INSTALL_PATH=${DOWNLOAD}
        BASENV_PKG=${BASENV_ORADBA}
    fi

    # check if we have a basenv package and start installing
    if [ -f ${INSTALL_PATH}/${BASENV_PKG} ]; then
        mkdir -p ${ORACLE_LOCAL}
        echo " - unzip ${INSTALL_PATH}/${BASENV_PKG} to ${ORACLE_LOCAL}"
        unzip -q -o ${INSTALL_PATH}/${BASENV_PKG} -d ${ORACLE_LOCAL}
        # Install basenv binaries
        ${ORACLE_LOCAL}/runInstaller -responseFile /tmp/base_install.rsp -silent
        # cleanup basenv
        rm -rf ${ORACLE_LOCAL}/basenv-* ${ORACLE_LOCAL}/runInstaller* /tmp/*.rsp
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${INSTALL_PATH}/${BASENV_PKG}; fi
    else
        echo " - ERROR: No base software package specified. Abort installation."
        exit 1
    fi
fi

# - Configure custom basenv folders --------------------------------------------

# define the oradba url and package name
export GITHUB_URL="https://codeload.github.com/oehrlis/oradba/zip/master"
export ORADBA_PKG="oradba.zip" 
# - Get oradba init scripts ----------------------------------------------------
echo " - Get oradba scripts -------------------------------------------------"
mkdir -p ${DOWNLOAD}                                    # create download folder
curl -Lf ${GITHUB_URL} -o ${DOWNLOAD}/${ORADBA_PKG}

# check if we do have an unzip command
if [ ! -z $(command -v unzip) ]; then 
    # unzip seems to be available
    unzip -o ${DOWNLOAD}/${ORADBA_PKG} -d ${ORACLE_LOCAL}   # unzip scripts
else 
    # missing unzip fallback to a simple phyton script as python seems
    # to be available on Docker image oraclelinx:7-slim
    echo " - no unzip available, fallback to python script"
    echo "import zipfile" >${DOWNLOAD}/unzipfile.py
    echo "with zipfile.ZipFile('${DOWNLOAD}/${ORADBA_PKG}', 'r') as z:" >>${DOWNLOAD}/unzipfile.py
    echo "   z.extractall('${ORACLE_LOCAL}')">>${DOWNLOAD}/unzipfile.py
    python ${DOWNLOAD}/unzipfile.py

    # adjust file mods
    find ${ORACLE_LOCAL} -type f -name *.sh -exec chmod 755 {} \;
fi

mv ${ORACLE_LOCAL}/oradba-master ${ORACLE_LOCAL}/oradba             # get rid of master folder
mv ${ORACLE_LOCAL}/oradba/README.md ${ORACLE_LOCAL}/oradba/doc      # move documentation
rm ${ORACLE_LOCAL}/oradba/.gitignore                                # remove gitignore
rm -rf ${DOWNLOAD}                                                  # clean up

mkdir -p ${ORACLE_LOCAL}/oradba/bin
mkdir -p ${ORACLE_LOCAL}/oradba/etc
mkdir -p ${ORACLE_LOCAL}/oradba/sql
mkdir -p ${ORACLE_LOCAL}/oradba/rcv

# - Configure stuff for none Docker environment --------------------------------
if ! running_in_docker; then
    # - Install Trivadis TVD-Backup --------------------------------------------
    if [ -n "${BACKUP_PKG}" ]; then
        if get_software "${BACKUP_PKG}"; then   # Check and get binaries
            echo " - extract ${SOFTWARE}/${BACKUP_PKG} to ${ORACLE_BASE}/local"
            tar -zxvf ${SOFTWARE}/${BACKUP_PKG} -C ${ORACLE_BASE}/local

            # - create archive delete job --------------------------------------
            echo "<SHOW_ALL>show all;"                                              >${ORACLE_BASE}/local/oradba/rcv/mnt_del_arc.rcv
            echo "<SET_GLOBAL_OPERATIONS>"                                          >>${ORACLE_BASE}/local/oradba/rcv/mnt_del_arc.rcv
            echo "delete noprompt archivelog <ARCHIVE_RANGE> <ARCHIVE_PATTERN>;"    >>${ORACLE_BASE}/local/oradba/rcv/mnt_del_arc.rcv
            echo " - Create rman archive delete job. Add the following line to your crontab."
            echo " - Change TEMPLATE to your DB SID's."
            echo ""
            echo "00 0,4,8,16,20 * * * /u01/app/oracle/local/tvdbackup/bin/rman_exec.ksh -t TEMPLATE -s ${ORACLE_BASE}/local/oradba/rcv/mnt_del_arc.rcv >/dev/null 2>&1"
        else
            echo " - No backup software package specified. Skip this step."
        fi
    fi

    # - Create houskeeping job -------------------------------------------------
    cp -v ${ORACLE_BASE}/local/dba/templates/etc/housekeep.conf.tpl ${ORACLE_BASE}/local/dba/etc/housekeep.conf
    cp -v ${ORACLE_BASE}/local/dba/templates/etc/housekeep_work.conf.tpl.unix ${ORACLE_BASE}/local/dba/etc/housekeep_work.conf
    echo " - Create housekeep config files. Please adapt ${ORACLE_BASE}/local/dba/etc/housekeep_work.conf"
    echo " - and add the following line to your crontab."
    echo ""
    echo "00 01 * * * ${ORACLE_BASE}/local/dba/bin/housekeep.ksh >> ${ORACLE_BASE}/local/dba/log/housekeep.log 2>&1"

    # - Configure autostart for none docker environments -----------------------
    echo " - Configure Oracle service for none Docker environments."
    cp -v ${ORACLE_BASE}/local/dba/templates/init.d/oracle.service ${ORACLE_BASE}/local/dba/etc/oracle.service
    cp -v ${ORACLE_BASE}/local/dba/templates/etc/oracle_start_stop.conf ${ORACLE_BASE}/local/dba/etc/oracle_start_stop.conf
    sed -i -e "s|${ORACLE_BASE}/tvdtoolbox/dba/etc/oracle_start_stop.conf|${ORACLE_BASE}/local/dba/etc/oracle_start_stop.conf|g" ${ORACLE_BASE}/local/dba/etc/oracle.service
    echo " - Run the following commands to enable the oracle service."
    echo ""
    echo "sudo cp ${ORACLE_BASE}/local/dba/etc/oracle.service /usr/lib/systemd/system/"
    echo "sudo systemctl --system daemon-reload"
    echo "sudo systemctl enable oracle"
    echo ""
else
    echo " - Seems that I do run in a Docker container."
fi

# fix bash_profile for docker environment and remove BE_INITIALSID
if running_in_docker; then
    if [ -f $HOME/.bash_profile ]; then
        sed -i.bck -n '/BE_INITIALSID/{N;s/.*//;x;d;};x;p;${x;p;}' $HOME/.bash_profile
        sed -i '/if \[ "`id -un`" = "grid" \]; then/,/export BE_INITIALSID/d' "$HOME/.bash_profile"
    fi
fi
# --- EOF ----------------------------------------------------------------------