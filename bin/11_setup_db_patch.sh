#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 11_setup_db_patch.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Script to patch Oracle Database binaries
# Notes......: - Script would like to be executed as oracle :-)
#              - If the required software is not in /opt/stage, an attempt is
#                made to download the software package with curl from 
#                ${SOFTWARE_REPO} In this case, the environment variable must 
#                point to a corresponding URL.
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
export DB_PATCH_PKG=${DB_PATCH_PKG:-""}
export DB_OJVM_PKG=${DB_OJVM_PKG:-""}
export DB_OPATCH_PKG=${DB_OPATCH_PKG:-""}

# get default major release based on DB_BASE_PKG
DEFAULT_ORACLE_MAJOR_RELEASE=$(echo $DB_BASE_PKG|cut -d_ -f2|cut -c1-3)
if [ $DEFAULT_ORACLE_MAJOR_RELEASE -gt 122 ]; then
    DEFAULT_ORACLE_MAJOR_RELEASE=$(echo $DEFAULT_ORACLE_MAJOR_RELEASE|sed 's/.$/0/')
fi
export ORACLE_MAJOR_RELEASE=${ORACLE_MAJOR_RELEASE:-$DEFAULT_ORACLE_MAJOR_RELEASE}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder
export ORADBA_DEBUG=${ORADBA_DEBUG:-"FALSE"}    # enable debug mode

# define Oracle specific variables
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"18.3.0.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"

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
   echo " - ERROR: This script must not be run as root" 1>&2
   exit 1
fi

# prepare 11.2 OPatch response file
if [ ${ORACLE_MAJOR_RELEASE} -eq 112 ]; then
    cp ${ORADBA_RSP}/ocm.rsp.tmpl /tmp/ocm.rsp
    OPATCH_RSP="-ocmrf /tmp/ocm.rsp"
fi

# add oracle perl to the PATH for env without perl e.g. docker
if [ ! -n "$(command -v perl)" ]; then
    export PATH=$PATH:$ORACLE_HOME/perl/bin
fi

# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install OPatch ----------------------------------------------------------
echo " - Install OPatch -----------------------------------------------------"
if [ -n "${DB_OPATCH_PKG}" ]; then
    if get_software "${DB_OPATCH_PKG}"; then           # Check and get binaries
        rm -rf ${ORACLE_HOME}/OPatch                # remove old OPatch
        echo " - unzip ${SOFTWARE}/${DB_OPATCH_PKG} to ${ORACLE_HOME}"
        unzip -q -o ${SOFTWARE}/${DB_OPATCH_PKG} \
            -d ${ORACLE_HOME}/                      # unpack OPatch binary package
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_OPATCH_PKG}
    else
        echo " - WARNING: Could not find local or remote OPatch package. Skip OPatch update."
    fi
else
    echo " - No OPatch package specified. Skip OPatch update."
fi

# - Install database patch (RU/PSU) -----------------------------------------
echo " - Install database patch (RU/PSU) ------------------------------------"
if [ -n "${DB_PATCH_PKG}" ]; then
    if get_software "${DB_PATCH_PKG}"; then         # Check and get binaries
        DB_PATCH_ID=$(echo ${DB_PATCH_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        echo " - unzip ${SOFTWARE}/${DB_PATCH_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${DB_PATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${DB_PATCH_ID}

        ${ORACLE_HOME}/OPatch/opatch apply -silent $OPATCH_RSP
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_PATCH_PKG}
        rm -rf ${DOWNLOAD}/${DB_PATCH_ID}           # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo " - WARNING: Could not find local or remote database patch (RU/PSU) package. Skip database patch (RU/PSU) installation."
    fi
else
    echo " - No database patch (RU/PSU) package specified. Skip database patch (RU/PSU) installation."
fi

# - Install OJVM RU ---------------------------------------------------------
echo " - Install OJVM RU ----------------------------------------------------"
if [ -n "${DB_OJVM_PKG}" ]; then
    if get_software "${DB_OJVM_PKG}"; then          # Check and get binaries
        DB_OJVM_ID=$(echo ${DB_OJVM_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        echo " - unzip ${SOFTWARE}/${DB_OJVM_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${DB_OJVM_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${DB_OJVM_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent $OPATCH_RSP
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_OJVM_PKG}
        rm -rf ${DOWNLOAD}/${DB_OJVM_ID}            # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo " - WARNING: Could not find local or remote OJVM package. Skip OJVM installation."
    fi
else
    echo " - No OJVM package specified. Skip OJVM installation."
fi

echo " - CleanUp DB patch installation --------------------------------------"
# Remove not needed components
if running_in_docker; then
    echo " - remove Docker specific stuff"
    rm -rf ${ORACLE_HOME}/.patch_storage        # remove patch storage
    rm -rf ${ORACLE_HOME}/apex                  # APEX
    rm -rf ${ORACLE_HOME}/ords                  # ORDS
    rm -rf ${ORACLE_HOME}/bin/oracle_*          # Oracle Binaries
    rm -rf ${ORACLE_HOME}/sqldeveloper          # SQL Developer
    rm -rf ${ORACLE_HOME}/inventory/backup/*    # OUI backup
    rm -rf ${ORACLE_HOME}/network/tools/help    # Network tools help
    rm -rf ${ORACLE_HOME}/assistants/dbua       # Database upgrade assistant
    rm -rf ${ORACLE_HOME}/dmu                   # Database migration assistant
    rm -rf ${ORACLE_HOME}/install/pilot         # Remove pilot workflow installer
    rm -rf ${ORACLE_HOME}/suptools              # Support tools
    rm -rf ${ORACLE_HOME}/ucp                   # UCP connection pool
    rm -rf ${ORACLE_HOME}/lib/*.zip             # All installer files
fi

if [ "${ORADBA_DEBUG^^}" == "TRUE" ]; then
    echo " - \$ORADBA_DEBUG set to TRUE, keep temp and log files"
else
    echo " - \$ORADBA_DEBUG not set, remove temp and log files"
    # Temp locations
    echo " - remove temp files"
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/*.rsp
    rm -rf /tmp/InstallActions*
    rm -rf /tmp/CVU*oracle
    rm -rf /tmp/OraInstall*
    # remove all the logs....
    echo " - remove log files in \${ORACLE_INVENTORY} and \${ORACLE_BASE}/product"
    find ${ORACLE_INVENTORY} -type f -name *.log -exec rm {} \;
    find ${ORACLE_BASE}/product -type f -name *.log -exec rm {} \;
fi
# --- EOF --------------------------------------------------------------------