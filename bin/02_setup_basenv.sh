#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 02_setup_basenv.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to setup and configure TVD-Basenv.
# Notes......: Script would like to be executed as oracle :-)
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
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}     # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-/u01}     # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-$ORACLE_ROOT/app/oracle}
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}
export BASENV_PKG=${BASENV_PKG:-basenv-18.05.final.b.zip}
export SOFTWARE="/opt/stage"
export DOWNLOAD="/tmp/download"

# set the default ORACLE_HOME based on find results for oraenv
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product -name oraenv |sort -r|head -1)))}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-$(basename ${ORACLE_HOME})}

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

# prepare response file
cp ${ORADBA_RSP}/base_install.rsp.tmpl /tmp/base_install.rsp
sed -i -e "s|###ORACLE_BASE###|${ORACLE_BASE}|g"    /tmp/base_install.rsp
sed -i -e "s|###ORACLE_HOME###|${ORACLE_HOME}|g"    /tmp/base_install.rsp
sed -i -e "s|###TNS_ADMIN###|${TNS_ADMIN}|g"        /tmp/base_install.rsp
sed -i -e "s|###ORACLE_LOCAL###|${ORACLE_LOCAL}|g"  /tmp/base_install.rsp
# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install Trivadis toolbox ------------------------------------------------
echo " - Install Trivadis toolbox -------------------------------------------"
if [ -n "${BASENV_PKG}" ]; then
    if get_software "${DB_BASE_PKG}"; then          # Check and get binaries
        mkdir -p ${ORACLE_LOCAL}
        unzip -o ${SOFTWARE}/${BASENV_PKG} -d ${ORACLE_LOCAL}
        # Install basenv binaries
        ${ORACLE_LOCAL}/runInstaller -responseFile /tmp/base_install.rsp -silent
        # cleanup basenv
        rm -rf ${ORACLE_LOCAL}/basenv-* ${ORACLE_LOCAL}/runInstaller* /tmp/*.rsp
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${BASENV_PKG}; fi
    else
        echo "ERROR:   No base software package specified. Abort installation."
        exit 1
    fi
fi

# --- EOF --------------------------------------------------------------------