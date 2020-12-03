#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 01_setup_os_java.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Script to install Oracle server jre.
# Notes......: --
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
export JAVA_PKG=${JAVA_PKG:-"p31856315_180271_Linux-x86-64.zip"}

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}       # root folder for ORACLE_BASE and binaries
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}
export JAVA_BASE=${JAVA_BASE:-"${ORACLE_BASE}/product"} 
# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder
# define generic variables for software, download etc
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-true}                 # Flag to set yum clean up
# - EOF Environment Variables -----------------------------------------------

# - Install database binaries -----------------------------------------------
echo " - Oracle Java  -----------------------------------------"
if [ -n "${JAVA_PKG}" ]; then
    if get_software "${JAVA_PKG}"; then          # Check and get binaries
        mkdir -p  ${JAVA_BASE}
        # Install Oracle Java
        unzip -p ${SOFTWARE}/${JAVA_PKG} \
            *tar* | tar zxv -C ${JAVA_BASE}
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${JAVA_PKG}
        # set alternative stuff
        running_in_docker && \
        export JAVA_DIR=$(ls -1 -d ${JAVA_BASE}/jdk*|tail -1) && \
        mkdir -p /usr/java && \
        ln -s $JAVA_DIR /usr/java/latest && \
        ln -s $JAVA_DIR /usr/java/default && \
        alternatives --install /usr/bin/java java $JAVA_DIR/bin/java 20000 && \
        alternatives --install /usr/bin/javac javac $JAVA_DIR/bin/javac 20000 && \
        alternatives --install /usr/bin/jar jar $JAVA_DIR/bin/jar 20000
    else
        echo " - ERROR: No base software package specified. Abort installation."
        exit 1
    fi
fi

# add 3DES_EDE_CBC for Oracle EUS java.security.tmpl
JAVA_BIN=$(command -v ${JAVA_DIR}/bin/java)
if [ ! -z "$JAVA_BIN" ];then
    JAVA_SECURITY=$(find $(dirname $(dirname $(realpath $JAVA_BIN))) -name java.security 2>/dev/null)
    if [ ! -z ${JAVA_SECURITY} ] && [ -f ${JAVA_SECURITY} ]; then
        echo " - Relax java security settings for Oracle EUS."
        cp -v ${ORADBA_RSP}/java.security.tmpl ${JAVA_SECURITY}
    fi
else
    echo " - java security not configured."
fi
# --- EOF --------------------------------------------------------------------