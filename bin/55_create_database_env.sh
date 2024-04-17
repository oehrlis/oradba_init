#!/bin/bash
# -----------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Data Platforms
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
LOCAL_ORACLE_SID=${1:-"SDBM"}               # Default name for Oracle database
ORADBA_BIN=$(dirname ${BASH_SOURCE[0]})
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

# define logfile and logging
export LOG_BASE=${LOG_BASE:-"/tmp"}                          # Use script directory as default logbase
TIMESTAMP=$(date "+%Y.%m.%d_%H%M%S")
readonly LOGFILE="$LOG_BASE/$(basename $SCRIPT_NAME .sh)_${LOCAL_ORACLE_SID}_$TIMESTAMP.log"
# - EOF Default Values --------------------------------------------------------

# - Initialization ------------------------------------------------------------
# Define a bunch of bash option see 
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o nounset                              # stop script after 1st cmd failed
#set -o errexit                              # exit when 1st unset variable found
set -o pipefail                             # pipefail exit after 1st piped commands failed

# initialize logfile
touch $LOGFILE 2>/dev/null
exec &> >(tee -a "$LOGFILE")                # Open standard out at `$LOG_FILE` for write.  
exec 2>&1  

# - Main ----------------------------------------------------------------------
echo "INFO: Start to create DB environment for SID at $(date)"

# Check if parameter is not empty
if [ -z "${LOCAL_ORACLE_SID}" ] ; then
    CleanAndQuit 20
# Check for a valid SID
elif [ $(cat $ORATAB | grep "^${LOCAL_ORACLE_SID}" | wc -l) -ne 1 ] ; then
    echo "INFO: Add ${LOCAL_ORACLE_SID} to oratab $ORATAB"
    echo "${LOCAL_ORACLE_SID}:${ORACLE_HOME}:Y" >>$ORATAB
else
    echo "INFO: ${LOCAL_ORACLE_SID} already exists in oratab $ORATAB"
fi

# set environment BasEnv and database
if [ -f "$HOME/.BE_HOME" ]; then
    echo "INFO: source TVD-BasEnv"
    . $HOME/.BE_HOME
    . ${BE_HOME}/bin/basenv.ksh
    . ${BE_HOME}/bin/oraenv.ksh ${LOCAL_ORACLE_SID}           # source SID environment
else   
    echo "INFO: skip TVD-BasEnv"
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
mkdir -pv "$(dirname $(find /u0? -name fast_recovery_area 2>/dev/null|tail -1))/backup/${ORACLE_SID}"

cat << EOF >$BE_ORA_ADMIN/${ORACLE_SID}/etc/rman.conf
target=/
catalog=nocatalog
CF_ChannelType="disk"
CF_ChannelNo=2
CF_Compress=1
CF_BckPathParm="${ORACLE_ARCH}/backup/$MY_ORACLE_SID"
CF_MailIfOk=2
EOF

# Create TNS Names entry
if [ $( grep -ic $ORACLE_SID ${TNS_ADMIN}/tnsnames.ora) -eq 0 ]; then
    echo "INFO: Add $ORACLE_SID to ${TNS_ADMIN}/tnsnames.ora."
    echo "${ORACLE_SID}.${DOMAIN}=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${HOST})(PORT=${ORACLE_PORT}))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${ORACLE_SID}.${DOMAIN}))(UR=A))">>${TNS_ADMIN}/tnsnames.ora
else
    echo "INFO: TNS name entry ${ORACLE_SID} does exists."
fi

echo "INFO: Finish creating the DB environment ${LOCAL_ORACLE_SID} at $(date)"
# --- EOF ---------------------------------------------------------------------
