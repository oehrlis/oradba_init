#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Transactional Data Platform
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 11_setup_wls_patch.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Script to patch Oracle Unified Directory binaries
# Notes......: - Script would like to be executed as oracle :-)
#              - If the required software is not in /opt/stage, an attempt is
#                made to download the software package with curl from 
#                ${SOFTWARE_REPO} In this case, the environment variable must 
#                point to a corresponding URL.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------
# - Customization -------------------------------------------------------------
ORADBA_BIN=$(dirname ${BASH_SOURCE[0]})
# - End of Customization ------------------------------------------------------

# - Environment Variables ---------------------------------------------------
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define the software packages
export FMW_PATCH_PKG=${FMW_PATCH_PKG:-""}
export WLS_OPATCH_PKG=${WLS_OPATCH_PKG:-""}
export OUI_PATCH_PKG=${OUI_PATCH_PKG:-""}
export COHERENCE_PATCH_PKG=${COHERENCE_PATCH_PKG:-""}
export WLS_ONEOFF_PKGS=${WLS_ONEOFF_PKGS:-""}
export OPATCH_NO_FUSER=true

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_DEBUG=${ORADBA_DEBUG:-"FALSE"}    # enable debug mode

# define Oracle specific variables
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"fmw14.1.1.0.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"

# define generic variables for software, download etc
export JAVA_HOME=${JAVA_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE} /usr/java -name javac 2>/dev/null|sort -r|head -1) 2>/dev/null) 2>/dev/null)}
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-"true"}               # Flag to set yum clean up
export SLIM=${SLIM:-"false"}                    # flag to enable SLIM setup
# - EOF Environment Variables -----------------------------------------------

# - Functions ---------------------------------------------------------------
function install_patch {
# ---------------------------------------------------------------------------
# Purpose....: function to install a DB patch using opatch apply 
# ---------------------------------------------------------------------------
    PATCH_PKG=${1:-""}
    if [ -n "${PATCH_PKG}" ]; then
        if get_software "${PATCH_PKG}"; then         # Check and get binaries
            PATCH_ID=$(echo ${PATCH_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
            echo " - unzip ${SOFTWARE}/${PATCH_PKG} to ${DOWNLOAD}"
            unzip -q -o ${SOFTWARE}/${PATCH_PKG} \
                -d ${DOWNLOAD}/                      # unpack OPatch binary package
            cd ${DOWNLOAD}/${PATCH_ID}

            ${ORACLE_HOME}/OPatch/opatch apply -silent
            OPATCH_ERR=$?
            if [ ${OPATCH_ERR} -ne 0 ]; then
                echo " - WARNING: opatch apply failed with error ${OPATCH_ERR}"
                return 1
            fi

            # remove files on docker builds
            running_in_docker && rm -rf ${SOFTWARE}/${PATCH_PKG}
            rm -rf ${DOWNLOAD}/${PATCH_ID}           # remove the binary packages
            rm -rf ${DOWNLOAD}/PatchSearch.xml       # remove the binary packages
            echo " - Successfully install patch package ${PATCH_PKG}"
        else
            echo " - WARNING: Could not find local or remote patch package ${PATCH_PKG}. Skip patch installation for ${PATCH_PKG}"
            echo " - WARNING: Skip patch installation."
        fi
    else
        echo " - No package specified. Skip patch installation."
    fi
}
# - EOF Functions -----------------------------------------------------------

# - Initialization ----------------------------------------------------------
# Make sure root does not run our script
if [ ! $EUID -ne 0 ]; then
   echo " - ERROR: This script must not be run as root" 1>&2
   exit 1
fi

# fuser issue see MOS Note 2429708.1 OPatch Fails with Error "fuser could not be located"
running_in_docker && export OPATCH_NO_FUSER=true
# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install OPatch ----------------------------------------------------------
echo " - Step 1: Install OPatch ---------------------------------------------"
if [ -n "${WLS_OPATCH_PKG}" ]; then
    if get_software "${WLS_OPATCH_PKG}"; then       # Check and get binaries
        echo " - unzip ${SOFTWARE}/${WLS_OPATCH_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${WLS_OPATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        # install the OPatch using java
        $JAVA_HOME/bin/java -jar ${DOWNLOAD}/6880880/opatch_generic.jar \
            -ignoreSysPrereqs -force \
            -silent oracle_home=${ORACLE_HOME}
        rm -rf ${DOWNLOAD}/6880880
        running_in_docker && rm -rf ${SOFTWARE}/${WLS_OPATCH_PKG}
    else
        echo " - WARNING: Could not find local or remote OPatch package. Skip OPatch update."
    fi
else
    echo " - No OPatch package specified. Skip OPatch update."
fi

# - Install OUI patch -------------------------------------------------------
echo " - Step 2: Install OUI patch ------------------------------------------"
install_patch ${OUI_PATCH_PKG}

# - Install FMW patch -------------------------------------------------------
echo " - Step 3: Install FMW patch (RU/PSU) ---------------------------------"
install_patch ${FMW_PATCH_PKG}

# - Install Coherence patch -------------------------------------------------
echo " - Step 4: Install Coherence patch ------------------------------------"
if [ -n "${COHERENCE_PATCH_PKG}" ]; then
    if get_software "${COHERENCE_PATCH_PKG}"; then        # Check and get binaries
        COHERENCE_PATCH_ID=$(unzip -qql ${SOFTWARE}/${COHERENCE_PATCH_PKG}| sed -r '1 {s/([ ]+[^ ]+){3}\s+//;q}')
        echo " - unzip ${SOFTWARE}/${COHERENCE_PATCH_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${COHERENCE_PATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${COHERENCE_PATCH_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent
        # remove binary packages on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${COHERENCE_PATCH_PKG}
        rm -rf ${DOWNLOAD}/${COHERENCE_PATCH_ID}          # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo " - WARNING: Could not find local or remote coherence patch package. Skip coherence patch installation."
    fi
else
    echo " - No coherence patch package specified. Skip coherence patch installation."
fi

echo " - Step 5: Install One-off patches ------------------------------------"
if [ -n "${WLS_ONEOFF_PKGS}" ]; then
    for oneoff_patch in $(echo "${WLS_ONEOFF_PKGS}"|sed s/\;/\ /g); do
        echo " - Step 6.1: Install One-off patch ${oneoff_patch} ------------"
        install_patch ${oneoff_patch}
    done
else
    echo " - No one-off packages specified. Skip one-off installation."
fi

echo " - CleanUp WLS patch installation -------------------------------------"
# Remove not needed components
if running_in_docker; then
    echo " - remove Docker specific stuff"
    rm -rf ${ORACLE_HOME}/inventory/backup/*    # OUI backup
    rm -rf ${ORACLE_HOME}/.patch_storage        # remove patch storage
fi

if [ "${ORADBA_DEBUG^^}" == "TRUE" ]; then
    echo " - \$ORADBA_DEBUG set to TRUE, keep temp and log files"
else
    echo " - \$ORADBA_DEBUG not set, remove temp and log files"
    # Temp locations
    echo " - remove temp files"
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/*.rsp
    rm -rf /tmp/*.loc
    rm -rf /tmp/InstallActions*
    rm -rf /tmp/CVU*oracle
    rm -rf /tmp/OraInstall*
    # remove all the logs....
    echo " - remove log files in \${ORACLE_INVENTORY} and \${ORACLE_BASE}/product"
    find ${ORACLE_INVENTORY} -type f -name *.log -exec rm {} \;
    find ${ORACLE_BASE}/product -type f -name *.log -exec rm {} \;
fi

if [ "${SLIM^^}" == "TRUE" ]; then
    echo " - \$SLIM set to TRUE, remove other stuff..."
    rm -rf ${ORACLE_HOME}/inventory                 # remove inventory
    rm -rf ${ORACLE_HOME}/oui                       # remove oui
    rm -rf ${ORACLE_HOME}/OPatch                    # remove OPatch
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/OraInstall*
    rm -rf ${ORACLE_HOME}/.patch_storage            # remove patch storage
fi
# --- EOF --------------------------------------------------------------------