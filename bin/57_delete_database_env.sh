#!/bin/bash
# -----------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# -----------------------------------------------------------------------------
# Name.......: 57_delete_database_env.sh
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
LOCAL_ORACLE_SID=${1:-""}               # Default name for Oracle database
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
readonly LOGFILE="$LOG_BASE/$(basename $SCRIPT_NAME .sh)_$TIMESTAMP.log"
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
echo "INFO: Start to delete DB environment for SID ${LOCAL_ORACLE_SID} on ${HOST} at $(date)"

# Check if DB environment exits
if [ $(cat $ORATAB | grep "^${LOCAL_ORACLE_SID}" | wc -l) -ne 0 ] ; then
    echo "INFO: ${LOCAL_ORACLE_SID} does exists in oratab $ORATAB"

    # set database environment 
    if [ -f "$HOME/.BE_HOME" ]; then
        . $HOME/.BE_HOME
        . ${BE_HOME}/bin/basenv.ksh
        . ${BE_HOME}/bin/oraenv.ksh ${LOCAL_ORACLE_SID}           # source SID environment
    else 
        ORACLE_SID=${LOCAL_ORACLE_SID}
    fi

    # Shutdown database
    $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
        SHUTDOWN ABORT;
        exit;
EOF
fi

# set some variables
typeset -l ORACLE_SID_lowercase=${ORACLE_SID}
BE_ORA_ADMIN_SID=${BE_ORA_ADMIN_SID:-${ORACLE_BASE}/admin/${ORACLE_SID}}
# cleanup/remove the admin files
rm -rf ${BE_ORA_ADMIN_SID}

# cleanup/remove the files - diag, fast_recovery_area and startup init${SID}.ora
rm -rf ${ORACLE_BASE}/diag/rdbms/${ORACLE_SID_lowercase}/${ORACLE_SID}
rm -rf ${ORACLE_BASE}/audit/${ORACLE_SID}
rm -rf ${ORACLE_HOME}/dbs/*${ORACLE_SID}*
rm -rf /u??/fast_recovery_area/${ORACLE_SID}

# cleanup/remove the data files
rm -rf /u??/oradata/${ORACLE_SID}

# remove TNS Names entry
sed -i -e "/^${ORACLE_SID}/d" ${TNS_ADMIN}/tnsnames.ora
sed -i -e "/^${ORACLE_SID}/d" ${ORATAB}

echo "INFO: Finish deleting the DB environment ${ORACLE_SID} on ${HOST} at $(date)"
# --- EOF ---------------------------------------------------------------------
