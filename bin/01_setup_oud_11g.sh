#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 01_setup_oud_11g.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to install Oracle Unified Directory 11g.
# Notes......: Script would like to be executed as oracle :-).
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
# Version dependend settings
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"oud12.2.1.3.0"}
# define the software packages
export OUD_BASE_PKG=${OUD_BASE_PKG:-"p26270957_122130_Generic.zip"}
export OUD_PSU_PKG=${OUD_PSU_PKG:-""}
export OPATCH_PKG=${OPATCH_PKG:-""}

# other stuff
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}     # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-/u01}     # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-$ORACLE_ROOT/app/oracle}
export ORACLE_INVENTORY=${ORACLE_INVENTORY:-$ORACLE_ROOT/app/oraInventory}
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"
export SLIM=${SLIM:-"FALSE"}
export SOFTWARE="/opt/stage"
export SOFTWARE_REPO=""
export DOWNLOAD="/tmp/download"
export CLEANUP=${CLEANUP:-true}             # Flag to set yum clean up
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

# Create response file
echo " - Prepare response file ----------------------------------------------"
echo "[ENGINE]"                                                                                             >/tmp/oud_install.rsp
echo "Response File Version=1.0.0.0.0"                                                                      >>/tmp/oud_install.rsp
echo "[GENERIC]"                                                                                            >>/tmp/oud_install.rsp
echo "DECLINE_SECURITY_UPDATES=true"                                                                        >>/tmp/oud_install.rsp
echo "SECURITY_UPDATES_VIA_MYORACLESUPPORT=false"                                                           >>/tmp/oud_install.rsp
echo "INSTALL_TYPE='Standalone Oracle Unified Directory Server (Managed independently of WebLogic server)'" >>/tmp/oud_install.rsp

# Create response file
echo " - Prepare response file ----------------------------------------------"
echo "inventory_loc=${ORACLE_INVENTORY}"   >/tmp/oraInst.loc
echo "inst_group=oinstall"                 >>/tmp/oraInst.loc

# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install database binaries -----------------------------------------------
echo " - Install Oracle OUD binaries ----------------------------------------"
if [ -n "${OUD_BASE_PKG}" ]; then
    if get_software "${OUD_BASE_PKG}"; then          # Check and get binaries
        mkdir -p ${ORACLE_HOME}
        unzip -o ${SOFTWARE}/${OUD_BASE_PKG} -d ${DOWNLOAD}
        # the jar file name from the logfile
        OUD_BASE_JAR=$(grep -i jar ${OUD_BASE_PKG} |cut -d' ' -f3| tr -d " ")
        # Install OUD binaries
        $JAVA_HOME/bin/java -jar ${DOWNLOAD}/$OUD_BASE_JAR -silent \
            -responseFile /tmp/oud_install.rsp \
            -invPtrLoc /tmp/oraInst.loc \
            -ignoreSysPrereqs -force \
            -novalidation ORACLE_HOME=${ORACLE_HOME} \
            INSTALL_TYPE="Standalone Oracle Unified Directory Server (Managed independently of WebLogic server)"

        # remove files on docker builds
        rm -rf ${DOWNLOAD}/$OUD_BASE_JAR /tmp/oud_install.rsp /tmp/oraInst.loc
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${OUD_BASE_PKG}; fi
    else
        echo "ERROR:   No base software package specified. Abort installation."
        exit 1
    fi
fi

# - Install OPatch ----------------------------------------------------------
echo " - Install OPatch -----------------------------------------------------"
if [ -n "${OPATCH_PKG}" ]; then
    if get_software "${OPATCH_PKG}"; then           # Check and get binaries
        rm -rf ${ORACLE_HOME}/OPatch                # remove old OPatch
        unzip -o ${SOFTWARE}/${OPATCH_PKG} \
            -d ${ORACLE_HOME}/                      # unpack OPatch binary package
        # remove files on docker builds
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${OPATCH_PKG}; fi
    else
        echo "WARNING: Skip OPatch update."
    fi
fi

# - Install OUD PSU ---------------------------------------------------------
echo " - Install OUD PSU ----------------------------------------------------"
if [ -n "${OUD_PSU_PKG}" ]; then
    if get_software "${OUD_PSU_PKG}"; then            # Check and get binaries
        OUD_PSU_ID=$(echo ${OUD_PSU_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        unzip -o ${SOFTWARE}/${OUD_PSU_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${OUD_PSU_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent
        # remove files on docker builds
        if [ "${DOCKER^^}" == "TRUE" ]; then rm -rf ${SOFTWARE}/${OUD_PSU_PKG}; fi
        rm -rf ${DOWNLOAD}/${OUD_PSU_ID}            # remove the binary packages
        rm -rf PatchSearch.xml                      # remove the binary packages
    else
        echo "WARNING: Skip OUD PSU installation."
    fi
fi

echo " - CleanUp installation -----------------------------------------------"
# Remove not needed components
# OUI backup
rm -rf ${ORACLE_HOME}/inventory/backup/*
# Temp location
rm -rf ${DOWNLOAD}/*
rm -rf /tmp/OraInstall*

# Temp locations
rm -rf ${DOWNLOAD}
rm -rf /tmp/*.rsp
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle
rm -rf /tmp/OraInstall*

# remove all the logs....
find ${ORACLE_BASE}/cfgtoollogs . -name *.log -exec rm {} \;
find ${ORACLE_BASE}/local . -name *.log -exec rm {} \;
find ${ORACLE_BASE}/oraInventory . -name *.log -exec rm {} \;
find ${ORACLE_BASE}/product . -name *.log -exec rm {} \;

if [ "${SLIM^^}" == "TRUE" ]; then
    # remove inventory
    rm -rf ${ORACLE_HOME}/inventory
    # remove oui
    rm -rf ${ORACLE_HOME}/oui
    # remove OPatch
    rm -rf ${ORACLE_HOME}/OPatch
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/OraInstall*
    # remove patch storage
    rm -rf ${ORACLE_HOME}/.patch_storage
fi
# --- EOF --------------------------------------------------------------------


# Get the package and psu's from cli
FMW_OUD_PKG=${1:-${DEFAULT_FMW_OUD_PKG}}
FMW_OUD_PKG_LOG=$(basename ${FMW_OUD_PKG} .zip).log
OUD_PATCH=${2:-${DEFAULT_OUD_PATCH}}
SLIM=${3:-"FALSE"}


# clean up
rm -rf ${DOWNLOAD}/${FMW_OUD_PKG} \
       ${DOWNLOAD}/${FMW_OUD_PKG_LOG} \
       ${DOWNLOAD}/${FMW_OUD_JAR}

# - Install OUD Patch / PSU --------------------------------------------
if [ -n ${OUD_PATCH} ]; then
    for i in $(echo "${OUD_PATCH}"|sed s/\,/\ /g); do
        OUD_PSU=${i}
        OUD_PSU_ID=$(echo $OUD_PSU| sed -E 's/p([[:digit:]]+).*/\1/')
        echo "Install Oracle Patch / PSU ${OUD_PSU_ID}"
        # Get the latest database RU if it is not there yet
        if [ ! -s "${DOWNLOAD}/${OUD_PSU}" ]; then
            echo "download ${DOWNLOAD}/${OUD_PSU} from orarepo"
            curl -f http://${ORAREPO}/${OUD_PSU} -o ${DOWNLOAD}/${OUD_PSU}
        else
            echo "use local copy of ${DOWNLOAD}/${OUD_PSU}"
        fi

        # unzip OUD PSU
        cd ${DOWNLOAD}
        $JAVA_HOME/bin/jar xvf ${OUD_PSU}

        # install OUD PSU
        cd ${OUD_PSU_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent

        # clean up
        rm -rf ${DOWNLOAD}/${OUD_PSU} \
               ${DOWNLOAD}/${OUD_PSU_ID}
    done
else
    echo "No OUD Patch / PSU specified"
fi