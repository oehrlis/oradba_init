#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 52_create_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Helper script to create the Oracle database
# Notes......: Script to create an Oracle database. If configuration files are
#              provided, the will be used to configure the instance.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...: 
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------
# - Customization -------------------------------------------------------------
LOCAL_ORACLE_SID=${1:-"SDBM"}                                           # Default name for Oracle database
LOCAL_ORACLE_PDB=${2:-"PDB1"}                                           # Check whether ORACLE_PDB is passed on
LOCAL_CONTAINER=${3:-"false"}                                           # Check whether CONTAINER is passed on
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
readonly LOGFILE="$LOG_BASE/$(basename $SCRIPT_NAME .sh)_$TIMESTAMP.log"

# - EOF Default Values --------------------------------------------------------

# - EOF Environment Variables -------------------------------------------

# generate password if it is still empty
if [ -z ${ORACLE_PWD} ]; then
    # Auto generate Oracle WebLogic Server admin password
    ORACLE_PWD=$(gen_password 12)
    echo " ------------------------------------------------------------------------"
    echo " -  Oracle Database Server auto generated password:"
    echo " -  ----> User        : SYS, SYSTEM AND PDBADMIN"
    echo " -  ----> Password    : ${ORACLE_PWD}"
    echo " ------------------------------------------------------------------------"
fi 

# set instant init location create folder if it does exists
if [ ! -d "${INSTANCE_INIT}/setup" ]; then
    INSTANCE_INIT="${ORACLE_SID_ADMIN}/scripts"
fi

# inform what's done next...
echo " - Create database instance ${ORACLE_SID} using:"
echo " - ORACLE_DBNAME         : ${ORACLE_DBNAME}"
echo " - ORACLE_DB_UNIQUE_NAME : ${ORACLE_DB_UNIQUE_NAME}"
echo " - ORACLE_SID            : ${ORACLE_SID}"
echo " - HOST                  : ${HOST}"
echo " - ORACLE_HOME           : ${ORACLE_HOME}"
echo " - ORACLE_RELEASE        : ${ORACLE_RELEASE}"
echo " - ORACLE_VERSION        : ${ORACLE_VERSION}"
echo " - ORACLE_BASE           : ${ORACLE_BASE}"
echo " - ORACLE_DATA           : ${ORACLE_DATA}"
echo " - ORACLE_ARCH           : ${ORACLE_ARCH}"
echo " - CONTAINER             : ${CONTAINER}"
echo " - INSTANCE_INIT         : ${INSTANCE_INIT}"
echo " - RESPONSE FOLDER       : ${ORADBA_RSP}"
echo " - RESPONSE              : ${ORADBA_RSP_FILE}"
echo " - TEMPLATE              : ${ORADBA_DBC_FILE}"
echo " - ORADBA_TEMPLATE_PREFIX: ${ORADBA_TEMPLATE_PREFIX}"
echo " - DB RESPONSE           : ${ORADBA_RESPONSE}"
echo " - DB TEMPLATE           : ${ORADBA_TEMPLATE}"
echo " - ORACLE_CHARACTERSET   : ${ORACLE_CHARACTERSET}"
echo " - DB_MASTER             : ${DB_MASTER}"

# run create DB with dbca if DB_MASTER is undefined
if [ -z "$DB_MASTER" ]; then
    echo "INFO: Create ${ORACLE_SID} using dbca"
    # write password file
    mkdir -p ${ORACLE_SID_ADMIN_ETC}
    echo "${ORACLE_PWD}" > "${ORACLE_BASE}/admin/${ORACLE_SID}/etc/${ORACLE_SID}_password.txt"
    echo " - ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: ${ORACLE_PWD}";

    # Replace place holders in response file
    cp -v ${ORADBA_RSP}/${ORADBA_DBC_FILE} ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_DATA###|$ORACLE_DATA|g"                      ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_ARCH###|$ORACLE_ARCH|g"                      ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_DBNAME###|$ORACLE_DBNAME|g"                  ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_DB_UNIQUE_NAME###|$ORACLE_DB_UNIQUE_NAME|g"  ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g"                        ${ORADBA_TEMPLATE}
    sed -i -e "s|###DEFAULT_DOMAIN###|$DOMAIN|g"                        ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g"      ${ORADBA_TEMPLATE}

    # Replace place holders in response file
    cp -v ${ORADBA_RSP}/${ORADBA_RSP_FILE} ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"                      ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_DATA###|$ORACLE_DATA|g"                      ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_ARCH###|$ORACLE_ARCH|g"                      ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"                      ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_DBNAME###|$ORACLE_DBNAME|g"                  ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_DB_UNIQUE_NAME###|$ORACLE_DB_UNIQUE_NAME|g"  ${ORADBA_TEMPLATE}
    sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g"                        ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g"                        ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g"                        ${ORADBA_RESPONSE}
    sed -i -e "s|###CONTAINER###|$CONTAINER|g"                          ${ORADBA_RESPONSE}
    sed -i -e "s|###TEMPLATE###|${ORADBA_TEMPLATE}|g"                   ${ORADBA_RESPONSE}
    sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g"      ${ORADBA_RESPONSE}

    # If there is greater than 8 CPUs default back to dbca memory calculations
    # dbca will automatically pick 40% of available memory for Oracle DB
    # The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
    # However, bigger environment can and should use more of the available memory
    # This is due to Github Issue #307
    if [ `nproc` -gt 8 ]; then
    sed -i -e "s|totalMemory=2048||g" ${ORADBA_RESPONSE}
    fi;

    # update listener.ora in general just for the Docker listener.ora
    sed -i -e "s|<HOSTNAME>|${HOST}|g" ${TNS_ADMIN}/listener.ora

    # Start LISTENER and run DBCA
    $ORACLE_HOME/bin/lsnrctl status > /dev/null 2>&1 || $ORACLE_HOME/bin/lsnrctl start
    $ORACLE_HOME/bin/dbca -silent -createDatabase -responseFile ${ORADBA_RESPONSE} 

    # remove passwords from response file
    sed -i -e "s|${ORACLE_PWD}|ORACLE_PASSWORD|g" ${ORADBA_RESPONSE}

    # Create TNS Names entry
    if [ $( grep -ic $ORACLE_SID ${TNS_ADMIN}/tnsnames.ora) -eq 0 ]; then
        echo "INFO: Add $ORACLE_SID to ${TNS_ADMIN}/tnsnames.ora."
        echo "${ORACLE_SID}.${DOMAIN}=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${HOST})(PORT=${ORACLE_PORT}))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${ORACLE_SID}.${DOMAIN}))(UR=A))">>${TNS_ADMIN}/tnsnames.ora
    else
        echo "INFO: TNS name entry ${ORACLE_SID} does exists."
    fi

    # Remove second control file, fix local_listener, make PDB auto open
    $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
        ALTER SYSTEM SET local_listener='';
        ALTER SYSTEM SET db_unique_name=$ORACLE_DB_UNIQUE_NAME scope=spfile;
        STARTUP FORCE;
        exit;
EOF

    echo "INFO: Create DB environment for ${ORACLE_SID} ---------------------"
    ${ORADBA_BIN}/${DB_ENV_SCRIPT} ${ORACLE_SID}

    # Execute custom provided setup scripts
    ${ORADBA_BIN}/${DB_CONFIG_SCRIPT} ${INSTANCE_INIT}/setup

    # update oratab
    if [ $(grep -c "^${ORACLE_SID}" $ORATAB) -gt 0 ]; then
        echo "INFO: Update ${ORACLE_SID} in oratab $ORATAB"
        sed -i "s|^${ORACLE_SID}.*|${ORACLE_SID}:${ORACLE_HOME}:Y|" $ORATAB
    else
        echo "INFO: Add ${ORACLE_SID} to oratab $ORATAB"
        echo "${ORACLE_SID}:${ORACLE_HOME}:Y" >>$ORATAB
    fi
else
    echo "INFO: Create ${ORACLE_SID} using DB Master ${DB_MASTER}"
    # create DB using rman duplicate
    ${ORADBA_BIN}/${DB_CLONE_SCRIPT} ${ORACLE_SID} ${DB_MASTER}
fi

# adjust basenv
MY_ORACLE_SID=${ORACLE_SID}
# set environment BasEnv and database
if [ -f "$HOME/.BE_HOME" ]; then
    echo "INFO: source TVD-BasEnv"
    . $HOME/.BE_HOME
    . ${BE_HOME}/bin/basenv.ksh
    . ${BE_HOME}/bin/oraenv.ksh ${MY_ORACLE_SID}    # source SID environment
else   
    echo "INFO: skip TVD-BasEnv"
fi


# --- EOF -------------------------------------------------------------------