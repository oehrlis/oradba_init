#!/bin/bash
# -----------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# -----------------------------------------------------------------------------
# Name.......: 55_create_database_env.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2021.01.07
# Revision...: 
# Purpose....: Script to create the DB environment.
# Notes......: --
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# -----------------------------------------------------------------------------
# - Customization -------------------------------------------------------------
LOCAL_ORACLE_SID=${1:-"TDB183C"}                                        # Default name for Oracle database
LOCAL_ORACLE_PDB=${2:-"PDB1"}                                           # Check whether ORACLE_PDB is passed on
LOCAL_CONTAINER=${3:-"false"}                                           # Check whether CONTAINER is passed on
# - End of Customization ------------------------------------------------------

# - Default Values ------------------------------------------------------------
# source generic environment variables and functions
ORADBA_INIT="$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"
if [ -f "${ORADBA_INIT}" ]; then
    source "${ORADBA_INIT}"
else
    echo "ERR  : could not source ${ORADBA_INIT}"
    exit 127
fi

# default Values for Script
export SCRIPT_BIN=$(dirname ${BASH_SOURCE[0]})
export SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SCRIPT_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SCRIPT_BASE=$(dirname ${SCRIPT_BIN_DIR})

# Default Values for DB
export DOMAIN=${DOMAIN:-"trivadislabs.com"} 
export ORACLE_SID=${ORACLE_SID:-${LOCAL_ORACLE_SID}}                    # Default SID for Oracle database
export ORACLE_DBNAME=${ORACLE_DBNAME:-${ORACLE_SID}}                    # Default name for Oracle database
export ORACLE_DB_UNIQUE_NAME=${ORACLE_DB_UNIQUE_NAME:-${ORACLE_DBNAME}} # Default name for Oracle database

# Default Values for folders
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}                               # default location for the Oracle root / software mountpoint
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}                               # default location for the Oracle data mountpoint
export ORACLE_ARCH=${ORACLE_ARCH:-"/u02"}                               # default location for the second Oracle data mountpoint 
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"19.0.0.0"}                 # default name for the oracle home name
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}          # default location for the Oracle base directory
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product/ -name sqlplus -type f|sort|tail -1)))}
 
# define logfile and logging
export LOG_BASE=${LOG_BASE:-"/tmp"}                          # Use script directory as default logbase
TIMESTAMP=$(date "+%Y.%m.%d_%H%M%S")
readonly LOGFILE="$LOG_BASE/$(basename $SCRIPT_NAME .sh)_$TIMESTAMP.log"
# default value for ORATAB if not defined
ORATAB=${ORATAB:-"/etc/oratab"}
# get first argument from commandline as local SID
newSID=$1
# - EOF Default Values --------------------------------------------------------

# - Functions -----------------------------------------------------------

# -----------------------------------------------------------------------
# Purpose....: Display Usage
# -----------------------------------------------------------------------
function Usage()
{
    echo ""
    echo "Usage, ${SCRIPT_NAME} <ORACLE_SID> "
    echo ""

    if [ ${1} -gt 0 ]; then
        CleanAndQuit ${1}
    else
        CleanAndQuit 0
    fi
}

# -----------------------------------------------------------------------
# Purpose....: Clean up before exit
# -----------------------------------------------------------------------
function CleanAndQuit()
{
    echo
    ERROR_CODE=${1:-0}
    ERROR_VALUE=${2:-"n/a"}
    case ${1} in
        0)  echo "END  : of ${SCRIPT_NAME}";;
        1)  echo "ERR  : Exit Code ${ERROR_CODE}. Wrong amount of arguments. See usage for correct one.";;
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

# - EOF Functions -------------------------------------------------------

# - Initialization ------------------------------------------------------------
# Define a bunch of bash option see 
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o nounset                              # stop script after 1st cmd failed
set -o errexit                              # exit when 1st unset variable found
set -o pipefail                             # pipefail exit after 1st piped commands failed

# initialize logfile
touch $LOGFILE 2>/dev/null
exec &> >(tee -a "$LOGFILE")                # Open standard out at `$LOG_FILE` for write.  
exec 2>&1  

# Check if parameter is not empty
if [ -z "${newSID}" ] ; then
    CleanAndQuit 20
# Check for a valid SID
elif [ $(cat $ORATAB | grep "^${newSID}" | wc -l) -ne 1 ] ; then
    CleanAndQuit 21
fi

# - Main ----------------------------------------------------------------------
echo "INFO: Start to create DB environment for SID on $(hostname) at $(date)"

# set environment BasEnv and database
if [ -f "$HOME/.BE_HOME" ]; then
    echo " - source TVD-BasEnv"
    . "$HOME/.BE_HOME"                              # load BE_HOME
    . "$HOME/.TVDPERL_HOME"                         # load TVDPERL_HOME
    . ${BE_HOME}/bin/basenv.sh                      # source basenv
    . ${BE_HOME}/bin/oraenv.ksh ${MY_ORACLE_SID}    # source SID environment
    # sed -i "/$MY_ORACLE_SID/{s/;[0-9][0-9];/;10;/}" $ETC_BASE/sidtab
    # echo "[${MY_ORACLE_SID}]">$ETC_BASE/sid.${MY_ORACLE_SID}.conf
else   
    echo " - skip TVD-BasEnv"
fi

# check default environment variables
if [ -z "${ORACLE_BASE}" ] || [ ! -d ${ORACLE_BASE} ] ; then
    CleanAndQuit 30
fi

if [ -z "${ORACLE_HOME}" ] || [ ! -d ${ORACLE_HOME} ] ; then
    CleanAndQuit 31
fi

if [ -z "${ORACLE_SID}" ] ; then
    CleanAndQuit 32
fi

# Create admin directories
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/adhoc
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/arch
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/backup
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/dpdump
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/adump
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/pfile
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/etc
mkdir -pv $BE_ORA_ADMIN/${ORACLE_SID}/log

# Create data file folders
for i in $(ls -d /u0?/oradata); do
    mkdir -pv $i/${ORACLE_SID}
done

mkdir -pv $(ls -d /u0?/fast_recovery_area |tail -1)/${ORACLE_SID}

if [ $( grep -ic $ORACLE_SID ${TNS_ADMIN}/tnsnames.ora) -eq 0 ]; then
    echo "Add $ORACLE_SID to ${TNS_ADMIN}/tnsnames.ora."
    echo "${ORACLE_SID}.${DOMAIN}=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$(hostname))(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${ORACLE_SID}.${DOMAIN})))">>${TNS_ADMIN}/tnsnames.ora
else
    echo "TNS name entry ${ORACLE_SID} does exists."
fi
# Create TNS Names entry
echo "INFO: Finish creating the DB environment on $(hostname) at $(date)"
# --- EOF ---------------------------------------------------------------------
