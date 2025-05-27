#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 00_setup_oradba_init.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Script to initialize and install oradba init scripts.
# Notes......: When executed, the oradba init scripts will be downloaded from 
#              github and installed. If the file is just sourced, only the 
#              common functions and environment variables will be set.
#              Script would like to be executed as root or source as 
#              anybody :-) 
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
# - just add/update any kind of customized environment variable here
export OPT_DIR=${OPT_DIR:-"/opt"}
export ORADBA_BIN=${ORADBA_BIN:-"/opt/oradba/bin"}
export DEFAULT_DOMAIN="oradba.ch"
export DEFAULT_ORACLE_ROOT="/u00"
export DEFAULT_ORACLE_DATA="/u01"
export DEFAULT_ORACLE_ARCH="/u02"
export DEFAULT_ORACLE_HOME_NAME="19.0.0.0"
export DEFAULT_ORACLE_PORT="1521"
export DB_CONFIG_SCRIPT="53_config_database.sh"
export DB_CLONE_SCRIPT="56_clone_database.sh"
export DB_ENV_SCRIPT="55_create_database_env.sh"
# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# Default Values for DB naming
export DOMAIN=${DOMAIN:-${DEFAULT_DOMAIN}}
export ORACLE_SID=${ORACLE_SID:-${LOCAL_ORACLE_SID}}                    # Default SID for Oracle database
export ORACLE_DBNAME=${ORACLE_DBNAME:-${ORACLE_SID}}                    # Default name for Oracle database
export ORACLE_DB_UNIQUE_NAME=${ORACLE_DB_UNIQUE_NAME:-${ORACLE_DBNAME}} # Default name for Oracle database
export ORACLE_PDB=${ORACLE_PDB:-${LOCAL_ORACLE_PDB}}                    # Check whether ORACLE_PDB is passed on
# Default Values for folders
export ORACLE_ROOT=${ORACLE_ROOT:-${DEFAULT_ORACLE_ROOT}}                   # default location for the Oracle root / software mountpoint
export ORACLE_DATA=${ORACLE_DATA:-${DEFAULT_ORACLE_DATA}}                   # default location for the Oracle data mountpoint
export ORACLE_ARCH=${ORACLE_ARCH:-${DEFAULT_ORACLE_ARCH}}                   # default location for the second Oracle data mountpoint 
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-${DEFAULT_ORACLE_HOME_NAME}}    # default name for the oracle home name
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}              # default location for the Oracle base directory
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product  -name sqlplus -type f 2>/dev/null |sort|tail -1)2>/dev/null)2>/dev/null)}
export ORACLE_INVENTORY=${ORACLE_INVENTORY:-${ORACLE_ROOT}/app/oraInventory}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-"${ORACLE_HOME}/lib:/usr/lib"}
export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}

# Default Values DB config
export CONTAINER=${CONTAINER:-${LOCAL_CONTAINER}}                       # Check whether CONTAINER is passed on
export DB_MASTER=${DB_MASTER:-""}                                       # Flag to clone database from master
export OMF=${OMF:-${LOCAL_OMF}}                                         # Flag to use Oracle Managed Files
export OPTIONS=${OPTIONS:-${LOCAL_OPTIONS}}                             # DBCA options to enable / disable features
export NO_DATABASE=${NO_DATABASE:-"FALSE"}                              # Flag to create container without a database
export ORACLE_VERSION="$(${ORACLE_HOME}/bin/sqlplus -V 2>/dev/null|grep -ie 'Release\|Version'|sed 's/^.*\([0-9]\{2\}\.[0-9]\.[0-9]\.[0-9]\.[0-9]\).*$/\1/'|tail -1)"
export ORACLE_RELEASE="$(${ORACLE_HOME}/bin/sqlplus -V 2>/dev/null|grep -ie 'Release'|tr '\n' ' ' |sed 's/^.*\([0-9]\{2\}\.[0-9]\.[0-9]\).*$/\1/'|tail -1)"
export ORACLE_PWD=${ORACLE_PWD:-""}                                     # Default admin password
export ORACLE_SID_ADMIN="${ORACLE_BASE}/admin/${ORACLE_SID}"
export ORACLE_SID_ADMIN_ETC="${ORACLE_SID_ADMIN}/etc"
export ORACLE_PORT=${ORACLE_PORT:-$DEFAULT_ORACLE_PORT}
# default folder for DB instance init scripts
export INSTANCE_INIT=${INSTANCE_INIT:-"${ORACLE_SID_ADMIN}/scripts"}

# define oradba specific variables
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP=${ORADBA_RSP:-"${ORADBA_BASE}/rsp"}                   # oradba init response file folder
export ORADBA_RSP=${CUSTOM_RSP:-"${ORADBA_RSP}"}                        # custom response file folder
export ORADBA_TEMPLATE_PREFIX=${ORADBA_TEMPLATE_PREFIX:-""}
export ORADBA_RSP_FILE=${ORADBA_RSP_FILE:-"dbca${ORACLE_RELEASE}.rsp.tmpl"} # oradba init response file
export ORADBA_DBC_FILE=${ORADBA_DBC_FILE:-"${ORADBA_TEMPLATE_PREFIX}dbca${ORACLE_RELEASE}.dbc.tmpl"}
export ORADBA_TEMPLATE=${ORADBA_TEMPLATE:-"${ORACLE_SID_ADMIN_ETC}/dbca${ORACLE_SID}.dbc"}
export ORADBA_RESPONSE=${ORADBA_RESPONSE:-"${ORACLE_SID_ADMIN_ETC}/dbca${ORACLE_SID}.rsp"}

HOSTNAME_BIN=$(command -v hostname)                                     # get the binary for hostname
HOSTNAME_BIN=${HOSTNAME_BIN:-"cat /proc/sys/kernel/hostname"}           # fallback to /proc/sys/kernel/hostname
export HOST=$(${HOSTNAME_BIN})
export DOMAIN=${DOMAIN:-$(hostname -d 2>/dev/null ||cat /etc/domainname ||echo ${DEFAULT_DOMAIN})}
# default value for ORATAB if not defined
ORATAB=${ORATAB:-"/etc/oratab"}
# - EOF Default Values ---------------------------------------------------------

# - Environment Variables ------------------------------------------------------
# define the oradba url and package name
export GITHUB_URL="https://codeload.github.com/oehrlis/oradba_init/zip/master"
export ORADBA_PKG="oradba_init.zip"
export ORADBA_DEBUG=${ORADBA_DEBUG:-"FALSE"}    # enable debug mode

# define the defaults for software, download etc
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-true}                 # Flag to set yum clean up
# - EOF Environment Variables --------------------------------------------------

# - Default Values -------------------------------------------------------------
# - EOF Default Values ---------------------------------------------------------

# - Functions ------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Purpose....: Clean up before exit
# ------------------------------------------------------------------------------
function CleanAndQuit()
{
    echo
    ERROR_CODE=${1:-0}
    ERROR_VALUE=${2:-"n/a"}
    case ${1} in
        0)  echo "END  : of ${SCRIPT_NAME}";;
        1)  echo "ERR  : Exit Code ${ERROR_CODE}. Wrong amount of arguments. See usage for correct one.";;
        12) echo "ERR  : Exit Code ${1}. Can not create directory ${2}";;
        13) echo "ERR  : Exit Code ${1}. Directory ${2} is not writeable";;
        14) echo "ERR  : Exit Code ${1}. Directory ${2} already exists";;
        20) echo "ERR  : New SID is unset or set to the empty string!";;
        21) echo "ERR  : Invalid SID provided! SID ${ERROR_VALUE} not in $ORATAB!";;
        30) echo "ERR  : \$ORACLE_BASE ${ORACLE_BASE} is unset, set to the an empty string or directory not found!";;
        31) echo "ERR  : \$ORACLE_HOME ${ORACLE_HOME} is unset, set to the an empty string or directory not found!";;
        32) echo "ERR  : \$ORACLE_SID ${ORACLE_SID} is unset or set to the empty string!";;
        99) echo "INFO : Just wanna say hallo.";;
        ?)  echo "ERR  : Exit Code ${ERROR_CODE}. Unknown Error.";;
    esac
    exit ${1}
}

function get_software {
# ------------------------------------------------------------------------------
# Purpose....: Verify if the software package is available if not try to 
#              download it from $SOFTWARE_REPO
# ------------------------------------------------------------------------------
    PKG=$1
    if [ ! -s "${SOFTWARE}/${PKG}" ]; then
        if [ ! -z "${SOFTWARE_REPO}" ]; then
            echo " - Try to download ${PKG} from ${SOFTWARE_REPO}"
            curl -f ${SOFTWARE_REPO}/${PKG} -o ${SOFTWARE}/${PKG} 2>&1
            CURL_ERR=$?
            if [ ${CURL_ERR} -ne 0 ]; then
                echo " - WARNING: Unable to access software repository or ${PKG} (curl error ${CURL_ERR})"
                return 1
            fi
        else
            echo " - WARNING: No software repository specified"
            return 1
        fi
    else
        echo " - Found package ${PKG} for installation."
        return 0
    fi
}

function running_in_docker() {
# ------------------------------------------------------------------------------
# Purpose....:  Function for checking whether the process is running in a 
#               container. It return 0 if YES or 1 if NOT.
# ------------------------------------------------------------------------------
    if [ -f /.dockerenv ]; then
        return 0
    else
        return 1
    fi
}

function gen_password {
# ------------------------------------------------------------------------------
# Purpose....: generate a password string
# ------------------------------------------------------------------------------
    Length=${1:-12}

    # make sure, that the password length is not shorter than 4 characters
    if [ ${Length} -lt 4 ]; then
        Length=4
    fi

    # generate password
    if [ $(command -v pwgen) ]; then 
        pwgen -s -1 ${Length}
    else 
        while true; do
            # use urandom to generate a random string
            s=$(cat /dev/urandom | tr -dc "A-Za-z0-9" | fold -w ${Length} | head -n 1)
            # check if the password meet the requirements
            if [[ ${#s} -ge ${Length} && "$s" == *[A-Z]* && "$s" == *[a-z]* && "$s" == *[0-9]*  ]]; then
                echo "$s"
                break
            fi
        done
    fi
}

# - EOF Functions --------------------------------------------------------------

# check if script is sourced and return/exit

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    echo " - Script is executed -------------------------------------------------"
    # Make sure only root can run our script
    if [ $EUID -ne 0 ]; then
        echo " - ERROR: This script must be run as root" 1>&2
        exit 1
    fi
    # create a software depot
    mkdir -p ${SOFTWARE}
    chmod 777 ${SOFTWARE}

    # - Get oradba init scripts ------------------------------------------------
    echo " - Get oradba init scripts --------------------------------------------"
    mkdir -p ${DOWNLOAD}                                    # create download folder
    curl -Lf ${GITHUB_URL} -o ${DOWNLOAD}/${ORADBA_PKG}

    # check if we do have an unzip command
    if [ ! -z $(command -v unzip) ]; then 
        # unzip seems to be available
        unzip -o ${DOWNLOAD}/${ORADBA_PKG} -d /opt          # unzip scripts
    else 
        # missing unzip fallback to a simple phyton script as python seems
        # to be available on Docker image oraclelinx:7-slim
        echo " - no unzip available, fallback to python script"
        echo "import zipfile" >${DOWNLOAD}/unzipfile.py
        echo "with zipfile.ZipFile('${DOWNLOAD}/${ORADBA_PKG}', 'r') as z:" >>${DOWNLOAD}/unzipfile.py
        echo "   z.extractall('${OPT_DIR}')">>${DOWNLOAD}/unzipfile.py
        python ${DOWNLOAD}/unzipfile.py

        # adjust file mods
        find ${OPT_DIR} -type f -name *.sh -exec chmod 755 {} \;
    fi

    if [ -d "${OPT_DIR}/oradba" ]; then
        echo " - update existing ----------------------------------------------------"
        \cp -rf ${OPT_DIR}/oradba_init-master/* ${OPT_DIR}/oradba/
        rm -rf ${OPT_DIR}/oradba_init-master
    else
        echo " - create new  --------------------------------------------------------"
        mv ${OPT_DIR}/oradba_init-master ${OPT_DIR}/oradba      # get rid of master folder
    fi
    [ -f ${OPT_DIR}/oradba/README.md ] && mv ${OPT_DIR}/oradba/README.md ${OPT_DIR}/oradba/doc    # move documentation
    [ -f ${OPT_DIR}/oradba/.gitignore ] && rm ${OPT_DIR}/oradba/.gitignore                         # remove gitignore
    rm -rf ${DOWNLOAD} 
else
    echo " - Set common functions and variables ---------------------------------"
    return
fi
# --- EOF ----------------------------------------------------------------------
