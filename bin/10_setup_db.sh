#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 10_setup_db.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: generic script to install Oracle databases binaries
# Notes......: - Script would like to be executed as oracle :-)
#              - If the required software is not in /opt/stage, an attempt is
#                made to download the software package with curl from 
#                ${SOFTWARE_REPO} In this case, the environment variable must 
#                point to a corresponding URL.
#              - default values for software packages are set to 18.3
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

# define the software packages
export DB_BASE_PKG=${DB_BASE_PKG:-"LINUX.X64_180000_db_home.zip"}
export DB_EXAMPLE_PKG=${DB_EXAMPLE_PKG:-""}
export DB_PATCH_PKG=${DB_PATCH_PKG:-""}
export DB_OJVM_PKG=${DB_OJVM_PKG:-""}
export DB_OPATCH_PKG=${DB_OPATCH_PKG:-"p6880880_180000_Linux-x86-64.zip"}
export RESPONSFILE_VERSION=${RESPONSFILE_VERSION:-"oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v18.0.0"}

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
export ORACLE_EDITION=${ORACLE_EDITION:-"EE"}   # Oracle edition
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"18.3.0.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"
export ORACLE_MAJOR_RELEASE=${ORACLE_MAJOR_RELEASE:-"180"}

# define generic variables for software, download etc
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-"true"}               # Flag to set yum clean up
export SLIM=${SLIM:-"false"}                    # flag to enable SLIM setup
# - EOF Environment Variables -----------------------------------------------

# - Initialization ----------------------------------------------------------
# Make sure root does not run our script
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
echo " - Prepare response files ---------------------------------------------"
cp ${ORADBA_RSP}/db_install.rsp.tmpl /tmp/db_install.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"              /tmp/db_install.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"              /tmp/db_install.rsp
sed -i -e "s|###ORACLE_INVENTORY###|$ORACLE_INVENTORY|g"    /tmp/db_install.rsp
sed -i -e "s|###ORACLE_EDITION###|$ORACLE_EDITION|g"        /tmp/db_install.rsp
sed -i -e "s|^oracle.install.responseFileVersion.*|$RESPONSFILE_VERSION|" /tmp/db_install.rsp

# adjust response file for 11.2 and 12.1
if [ ${ORACLE_MAJOR_RELEASE} -eq 112 ]; then
    sed -i -e "/oracle.install.db.BACKUPDBA_GROUP/d"       /tmp/db_install.rsp
    sed -i -e "/oracle.install.db.DGDBA_GROUP/d"           /tmp/db_install.rsp
    sed -i -e "/oracle.install.db.KMDBA_GROUP/d"           /tmp/db_install.rsp
    sed -i -e "/oracle.install.db.OSRACDBA_GROUP/d"        /tmp/db_install.rsp
    echo "oracle.install.db.EEOptionsSelection=false"      >>/tmp/db_install.rsp
elif [ ${ORACLE_MAJOR_RELEASE} -eq 121 ]; then
    sed -i -e "/oracle.install.db.OSRACDBA_GROUP/d"        /tmp/db_install.rsp
fi

cp ${ORADBA_RSP}/db_examples_install.rsp.tmpl /tmp/db_examples_install.rsp
sed -i -e "s|###ORACLE_INVENTORY###|$ORACLE_INVENTORY|g"    /tmp/db_examples_install.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"              /tmp/db_examples_install.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"              /tmp/db_examples_install.rsp
sed -i -e "s|^oracle.install.responseFileVersion.*|$RESPONSFILE_VERSION|" /tmp/db_examples_install.rsp

# - Install database binaries -----------------------------------------------
# handle pre and post 18c
echo " - Install Oracle DB binaries -----------------------------------------"
if [ -n "${DB_BASE_PKG}" ]; then
    if get_software "${DB_BASE_PKG}"; then          # Check and get binaries
        mkdir -p ${ORACLE_HOME}
        echo " - unzip ${SOFTWARE}/${DB_BASE_PKG} to ${ORACLE_HOME}"
        unzip -q -o ${SOFTWARE}/${DB_BASE_PKG} \
            -d ${ORACLE_HOME}                       # unpack Oracle binary package
        
        # Workaround for 12.1 with 2 zip files
        if [ -n "${DB_BASE2_PKG}" ]; then
            if get_software "${DB_BASE2_PKG}"; then
                echo " - unzip ${SOFTWARE}/${DB_BASE2_PKG} to ${ORACLE_HOME}"
                unzip -q  -o ${SOFTWARE}/${DB_BASE2_PKG} -d ${ORACLE_HOME}
            fi
        fi
        # check if we have a legacy installer (pre 18c)
        if [ -d "${ORACLE_HOME}/database" ]; then
            echo "INFO:    Legacy OUI software setup"
            mv ${ORACLE_HOME}/database ${ORACLE_HOME}/..
            SETUP_PATH="${ORACLE_HOME}/../database"
        else
            echo "INFO:    New OUI inplace software setup"
            SETUP_PATH="${ORACLE_HOME}"
        fi
        # Install Oracle binaries -ignorePrereqFailure/-ignoreSysPrereqs
        PREREQ="-ignorePrereqFailure"
        if [ ${ORACLE_MAJOR_RELEASE} -le 121 ]; then
            PREREQ="-ignoresysprereqs -ignoreprereq"
        fi
        
        ${SETUP_PATH}/runInstaller -silent -force \
            -waitforcompletion \
            -responsefile /tmp/db_install.rsp \
            ${PREREQ}
        rm -rf "${ORACLE_HOME}/../database"         # remove software for legacy OUI
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_BASE_PKG}
        if [ -n "${DB_BASE2_PKG}" ]; then
            running_in_docker && rm -rf ${SOFTWARE}/${DB_BASE2_PKG}
        fi
    else
        echo "ERROR:   No base software package specified. Abort installation."
        exit 1
    fi
fi

# - Install database examples -----------------------------------------------
echo " - Install Oracle DB examples -----------------------------------------"
if [ -n "${DB_EXAMPLE_PKG}" ]; then
    if get_software "${DB_EXAMPLE_PKG}"; then           # Check and get binaries
        echo " - unzip ${SOFTWARE}/${DB_EXAMPLE_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${DB_EXAMPLE_PKG} \
            -d ${DOWNLOAD}/                             # unpack Oracle binary package
        
        # Install Oracle binaries -ignorePrereqFailure/-ignoreSysPrereqs
        PREREQ="-ignorePrereqFailure"
        if [ ${ORACLE_MAJOR_RELEASE} -le 121 ]; then
            PREREQ="-ignoresysprereqs -ignoreprereq"
        fi
        
        # Install Oracle binaries
        ${DOWNLOAD}/examples/runInstaller -silent -force \
            -waitforcompletion \
            -responsefile /tmp/db_examples_install.rsp \
            ${PREREQ}
        # remove files on docker builds
        rm -rf ${DOWNLOAD}/examples
        running_in_docker && rm -rf ${SOFTWARE}/${DB_EXAMPLE_PKG}
    else
        echo "WARNING: Could not find local or remote example package. Skip example installation."
    fi
else
    echo "INFO:    No example package specified. Skip example installation."
fi

# install patch any of the patch variable is if defined
if [ ! -z "${DB_PATCH_PKG}" ] || [ ! -z "${DB_OJVM_PKG}" ] || [ ! -z "${DB_OPATCH_PKG}" ]; then 
    ${ORADBA_BIN}/11_setup_db_patch.sh
else
    echo "INFO:    Skip patch installation. No patch packages specified."
fi

echo " - CleanUp DB installation --------------------------------------------"
# Remove not needed components
rm -rf ${ORACLE_HOME}/apex                  # APEX
rm -rf ${ORACLE_HOME}/ords                  # ORDS
rm -rf ${ORACLE_HOME}/sqldeveloper          # SQL Developer
rm -rf ${ORACLE_HOME}/inventory/backup/*    # OUI backup
rm -rf ${ORACLE_HOME}/network/tools/help    # Network tools help
rm -rf ${ORACLE_HOME}/assistants/dbua       # Database upgrade assistant
rm -rf ${ORACLE_HOME}/dmu                   # Database migration assistant
rm -rf ${ORACLE_HOME}/install/pilot         # Remove pilot workflow installer
rm -rf ${ORACLE_HOME}/suptools              # Support tools
rm -rf ${ORACLE_HOME}/ucp                   # UCP connection pool
rm -rf ${ORACLE_HOME}/lib/*.zip             # All installer files

# Temp locations
rm -rf ${DOWNLOAD}/*
rm -rf /tmp/*.rsp
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle
rm -rf /tmp/OraInstall*

# remove all the logs....
find ${ORACLE_INVENTORY} -type f -name *.log -exec rm {} \;
find ${ORACLE_BASE}/product -type f -name *.log -exec rm {} \;

if [ "${SLIM^^}" == "TRUE" ]; then
    rm -rf ${ORACLE_HOME}/inventory             # remove inventory
    rm -rf ${ORACLE_HOME}/oui                   # remove oui
    rm -rf ${ORACLE_HOME}/OPatch                # remove OPatch
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/OraInstall*
    rm -rf ${ORACLE_HOME}/.patch_storage        # remove patch storage
fi
# --- EOF --------------------------------------------------------------------