#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Data Platforms
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 10_setup_oud.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: generic script to install Oracle Unified Directory binaries.
# Notes......: Script would like to be executed as oracle :-).
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------
# - Customization -----------------------------------------------------------
# OUD_BASE_PKG="p30188352_122140_Generic.zip"         # OUD 12.2.1.4.0
# FMW_BASE_PKG="p30188255_122140_Generic.zip"         # ORACLE FUSION MIDDLEWARE 12C (12.2.1.4.0) INFRASTRUCTURE (Patchset)
# OUD_PATCH_PKG="p30851280_122140_Generic.zip"        # OUD BUNDLE PATCH 12.2.1.4.200204 (Patch) 
# FMW_PATCH_PKG="p30689820_122140_Generic.zip"        # WLS PATCH SET UPDATE 12.2.1.4.191220 (Patch) 
# OUD_OPATCH_PKG="p28186730_139422_Generic.zip"       # OPATCH 13.9.4.2.2 FOR FMW/WLS 12.2.1.3.0 AND 12.2.1.4.0 (Patch) 
# OUI_PATCH_PKG=""
# COHERENCE_PATCH_PKG="p30729380_122140_Generic.zip"  # Coherence 12.2.1.4.3 Cumulative Patch using OPatch (Patch) 
# ORACLE_HOME_NAME="oud12.2.1.4.0"                    # Name of the Oracle Home directory
# ORACLE_HOME="${ORACLE_BASE}/product/${ORACLE_HOME_NAME}"
ORADBA_BIN=$(dirname ${BASH_SOURCE[0]})
# - End of Customization ----------------------------------------------------

# - Default Values ----------------------------------------------------------
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define the software packages default is just the OUD 12.2.1.4 base package
export OUD_BASE_PKG=${OUD_BASE_PKG:-"p30188352_122140_Generic.zip"} # OUD 12.2.1.4.0
export FMW_BASE_PKG=${FMW_BASE_PKG:-""}                             
export OUD_PATCH_PKG=${OUD_PATCH_PKG:-""}
export FMW_PATCH_PKG=${FMW_PATCH_PKG:-""}
export OUD_OPATCH_PKG=${OUD_OPATCH_PKG:-""}
export OUI_PATCH_PKG=${OUI_PATCH_PKG:-""}
export COHERENCE_PATCH_PKG=${COHERENCE_PATCH_PKG:-""}
export OUD_ONEOFF_PKGS=${OUD_ONEOFF_PKGS:-""}

export OUD_TYPE=${OUD_TYPE:-"OUD12"}
export OUD_INSTALL_TYPE=${OUD_INSTALL_TYPE:-'Standalone Oracle Unified Directory Server (Managed independently of WebLogic server)'}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder
export ORADBA_DEBUG=${ORADBA_DEBUG:-"FALSE"}    # enable debug mode
export PATCH_LATER=${PATCH_LATER:-"FALSE"}      # Flag to postpone patch and clear stuff

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}       # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}       # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}
export ORACLE_INVENTORY=${ORACLE_INVENTORY:-"${ORACLE_ROOT}/app/oraInventory"}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"oud12.2.1.3.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"

# define generic variables for software, download etc
export JAVA_HOME=${JAVA_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE} /usr/java -name javac 2>/dev/null|sort -r|head -1) 2>/dev/null) 2>/dev/null)}
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-"true"}               # Flag to set yum clean up
export SLIM=${SLIM:-"false"}                    # flag to enable SLIM setup
# - End of Default Values ---------------------------------------------------

# - Initialization ----------------------------------------------------------
# Make sure root does not run our script
if [ ! $EUID -ne 0 ]; then
   echo " - ERROR: This script must not be run as root" 1>&2
   exit 1
fi

# show what we will create later on...
echo " - Prepare Oracle OUD binaries installation ---------------------------"
echo " - ORACLE_ROOT       = ${ORACLE_ROOT}" 
echo " - ORACLE_DATA       = ${ORACLE_DATA}" 
echo " - ORACLE_BASE       = ${ORACLE_BASE}" 
echo " - ORACLE_HOME       = ${ORACLE_HOME}" 
echo " - ORACLE_INVENTORY  = ${ORACLE_INVENTORY}" 
echo " - JAVA_HOME         = ${JAVA_HOME}" 
echo " - OUD_TYPE          = ${OUD_TYPE}" 
echo " - SOFTWARE          = ${SOFTWARE}" 
echo " - DOWNLOAD          = ${DOWNLOAD}" 
echo " - OUD_BASE_PKG      = ${OUD_BASE_PKG}" 
echo " - FMW_BASE_PKG      = ${FMW_BASE_PKG}" 
echo " - OUD_PATCH_PKG     = ${OUD_PATCH_PKG}" 
echo " - FMW_PATCH_PKG     = ${FMW_PATCH_PKG}" 
echo " - OUD_OPATCH_PKG    = ${OUD_OPATCH_PKG}" 
echo " - OUI_PATCH_PKG     = ${OUI_PATCH_PKG}" 

# Replace place holders in responce file
echo " - Prepare response files ---------------------------------------------"
cp ${ORADBA_RSP}/oud_install.rsp.tmpl /tmp/oud_install.rsp

echo "inventory_loc=${ORACLE_INVENTORY}"   >/tmp/oraInst.loc
echo "inst_group=oinstall"                 >>/tmp/oraInst.loc
# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
mkdir -p ${ORACLE_BASE}/product
# - Install FWM Binaries ----------------------------------------------------
# - just required if you setup OUDSM
if [ "${OUD_TYPE}" == "OUDSM12" ]; then
    echo " - Install Oracle FMW binaries ----------------------------------------"
    export OUD_INSTALL_TYPE='Collocated Oracle Unified Directory Server (Managed through WebLogic server)'
    if [ -n "${FMW_BASE_PKG}" ]; then
        if get_software "${FMW_BASE_PKG}"; then          # Check and get binaries
            cd ${DOWNLOAD}
            # unpack OUD binary package
            FMW_BASE_LOG=$(basename ${FMW_BASE_PKG} .zip).log
            $JAVA_HOME/bin/jar xvf ${SOFTWARE}/${FMW_BASE_PKG} >${FMW_BASE_LOG}

            # get the jar file name from the logfile
            FMW_BASE_JAR=$(grep -i jar ${FMW_BASE_LOG} |cut -d' ' -f3| tr -d " ")

            # Install OUD binaries
            $JAVA_HOME/bin/java -jar ${DOWNLOAD}/$FMW_BASE_JAR -silent \
            -responseFile /tmp/oud_install.rsp \
            -invPtrLoc /tmp/oraInst.loc \
            -ignoreSysPrereqs -force \
            -novalidation ORACLE_HOME=${ORACLE_HOME} \
            INSTALL_TYPE="WebLogic Server"

            # remove files on docker builds
            rm -rf ${DOWNLOAD}/$FMW_BASE_JAR
            running_in_docker && rm -rf ${SOFTWARE}/${FMW_BASE_PKG}
        else
            echo " - ERROR: No base software package specified. Abort installation."
            exit 1
        fi
    fi
fi

# - Install OUD binaries ----------------------------------------------------
echo " - Install Oracle OUD binaries ----------------------------------------"
if [ -n "${OUD_BASE_PKG}" ]; then
    if get_software "${OUD_BASE_PKG}"; then          # Check and get binaries
        cd ${DOWNLOAD}
        # unpack OUD binary package
        OUD_BASE_LOG=$(basename ${OUD_BASE_PKG} .zip).log
        $JAVA_HOME/bin/jar xvf ${SOFTWARE}/${OUD_BASE_PKG} >${OUD_BASE_LOG}
        # identify OUD major release based on OUD_TYPE
        if [ "${OUD_TYPE}" == "OUD12" ] || [ "${OUD_TYPE}" == "OUDSM12" ]; then
            echo " - Start to install OUD 12c (${OUD_TYPE})"
            # get the jar file name from the logfile
            OUD_BASE_JAR=$(grep -i jar ${OUD_BASE_LOG} |cut -d' ' -f3| tr -d " ")

            # Install OUD binaries
            $JAVA_HOME/bin/java -jar ${DOWNLOAD}/$OUD_BASE_JAR -silent \
                -responseFile /tmp/oud_install.rsp \
                -invPtrLoc /tmp/oraInst.loc \
                -ignoreSysPrereqs -force \
                -novalidation ORACLE_HOME=${ORACLE_HOME} \
                INSTALL_TYPE="${OUD_INSTALL_TYPE}"

            # remove files on docker builds
            rm -rf ${DOWNLOAD}/$OUD_BASE_JAR
            running_in_docker && rm -rf ${SOFTWARE}/${OUD_BASE_PKG}
        else
            echo " - Start to install OUD 11g"
            chmod -R u+x ${DOWNLOAD}/Disk1
            # Install OUD binaries
            ${DOWNLOAD}/Disk1/runInstaller -silent \
                -jreLoc ${JAVA_HOME} \
                -waitforcompletion \
                -ignoreSysPrereqs -force \
                -response /tmp/oud_install.rsp \
                -invPtrLoc /tmp/oraInst.loc \
                ORACLE_HOME=${ORACLE_HOME}
        
            # remove files on docker builds
            rm -rf ${DOWNLOAD}/Disk1
            running_in_docker && rm -rf ${SOFTWARE}/${OUD_BASE_PKG}
        fi
    else
        echo " - ERROR: No base software package specified. Abort installation."
        exit 1
    fi
fi

# install patch any of the patch variable is if defined
if [ ! -z "${OUD_PATCH_PKG}" ] || [ ! -z "${FMW_PATCH_PKG}" ] || [ ! -z "${OUD_OPATCH_PKG}" ] || [ ! -z "${OUI_PATCH_PKG}" ] && [ "${PATCH_LATER^^}" == "FALSE" ]; then  
    if [ "${OUD_TYPE}" == "OUD12" ]; then
        DONT_FMW_PATCH_PKG=${FMW_PATCH_PKG}
        DONT_COHERENCE_PATCH_PKG=${COHERENCE_PATCH_PKG}
        DONT_CPU_WLS_ONEOFF_PKGS=${CPU_WLS_ONEOFF_PKGS}
        unset FMW_PATCH_PKG
        unset COHERENCE_PATCH_PKG
        unset CPU_WLS_ONEOFF_PKGS
        ${ORADBA_BIN}/11_setup_oud_patch.sh
        FMW_PATCH_PKG=${DONT_FMW_PATCH_PKG}
        COHERENCE_PATCH_PKG=${DONT_COHERENCE_PATCH_PKG}
        CPU_WLS_ONEOFF_PKGS=${DONT_CPU_WLS_ONEOFF_PKGS}
        unset DONT_FMW_PATCH_PKG
        unset DONT_COHERENCE_PATCH_PKG
        unset DONT_FMW_PATCH_PKG
    else
        ${ORADBA_BIN}/11_setup_oud_patch.sh
    fi
    ${ORADBA_BIN}/11_setup_oud_patch.sh
elif [ "${PATCH_LATER^^}" == "TRUE" ]; then
    echo " - Patch later. PATCH_LATER=$PATCH_LATER"
else
    echo " - Skip patch installation. No patch packages specified."
fi

echo " - CleanUp OUD installation -------------------------------------------"
# Remove not needed components
if running_in_docker && [ "${PATCH_LATER^^}" == "FALSE" ]; then
    echo " - remove Docker specific stuff"
    rm -rf ${ORACLE_HOME}/inventory/backup/*            # OUI backup
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

if [ "${SLIM^^}" == "TRUE" ] && [ "${PATCH_LATER^^}" == "FALSE" ]; then
    echo " - \$SLIM set to TRUE, remove other stuff..."
    rm -rf ${ORACLE_HOME}/inventory                 # remove inventory
    rm -rf ${ORACLE_HOME}/oui                       # remove oui
    rm -rf ${ORACLE_HOME}/OPatch                    # remove OPatch
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/OraInstall*
    rm -rf ${ORACLE_HOME}/.patch_storage            # remove patch storage
fi
# --- EOF --------------------------------------------------------------------