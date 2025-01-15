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
OUDBASE_PKG="oudbase_install.sh"        # oudbase install script
# OUD base GitHub download URL
OUDBASE_URL=$(curl -s https://api.github.com/repos/oehrlis/oudbase/releases/latest \
        | grep "browser_download_url.*${OUDBASE_PKG}" \
        | cut -d: -f 2,3 \
        | tr -d \" )
export ORADBA_DEBUG=${ORADBA_DEBUG:-"FALSE"}    # enable debug mode

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}     # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}     # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}
# set the default ORACLE_HOME based on find results for oraenv
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product -name oud-setup 2>/dev/null|sort -r|head -1) 2>/dev/null) 2>/dev/null)}
export ORACLE_FMW_HOME=${ORACLE_FMW_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product -name product.xml 2>/dev/null|sort -r|head -1) 2>/dev/null) 2>/dev/null)}
export JAVA_HOME=${JAVA_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE} /usr/java -name javac 2>/dev/null|sort -r|head -1) 2>/dev/null) 2>/dev/null)}

# define generic variables for software, download etc
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
# - EOF Environment Variables --------------------------------------------------

# - Initialization -------------------------------------------------------------
# Make sure root does not run our script
if [ ! $EUID -ne 0 ]; then
   echo "This script must not be run as root" 1>&2
   exit 1
fi
# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------
# create the download directory if it does not yet exists
mkdir -p ${DOWNLOAD}
# get the OUD base install package
curl -f --location-trusted ${OUDBASE_URL} -o ${DOWNLOAD}/${OUDBASE_PKG}

#adapt permissions
chmod 755 ${DOWNLOAD}/${OUDBASE_PKG}

# install OUD base use commandline parameter if environment variables are defined

# show what we will create later on...
echo " - Prepare Oracle OUDBase installation ----------------------------------"
echo " - OUDBASE_PKG       = ${OUDBASE_PKG}" 
echo " - ORACLE_BASE       = ${ORACLE_BASE}" 
echo " - ORACLE_HOME       = ${ORACLE_HOME}" 
echo " - ORACLE_FMW_HOME   = ${ORACLE_FMW_HOME}" 
echo " - JAVA_HOME         = ${JAVA_HOME}" 
echo " - LOG_BASE          = ${LOG_BASE}" 
echo " - ORACLE_DATA       = ${ORACLE_DATA}"
echo " - DOWNLOAD          = ${DOWNLOAD}"

${DOWNLOAD}/${OUDBASE_PKG} -va -b ${ORACLE_BASE} -j ${JAVA_HOME} -d ${ORACLE_DATA}

# clean up
if [ "${ORADBA_DEBUG^^}" == "TRUE" ]; then
    echo " - \$ORADBA_DEBUG set to TRUE, keep temp and log files"
else
    echo " - \$ORADBA_DEBUG not set, remove temp and log files"
    echo " - remove log files"
    rm -rf ${DOWNLOAD}/${OUDBASE_PKG}
    rm -rf  ${DOWNLOAD}/oudbase_install.log
fi
# --- EOF ----------------------------------------------------------------------