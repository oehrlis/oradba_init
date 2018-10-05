#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 20_setup_basenv.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to setup and configure TVD-Basenv.
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
export BASENV_PKG=${BASENV_PKG:-basenv-18.05.final.b.zip}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}     # root folder for ORACLE_BASE and binaries
export ORACLE_BASE=${ORACLE_BASE:-$ORACLE_ROOT/app/oracle}
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}
# set the default ORACLE_HOME based on find results for oraenv
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product -name oraenv |sort -r|head -1)))}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-$(basename ${ORACLE_HOME})}

# define generic variables for software, download etc
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-"true"}               # Flag to set yum clean up
# - EOF Environment Variables -----------------------------------------------

# - Initialization ----------------------------------------------------------
# Make sure root does not run our script
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
    if get_software "${BASENV_PKG}"; then          # Check and get binaries
        mkdir -p ${ORACLE_LOCAL}
        echo " - unzip ${SOFTWARE}/${BASENV_PKG} to ${ORACLE_LOCAL}"
        unzip -q -o ${SOFTWARE}/${BASENV_PKG} -d ${ORACLE_LOCAL}
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