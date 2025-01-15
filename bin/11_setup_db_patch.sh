#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 11_setup_db_patch.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
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
export DB_PATCH_PKG=${DB_PATCH_PKG:-""}
export DB_OJVM_PKG=${DB_OJVM_PKG:-""}
export DB_OPATCH_PKG=${DB_OPATCH_PKG:-""}
export DB_JDKPATCH_PKG=${DB_JDKPATCH_PKG:-""}
export DB_PERLPATCH_PKG=${DB_PERLPATCH_PKG:-""}
export DB_ONEOFF_PKGS=${DB_ONEOFF_PKGS:-""}
export SLIMMING=${SLIMMING:-"false"}
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
export SLIMMING=${SLIMMING:-"false"}            # flag to enable SLIMMING setup
# - EOF Environment Variables --------------------------------------------------

# - Functions ------------------------------------------------------------------
function install_patch {
# ------------------------------------------------------------------------------
# Purpose....: function to install a DB patch using opatch apply 
# ------------------------------------------------------------------------------
    PATCH_PKG=${1:-""}
    if [ -n "${PATCH_PKG}" ]; then
        if get_software "${PATCH_PKG}"; then         # Check and get binaries
            PATCH_ID=$(echo ${PATCH_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
            echo " - unzip ${SOFTWARE}/${PATCH_PKG} to ${DOWNLOAD}"
            unzip -q -o ${SOFTWARE}/${PATCH_PKG} \
                -d ${DOWNLOAD}/                      # unpack OPatch binary package
            cd ${DOWNLOAD}/${PATCH_ID}

            ${ORACLE_HOME}/OPatch/opatch apply -silent $OPATCH_RSP
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
# - EOF Functions --------------------------------------------------------------


# - Initialization -------------------------------------------------------------
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

# - EOF Initialization ---------------------------------------------------------
echo " - database patch task overview ---------------------------------------"
echo " - DB_OPATCH_PKG         = ${DB_OPATCH_PKG}"
echo " - DB_PATCH_PKG          = ${DB_PATCH_PKG}"
echo " - DB_OJVM_PKG           = ${DB_OJVM_PKG}"
echo " - DB_JDKPATCH_PKG       = ${DB_JDKPATCH_PKG}"
echo " - DB_PERLPATCH_PKG      = ${DB_PERLPATCH_PKG}"
echo " - DB_ONEOFF_PKGS        = ${DB_ONEOFF_PKGS}"
echo " - ORACLE_MAJOR_RELEASE  = ${ORACLE_MAJOR_RELEASE}"
echo " - ORACLE_HOME           = ${ORACLE_HOME}"
echo " - SLIMMING              = ${SLIMMING}"

# - Main -----------------------------------------------------------------------
# - Install OPatch -------------------------------------------------------------
echo " - Step 1: Install OPatch ---------------------------------------------"
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

# - Install database patch -----------------------------------------------------
echo " - Step 2: Install database patch (RU/PSU) ----------------------------"
install_patch ${DB_PATCH_PKG}

echo " - Step 3: Install OJVM RU --------------------------------------------"
install_patch ${DB_OJVM_PKG}

echo " - Step 4: Install JDK patch Oracle home ------------------------------"
install_patch ${DB_JDKPATCH_PKG}

echo " - Step 5: Install Perl patch Oracle home -----------------------------"
install_patch ${DB_PERLPATCH_PKG}

echo " - Step 6: Install One-off patches ------------------------------------"
if [ -n "${DB_ONEOFF_PKGS}" ]; then
    j=1
    for oneoff_patch in $(echo "${DB_ONEOFF_PKGS}"|sed s/\;/\ /g); do
        echo " - Step 6.$j: Install One-off patch ${oneoff_patch} ------------"
        install_patch ${oneoff_patch}
        ((j++))                 # increment counter
    done
else
    echo " - No one-off packages specified. Skip one-off installation."
fi

echo " - Step 7: CleanUp DB patch installation ------------------------------"
# Remove not needed components
if running_in_docker || [[ "${SLIMMING^^}" == "TRUE" ]]; then
    echo " - remove Docker specific stuff"
    rm -rf ${ORACLE_HOME}/.patch_storage        # remove patch storage
    rm -rf ${ORACLE_HOME}/.opatchauto_storage   # remove patch storage
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
else
    echo " - no slimming of the Oracle Home"
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
# --- EOF ----------------------------------------------------------------------