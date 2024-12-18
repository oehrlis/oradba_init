#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Data Platforms
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 50_run_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Helper script to start the Oracle database
# Notes......: Script to create an Oracle database. If configuration files are
#              provided, the will be used to configure the instance.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...: 
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------

# - Script Variables --------------------------------------------------------
# - Set script names for miscellaneous start, check and config scripts.
# ---------------------------------------------------------------------------
# Default name for OUD instance
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder
export START_SCRIPT=${START_SCRIPT:-"51_start_database.sh"}
export CREATE_SCRIPT=${CREATE_SCRIPT:-"52_create_database.sh"}
export CONFIG_SCRIPT=${CONFIG_SCRIPT:-"53_config_database.sh"}
export CHECK_SCRIPT=${CHECK_SCRIPT:-"54_check_database.sh"}
# - EOF Script Variables ----------------------------------------------------

# ---------------------------------------------------------------------------
# Default name for OUD instance
export ORACLE_SID=${ORACLE_SID:-TDB183C}                    # Default for ORACLE SID
export ORADBA_TEMPLATE_PREFIX=${ORADBA_TEMPLATE_PREFIX:-""}
export ORACLE_PDB=${ORACLE_PDB:-PDB1}                       # Default for ORACLE PDB
export ORACLE_CHARACTERSET=${ORACLE_CHARACTERSET:-AL32UTF8} # Default for ORACLE CHARACTERSET
export CONTAINER=${CONTAINER:-"false"}                      # Check whether CONTAINER is passed on

# Oracle Software, Patchs and common environment variables
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}

export INSTANCE_INIT=${INSTANCE_INIT:-"${ORACLE_BASE}/admin/${ORACLE_SID}/scripts"}
# - EOF Environment Variables -----------------------------------------------

# - Functions -----------------------------------------------------------

# -----------------------------------------------------------------------
function move_directories {
# Purpose....: Move config directories
    # -----------------------------------------------------------------------
    echo " ---------------------------------------------------------------"
    echo " - move directories with persistent data in ${ORACLE_BASE} to docker volume (${ORACLE_DATA})"

    # remove homes from the list
    # for i in dbs audit homes admin diag etc network; do
    for i in dbs audit admin diag etc network; do
        # check if directory is a softlink if not move it and create one
        if [ ! -L ${ORACLE_BASE}/${i} ] && [ -d ${ORACLE_BASE}/${i} ] && [ ! -d ${ORACLE_DATA}/${i} ]; then
            echo " - move ${ORACLE_BASE}/${i} to ${ORACLE_BASE}/${i}"
            mv -v ${ORACLE_BASE}/${i} ${ORACLE_DATA}
            echo " - - create softlink for ${ORACLE_BASE}/${i}"
            ln -s -v ${ORACLE_DATA}/${i} ${ORACLE_BASE}/${i}
            # if directory exists on /u01 just create a softlink
        elif [ ! -L ${ORACLE_BASE}/${i} ] && [ -d ${ORACLE_BASE}/${i} ] && [ -d ${ORACLE_DATA}/${i} ]; then
            rm -rf ${ORACLE_BASE}/${i}
            echo " - - re-create softlink for ${ORACLE_BASE}/${i}"
            ln -s -v ${ORACLE_DATA}/${i} ${ORACLE_BASE}/${i}
        fi
    done
    echo " ----------------------------------------------------------------"
}

# -----------------------------------------------------------------------
function move_files {
# Purpose....: Move DB files
# -----------------------------------------------------------------------
    echo " ----------------------------------------------------------------"
    echo " - - move files with persistent data to docker volume (${ORACLE_DATA})"
    # create admin directory on volume
    if [ ! -d ${ORACLE_DATA}/admin/${ORACLE_SID} ]; then
        mkdir -v -p ${ORACLE_DATA}/admin/${ORACLE_SID}
        mkdir -v -p ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile
    fi

    # create audit directory on volume
    if [ ! -d ${ORACLE_DATA}/audit ]; then
        mkdir -v -p ${ORACLE_DATA}/audit
    fi

    # move init.ora, spfile and password file to volume
    for i in spfile${ORACLE_SID}.ora init${ORACLE_SID}.ora orapw${ORACLE_SID}; do
        if [ -f ${ORACLE_HOME}/dbs/${i} ]  && [ ! -f ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/${i} ]; then
            mv -v ${ORACLE_HOME}/dbs/${i} ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/${i}
        fi
    done

    # create network directory on volume
    if [ ! -d ${ORACLE_DATA}/network ]; then
        mkdir -v -p ${ORACLE_DATA}/network
    fi

    for i in sqlnet.ora listener.ora ldap.ora tnsnames.ora; do
        if [ -f ${ORACLE_HOME}/network/admin/${i} ]  && [ ! -f ${TNS_ADMIN}/${i} ]; then
            mv -v ${ORACLE_HOME}/network/admin/${i} ${TNS_ADMIN}/${i}
        fi
    done

    if [ -f ${ORACLE_HOME}/ldap/admin/dsi.ora ] && [ ! -f ${TNS_ADMIN}/dsi.ora ]; then
        mv -v ${ORACLE_HOME}/ldap/admin/dsi.ora ${TNS_ADMIN}/dsi.ora
    fi

    # create etc directory on volume
    if [ ! -d ${ORACLE_DATA}/etc ]; then
        mkdir -v -p ${ORACLE_DATA}/etc
    fi

    # move toolbox config files
    cd ${ORACLE_LOCAL}/dba/etc/
    for i in basenv.conf orahometab sidtab sid.${ORACLE_SID}.conf sid._DEFAULT_.conf; do
        if [ -f ${ORACLE_LOCAL}/dba/etc/${i} ] && [ ! -f ${ORACLE_DATA}/etc/${i} ]; then
            mv -v ${ORACLE_LOCAL}/dba/etc/${i} ${ORACLE_DATA}/etc/${i}
        fi
    done
    cd -
    echo " ---------------------------------------------------------------"
    # create softlinks
    sym_link_files;
}

# -----------------------------------------------------------------------
function sym_link_files {
# Purpose....: Symbolic link DB files
# -----------------------------------------------------------------------
    echo " ---------------------------------------------------------------"
    echo " - create softlinks for config files"
    # check if we have a dbs in  ${ORACLE_BASE}
    echo " - create softlinks for \${ORACLE_HOME}/dbs files"
    # check if we do have orabasehome and if read/write or read-only Oracle home
    if [ -z $(command -v ${ORACLE_HOME}/bin/orabasehome) ] || [ $(${ORACLE_HOME}/bin/orabasehome) == "${ORACLE_HOME}" ]; then 
        echo " - using read/write Oracle home. Create softlinks in \${ORACLE_HOME}/dbs."
        for i in spfile${ORACLE_SID}.ora init${ORACLE_SID}.ora orapw${ORACLE_SID}; do
            if [ ! -L ${ORACLE_HOME}/dbs/${i} ] && [ -f ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/${i} ]; then
                ln -s -v ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/${i} ${ORACLE_HOME}/dbs/${i}
            fi
        done
    else 
        echo " - using read-only Oracle home. No softlinks will be created."
    fi

    # create softlinks for network configuration
    echo " - create softlinks for network configuration in \${ORACLE_HOME}/network/admin"
    for i in sqlnet.ora listener.ora ldap.ora tnsnames.ora; do
        if [ ! -L ${ORACLE_HOME}/network/admin/${i} ] && [ -f ${TNS_ADMIN}/${i} ]; then
            ln -s -v ${TNS_ADMIN}/${i} ${ORACLE_HOME}/network/admin/${i}
        fi
    done
    if [ ! -L ${ORACLE_HOME}/ldap/admin/dsi.ora ] && [ -f ${TNS_ADMIN}/dsi.ora ]; then
        ln -s -v ${TNS_ADMIN}/dsi.ora ${ORACLE_HOME}/ldap/admin/dsi.ora
    fi
    
    # create softlinks for toolbox configuration
    echo " - create softlinks for toolbox configuration in \${ORACLE_LOCAL}/dba/etc/"
    cd ${ORACLE_LOCAL}/dba/etc/
    for i in basenv.conf orahometab sidtab sid.${ORACLE_SID}.conf sid._DEFAULT_.conf; do
        if [ ! -L ${ORACLE_LOCAL}/dba/etc/${i} ] && [ -f ${ORACLE_DATA}/etc/${i} ] ; then
            ln -s -v -f ${ORACLE_DATA}/etc/${i} ${ORACLE_LOCAL}/dba/etc/${i}
        fi
    done
    cd -
    echo " ---------------------------------------------------------------"
}
# - EOF Functions -------------------------------------------------------

# ---------------------------------------------------------------------------
# SIGINT handler
# ---------------------------------------------------------------------------
function int_db() {
    echo " ---------------------------------------------------------------"
    echo " - Stopping container."
    echo " - SIGINT received, shutting down database ${ORACLE_SID}!"
    echo " ---------------------------------------------------------------"
    sqlplus / as sysdba <<EOF
    shutdown immediate;
    exit;
EOF
    lsnrctl stop
}

# ---------------------------------------------------------------------------
# SIGTERM handler
# ---------------------------------------------------------------------------
function term_db() {
    echo " ---------------------------------------------------------------"
    echo " - Stopping container."
    echo " - SIGTERM received, shutting down database ${ORACLE_SID}!"
    echo " ---------------------------------------------------------------"
    sqlplus / as sysdba <<EOF
    shutdown immediate;
    exit;
EOF
    lsnrctl stop
}

# ---------------------------------------------------------------------------
# SIGKILL handler
# ---------------------------------------------------------------------------
function kill_db() {
    echo " ---------------------------------------------------------------"
    echo " - SIGKILL received, shutting down database ${ORACLE_SID}!"
    echo " ---------------------------------------------------------------"
    sqlplus / as sysdba <<EOF
    shutdown abort;
    exit;
EOF
    lsnrctl stop
}

# - Initialization -------------------------------------------------------------
# Check whether container has enough memory
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
   memory=$(cat /sys/fs/cgroup/memory.max)
else
   memory=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
fi

# Github issue #219: Prevent integer overflow,
# only check if memory digits are less than 11 (single GB range and below)
if [[ ${memory} != "max" && ${#memory} -lt 11 && ${memory} -lt 2147483648 ]]; then
   echo "Error: The container doesn't have enough memory allocated."
   echo "A database container needs at least 2 GB of memory."
   echo "You currently only have $((memory/1024/1024)) MB allocated to the container."
   exit 1;
fi

# Set SIGINT handler
trap int_db SIGINT

# Set SIGTERM handler
trap term_db SIGTERM

# Set SIGKILL handler
trap kill_db SIGKILL
# - EOF Initialization --------------------------------------------------

# - Main ----------------------------------------------------------------
# Check whether SID is no longer than 12 bytes
# Github issue #246: Cannot start OracleDB image
if [ "${#ORACLE_SID}" -gt 12 ]; then
    echo " - ERROR: The ORACLE_SID must only be up to 12 characters long."
    exit 1
fi

# Check whether SID is alphanumeric
# Github issue #246: Cannot start OracleDB image
if [[ "$ORACLE_SID" =~ [^a-zA-Z0-9] ]]; then
    echo " - ERROR: The ORACLE_SID must be alphanumeric."
    exit 1
fi

# Check whether database already exists
if [ -d ${ORACLE_DATA}/oradata/${ORACLE_SID} ]; then
    move_directories
    move_files
    sym_link_files;

    # Make sure audit file destination exists
    if [ ! -d ${ORACLE_BASE}/admin/${ORACLE_SID}/adump ]; then
        mkdir -p ${ORACLE_BASE}/admin/${ORACLE_SID}/adump
    fi
   
    # Start database 
    ${ORADBA_BIN}/${START_SCRIPT}
else
    # Remove database config files, if they exist
    rm -f ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora
    rm -f ${ORACLE_HOME}/dbs/orapw${ORACLE_SID}
    rm -f ${ORACLE_HOME}/network/admin/sqlnet.ora
    rm -f ${ORACLE_HOME}/network/admin/listener.ora
    rm -f ${ORACLE_HOME}/network/admin/tnsnames.ora

    # check and move config directories
    move_directories

    # Create database 
    ${ORADBA_BIN}/${CREATE_SCRIPT} ${ORACLE_SID} ${ORACLE_PDB} ${CONTAINER}
    
    # Move database operational files to oradata
    move_files
fi

# set instant init location create folder if it does exists
if [ ! -d "${INSTANCE_INIT}/startup" ]; then
    INSTANCE_INIT="${ORACLE_BASE}/admin/${ORACLE_SID}/scripts"
fi

# check if we have an oratab entry
if [ $(grep -ic ${ORACLE_SID} /etc/oratab) -eq 0 ]; then
    echo "${ORACLE_SID}:${ORACLE_HOME}:Y" >/etc/oratab
fi

# Check whether database is up and running
${ORADBA_BIN}/${CHECK_SCRIPT}

if [ $? -eq 0 ]; then
    echo " ---------------------------------------------------------------"
    echo " - DATABASE ${ORACLE_SID} IS READY TO USE!"
    echo " ---------------------------------------------------------------"
    # Execute custom provided startup scripts
    ${ORADBA_BIN}/${CONFIG_SCRIPT} ${INSTANCE_INIT}/startup
else
    echo " ---------------------------------------------------------------"
    echo " - DATABASE SETUP FOR ${ORACLE_SID} WAS NOT SUCCESSFUL:"
    echo " - Please check output for further info!"
    echo " ---------------------------------------------------------------"
fi;

# Tail on alert log and wait (otherwise container will exit)
echo "---------------------------------------------------------------"
echo " - Tail output of alert log from ${ORACLE_SID}:"
echo "---------------------------------------------------------------"
echo " - The following output is now a tail of the alert.log:"
tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID
# --- EOF -------------------------------------------------------------------