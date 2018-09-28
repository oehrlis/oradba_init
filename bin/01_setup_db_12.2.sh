#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 01_setup_db_12.2.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to install Oracle Database 12.2.
# Notes......: Script would like to be executed as oracle :-).
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
# Version dependend settings
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"12.2.0.1"}
# define the software packages
export DB_BASE_PKG=${DB_BASE_PKG:-"linuxx64_12201_database.zip"}
export DB_EXAMPLE_PKG=${DB_EXAMPLE_PKG:-"linuxx64_12201_examples.zip"}
export DB_RU_PKG=${DB_RU_PKG:-"p28163133_122010_Linux-x86-64.zip"}
export DB_OJVM_PKG=${DB_OJVM_PKG:-"p27923353_122010_Linux-x86-64.zip"}
export OPATCH_PKG=${OPATCH_PKG:-"p6880880_122010_Linux-x86-64.zip"}
export RESPONSFILE_VERSION="oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0"

# other stuff
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}     # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-/u01}     # Oracle data folder eg volume for docker
export ORACLE_ARCH=${ORACLE_ARCH:-/u02}     # Oracle arch folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-$ORACLE_ROOT/app/oracle}
export ORACLE_INVENTORY=${ORACLE_INVENTORY:-$ORACLE_ROOT/app/oraInventory}
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"
export ORACLE_EDITION=${ORACLE_EDITION:-"EE"}
export SLIM=${SLIM:-"FALSE"}
export SOFTWARE="/opt/stage"
export SOFTWARE_REPO=""
export DOWNLOAD="/tmp/download"
export CLEANUP=${CLEANUP:-true}             # Flag to set yum clean up

# - EOF Environment Variables -----------------------------------------------

# - Functions ---------------------------------------------------------------
# ---------------------------------------------------------------------------
function get_software {
# Purpose....: Verify if the software package is available if not try to 
#              download it from $SOFTWARE_REPO
# ---------------------------------------------------------------------------
    PKG=$1
    if [ ! -s "${SOFTWARE}/${PKG}" ]; then
        if [ ! -z "${SOFTWARE_REPO}" ]; then
            echo "WARNING: Try to download ${PKG} from ${SOFTWARE_REPO}"
            curl -f ${SOFTWARE_REPO}${PKG} -o ${DOWNLOAD}/${PKG}
        else
            echo "WARNING: No software repository specified"
            return 1
        fi
    else
        echo "Found package ${PKG} for installation."
        return 0
    fi
}

# - EOF Functions -----------------------------------------------------------

# - Initialization ----------------------------------------------------------
# Make sure only root can run our script
if [ ! $EUID -ne 0 ]; then
   echo "This script must not be run as root" 1>&2
   exit 1
fi

# check space
echo " - Check available space ----------------------------------------------"
REQUIRED_SPACE_GB=15
AVAILABLE_SPACE_GB=$(df -PB 1G / | tail -n 1 | awk '{ print $4 }')

if [ $AVAILABLE_SPACE_GB -lt $REQUIRED_SPACE_GB ]; then
    echo "ERROR:   There is not enough space available."
    echo "         There has to be at least $REQUIRED_SPACE_GB GB, "
    echo "         but only $AVAILABLE_SPACE_GB GB are available."
    exit 1;
fi;
# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# Replace place holders in responce file
echo " - Prepare response file ----------------------------------------------"
cp ${ORADBA_RSP}/db_install.rsp.tmpl /tmp/db_install.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"              /tmp/db_install.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"              /tmp/db_install.rsp
sed -i -e "s|###ORACLE_INVENTORY###|$ORACLE_INVENTORY|g"    /tmp/db_install.rsp
sed -i -e "s|###ORACLE_EDITION###|$ORACLE_EDITION|g"        /tmp/db_install.rsp
sed -i -e "s|^oracle.install.responseFileVersion.*|$RESPONSFILE_VERSION|" /tmp/db_install.rsp

cp ${ORADBA_RSP}/db_examples_install.rsp.tmpl /tmp/db_examples_install.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"          /tmp/db_examples_install.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"          /tmp/db_examples_install.rsp
sed -i -e "s|^oracle.install.responseFileVersion.*|$RESPONSFILE_VERSION|" /tmp/db_examples_install.rsp

# - Install database binaries -----------------------------------------------
echo " - Install Oracle DB binaries -----------------------------------------"
if [ -n "${DB_BASE_PKG}" ]; then
    if get_software "${DB_BASE_PKG}"; then          # Check and get binaries
        mkdir -p ${ORACLE_HOME}
        unzip -o ${SOFTWARE}/${DB_BASE_PKG} \
            -d ${DOWNLOAD}                      # unpack Oracle binary package
        # Install Oracle binaries
        ${DOWNLOAD}/database/runInstaller -silent -force \
            -waitforcompletion \
            -responsefile /tmp/db_install.rsp \
            -ignorePrereqFailure
        # remove files on docker builds
        rm -rf ${DOWNLOAD}/database
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${DB_BASE_PKG}; fi
    else
        echo "ERROR:   No base software package specified. Abort installation."
        exit 1
    fi
fi

# - Install database examples -----------------------------------------------
echo " - Install Oracle DB examples -----------------------------------------"
if [ -n "${DB_EXAMPLE_PKG}" ]; then
    if get_software "${DB_EXAMPLE_PKG}"; then           # Check and get binaries
        unzip -o ${SOFTWARE}/${DB_EXAMPLE_PKG} \
            -d ${DOWNLOAD}/                             # unpack Oracle binary package
        # Install Oracle binaries
        ${DOWNLOAD}/examples/runInstaller -silent -force \
            -waitforcompletion \
            -responsefile /tmp/db_examples_install.rsp \
            -ignorePrereqFailure
        # remove files on docker builds
        rm -rf ${DOWNLOAD}/examples
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${DB_EXAMPLE_PKG}; fi
    else
        echo "WARNING: Skip example installation."
    fi
fi

# - Install OPatch ----------------------------------------------------------
echo " - Install OPatch -----------------------------------------------------"
if [ -n "${OPATCH_PKG}" ]; then
    if get_software "${OPATCH_PKG}"; then           # Check and get binaries
        rm -rf ${ORACLE_HOME}/OPatch                # remove old OPatch
        unzip -o ${SOFTWARE}/${OPATCH_PKG} \
            -d ${ORACLE_HOME}/                      # unpack OPatch binary package
        # remove files on docker builds
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${OPATCH_PKG}; fi
    else
        echo "WARNING: Skip OPatch update."
    fi
fi

# - Install database RU -----------------------------------------------------
echo " - Install database RU ------------------------------------------------"
if [ -n "${DB_RU_PKG}" ]; then
    if get_software "${DB_RU_PKG}"; then            # Check and get binaries
        DB_RU_ID=$(echo ${DB_RU_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        unzip -o ${SOFTWARE}/${DB_RU_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${DB_RU_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent
        # remove files on docker builds
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${DB_RU_PKG}; fi
        rm -rf ${DOWNLOAD}/${DB_RU_ID}              # remove the binary packages
        rm -rf PatchSearch.xml                      # remove the binary packages
    else
        echo "WARNING: Skip database RU installation."
    fi
fi

# - Install OJVM RU ---------------------------------------------------------
echo " - Install OJVM RU ----------------------------------------------------"
if [ -n "${DB_OJVM_PKG}" ]; then
    if get_software "${DB_OJVM_PKG}"; then          # Check and get binaries
        DB_OJVM_ID=$(echo ${DB_OJVM_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        unzip -o ${SOFTWARE}/${DB_OJVM_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${DB_OJVM_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent
        # remove files on docker builds
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${DB_OJVM_PKG}; fi
        rm -rf ${DOWNLOAD}/${DB_OJVM_ID}            # remove the binary packages
        rm -rf PatchSearch.xml                      # remove the binary packages
    else
        echo "WARNING: Skip OJVM RU installation."
    fi
fi

echo " - CleanUp installation -----------------------------------------------"
# Remove not needed components
# APEX
rm -rf ${ORACLE_HOME}/apex
# ORDS
rm -rf ${ORACLE_HOME}/ords
# SQL Developer
rm -rf ${ORACLE_HOME}/sqldeveloper
# OUI backup
rm -rf ${ORACLE_HOME}/inventory/backup/*
# Network tools help
rm -rf ${ORACLE_HOME}/network/tools/help
# Database upgrade assistant
rm -rf ${ORACLE_HOME}/assistants/dbua
# Database migration assistant
rm -rf ${ORACLE_HOME}/dmu
# Remove pilot workflow installer
rm -rf ${ORACLE_HOME}/install/pilot
# Support tools
rm -rf ${ORACLE_HOME}/suptools
# UCP connection pool
rm -rf ${ORACLE_HOME}/ucp
# All installer files
rm -rf ${ORACLE_HOME}/lib/*.zip 

# Temp locations
rm -rf ${DOWNLOAD}
rm -rf /tmp/*.rsp
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle
rm -rf /tmp/OraInstall*

# remove all the logs....
find ${ORACLE_BASE}/cfgtoollogs . -name *.log -exec rm {} \;
find ${ORACLE_BASE}/local . -name *.log -exec rm {} \;
find ${ORACLE_BASE}/oraInventory . -name *.log -exec rm {} \;
find ${ORACLE_BASE}/product . -name *.log -exec rm {} \;

if [ "${SLIM^^}" == "TRUE" ]; then
    # remove inventory
    rm -rf ${ORACLE_HOME}/inventory
    # remove oui
    rm -rf ${ORACLE_HOME}/oui
    # remove OPatch
    rm -rf ${ORACLE_HOME}/OPatch
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/OraInstall*
    # remove patch storage
    rm -rf ${ORACLE_HOME}/.patch_storage
fi

# --- EOF --------------------------------------------------------------------