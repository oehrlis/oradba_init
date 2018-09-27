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

# Make sure only root can run our script
if [ ! $EUID -ne 0 ]; then
   echo "This script must not be run as root" 1>&2
   exit 1
fi

echo " - Get Trivadis toolbox binaries --------------------------------------"
# Get the oracle binaries if they are not there yet
if [ ! -s "${SOFTWARE}/${BASENV_PKG}" ]; then
    echo "download ${DOWNLOAD}/${BASENV_PKG} from orarepo"
    curl -f http://orarepo/${BASENV_PKG} -o ${DOWNLOAD}/${BASENV_PKG}
else 
    echo "use local copy of ${SOFTWARE}/${BASENV_PKG}"
fi

echo " - Install Trivadis toolbox -------------------------------------------"
# prepare response file
cp ${ORADBA_RSP}/base_install.rsp.tmpl ${ORADBA_RSP}/base_install.rsp
sed -i -e "s|###ORACLE_BASE###|${ORACLE_BASE}|g"    ${ORADBA_RSP}/base_install.rsp
sed -i -e "s|###ORACLE_HOME###|${ORACLE_HOME}|g"    ${ORADBA_RSP}/base_install.rsp
sed -i -e "s|###TNS_ADMIN###|${TNS_ADMIN}|g"        ${ORADBA_RSP}/base_install.rsp
sed -i -e "s|###ORACLE_LOCAL###|${ORACLE_LOCAL}|g"  ${ORADBA_RSP}/base_install.rsp

# unpack Oracle binary package
mkdir -p ${ORACLE_BASE}/local
unzip -o ${DOWNLOAD}/${BASENV_PKG} -d ${ORACLE_LOCAL}

# install basenv
${ORACLE_LOCAL}/runInstaller -responseFile ${ORADBA_RSP}/base_install.rsp -silent

# cleanup basenv
rm -rf ${ORACLE_LOCAL}/basenv-* ${ORACLE_LOCAL}/runInstaller*

# --- EOF --------------------------------------------------------------------