#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 11_setup_oud_patch.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to patch Oracle Unified Directory binaries
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
export OUD_PATCH_PKG=${OUD_PATCH_PKG:-"p28245820_122130_Generic.zip"}
export FMW_PATCH_PKG=${FMW_PATCH_PKG:-"p27912627_122130_Generic.zip"}
export OUD_OPATCH_PKG=${OUD_OPATCH_PKG:-"p28186730_139400_Generic.zip"}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"

# define Oracle specific variables
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"oud11.1.2.3.0"}
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
   echo "This script must not be run as root" 1>&2
   exit 1
fi
# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install OPatch ----------------------------------------------------------
echo " - Install OPatch -----------------------------------------------------"
if [ -n "${OUD_OPATCH_PKG}" ]; then
    if get_software "${OUD_OPATCH_PKG}"; then       # Check and get binaries
        unzip -o ${SOFTWARE}/${OUD_OPATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        # install the OPatch using java
        $JAVA_HOME/bin/java -jar ${DOWNLOAD}/6880880/opatch_generic.jar \
            -silent oracle_home=${ORACLE_HOME}
        rm -rf ${DOWNLOAD}/6880880
        running_in_docker && rm -rf ${SOFTWARE}/${OUD_OPATCH_PKG}
    else
        echo "WARNING: Skip OPatch update."
    fi
fi

# - Install FMW patch -------------------------------------------------------
echo " - Install FMW patch --------------------------------------------------"
if [ -n "${FMW_PATCH_PKG}" ]; then
    if get_software "${FMW_PATCH_PKG}"; then        # Check and get binaries
        FMW_PATCH_ID=$(echo ${FMW_PATCH_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        unzip -o ${SOFTWARE}/${FMW_PATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${FMW_PATCH_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent
        # remove binary packages on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${FMW_PATCH_PKG}
        rm -rf ${DOWNLOAD}/${FMW_PATCH_ID}          # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo "WARNING: Skip FMW patch installation."
    fi
fi

# - Install OUD patch -------------------------------------------------------
echo " - Install OUD patch --------------------------------------------------"
if [ -n "${OUD_PATCH_PKG}" ]; then
    if get_software "${OUD_PATCH_PKG}"; then        # Check and get binaries
        OUD_PATCH_ID=$(echo ${OUD_PATCH_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        unzip -o ${SOFTWARE}/${OUD_PATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${OUD_PATCH_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${OUD_PATCH_PKG}
        rm -rf ${DOWNLOAD}/${OUD_PATCH_ID}          # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo "WARNING: Skip OUD patch installation."
    fi
fi

echo " - CleanUp installation -----------------------------------------------"
# Temp locations
rm -rf ${DOWNLOAD}/*
rm -rf /tmp/*.rsp
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle
rm -rf /tmp/OraInstall*

# remove all the logs....
find ${ORACLE_BASE}/cfgtoollogs . -type f -name *.log -exec rm {} \;
find ${ORACLE_BASE}/local . -type f -name *.log -exec rm {} \;
find ${ORACLE_INVENTORY} . -type f -name *.log -exec rm {} \;
find ${ORACLE_BASE}/product . -type f -name *.log -exec rm {} \;
# --- EOF --------------------------------------------------------------------