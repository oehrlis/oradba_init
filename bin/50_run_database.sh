#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 50_run_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Helper script to start the Oracle database
# Notes......: Script to create an Oracle database. If configuration files are
#              provided, the will be used to configure the instance.
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

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder

# ---------------------------------------------------------------------------
# Default name for OUD instance
export ORACLE_SID=${ORACLE_SID:-TDB183C}                    # Default for ORACLE SID
export ORACLE_PDB=${ORACLE_PDB:-PDB1}                       # Default for ORACLE PDB
export ORACLE_CHARACTERSET=${ORACLE_CHARACTERSET:-AL32UTF8} # Default for ORACLE CHARACTERSET
export CONTAINER=${CONTAINER:-"false"}                      # Check whether CONTAINER is passed on

# Oracle Software, Patchs and common environment variables
export ORACLE_ROOT=${ORACLE_ROOT:-/u00}
export ORACLE_DATA=${ORACLE_DATA:-/u01}
export ORACLE_BASE=${ORACLE_BASE:-${ORACLE_ROOT}/app/oracle}
export ORACLE_LOCAL=${ORACLE_LOCAL:-${ORACLE_BASE}/local}
export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}
# - EOF Environment Variables -----------------------------------------------

# - Functions -----------------------------------------------------------

# -----------------------------------------------------------------------
function move_directories {
# Purpose....: Move config directories
# -----------------------------------------------------------------------
    # check if admin directory is a softlink if not move it and create one
    if [ ! -L ${ORACLE_BASE}/admin ] && [ ! -d ${ORACLE_DATA}/admin ]; then
        mv ${ORACLE_BASE}/admin ${ORACLE_DATA}
        ln -s ${ORACLE_DATA}/admin ${ORACLE_BASE}/admin
    # if admin exists on /u01 just create a softlink
    elif [ ! -L ${ORACLE_BASE}/admin ] && [ -d ${ORACLE_DATA}/admin ]; then
        mv ${ORACLE_BASE}/admin ${ORACLE_BASE}/admin_container
        ln -s ${ORACLE_DATA}/admin ${ORACLE_BASE}/admin
    fi

    # check if diag directory is a softlink if not move it and create one
    if [ ! -L ${ORACLE_BASE}/diag ] && [ ! -d ${ORACLE_DATA}/diag ]; then
        mv ${ORACLE_BASE}/diag ${ORACLE_DATA}
        ln -s ${ORACLE_DATA}/diag ${ORACLE_BASE}/diag
    # if diag exists on /u01 just create a softlink
    elif [ ! -L ${ORACLE_BASE}/diag ] && [ -d ${ORACLE_DATA}/diag ]; then
        rm -rf ${ORACLE_BASE}/diag
        ln -s ${ORACLE_DATA}/diag ${ORACLE_BASE}/diag
    fi

    # check if etc directory is a softlink if not move it and create one
    if [ ! -L ${ORACLE_BASE}/etc ] && [ ! -d ${ORACLE_DATA}/etc ]; then
        mv ${ORACLE_BASE}/etc ${ORACLE_DATA}
        ln -s ${ORACLE_DATA}/etc ${ORACLE_BASE}/etc
    # if etc exists on /u01 just create a softlink
    elif [ ! -L ${ORACLE_BASE}/etc ] && [ -d ${ORACLE_DATA}/etc ]; then
        mv ${ORACLE_BASE}/etc/* ${ORACLE_DATA}/etc
        rm -rf ${ORACLE_BASE}/etc
        ln -s ${ORACLE_DATA}/etc ${ORACLE_BASE}/etc
    fi

    # check if network directory is a softlink if not move it and create one
    if [ ! -L ${ORACLE_BASE}/network ] && [ ! -d ${ORACLE_DATA}/network ]; then
        mv ${ORACLE_BASE}/network ${ORACLE_DATA}
        ln -s ${ORACLE_DATA}/network ${ORACLE_BASE}/network
    # if diag exists on /u01 just create a softlink
    elif [ ! -L ${ORACLE_BASE}/network ] && [ -d ${ORACLE_DATA}/network ]; then
        rm -rf ${ORACLE_BASE}/network
        ln -s ${ORACLE_DATA}/network ${ORACLE_BASE}/network
    fi
}

# -----------------------------------------------------------------------
function move_files {
# Purpose....: Move DB files
# -----------------------------------------------------------------------
    
    # create admin directory on volume
    if [ ! -d ${ORACLE_DATA}/admin/${ORACLE_SID} ]; then
        mkdir -p ${ORACLE_DATA}/admin/${ORACLE_SID}
    fi

    # create network directory on volume
    if [ ! -d ${ORACLE_DATA}/network ]; then
        mkdir -p ${ORACLE_DATA}/network
    fi

    # create etc directory on volume
    if [ ! -d ${ORACLE_DATA}/etc ]; then
        mkdir -p ${ORACLE_DATA}/etc
    fi

    # move db config files
    mv ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/
    mv ${ORACLE_HOME}/dbs/orapw${ORACLE_SID} ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/

    # move network config files
    for i in sqlnet.ora listener.ora ldap.ora tnsnames.ora; do
        ln -s ${ORACLE_HOME}/network/admin/${i} ${TNS_ADMIN}/${i}
    done
    mv ${ORACLE_HOME}/ldap/admin/dsi.ora ${TNS_ADMIN}/dsi.ora

    # move toolbox config files
    for i in basenv.conf orahometab sidtab sid.*.conf; do
        mv ${ORACLE_LOCAL}/dba/etc/${i} ${ORACLE_DATA}/etc/${i}
    done

    # oracle user does not have permissions in /etc, hence cp and not mv
    mv ${ORACLE_BASE}/etc/oratab ${ORACLE_DATA}/etc/oratab
    
    # create softlinks
    sym_link_files;
}

# -----------------------------------------------------------------------
function sym_link_files {
# Purpose....: Symbolic link DB files
# -----------------------------------------------------------------------

    # create softlinks for db config files
    if [ ! -L ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora ]; then
        ln -s ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/spfile${ORACLE_SID}.ora ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora
    fi
    if [ ! -L ${ORACLE_HOME}/dbs/orapw${ORACLE_SID} ]; then
        ln -s ${ORACLE_DATA}/admin/${ORACLE_SID}/pfile/orapw${ORACLE_SID} ${ORACLE_HOME}/dbs/orapw${ORACLE_SID}
    fi

    # create softlinks for network configuration
    for i in sqlnet.ora listener.ora ldap.ora tnsnames.ora; do
        if [ ! -L ${ORACLE_HOME}/network/admin/${i} ]; then
            ln -s ${TNS_ADMIN}/${i} ${ORACLE_HOME}/network/admin/${i}
        fi
    done
    if [ ! -L ${ORACLE_HOME}/ldap/admin/dsi.ora ]; then
        ln -s ${TNS_ADMIN}/dsi.ora ${ORACLE_HOME}/ldap/admin/dsi.ora
    fi

    # create softlinks for toolbox configuration
    for i in basenv.conf orahometab sidtab sid.*.conf; do
        if [ ! -L ${ORACLE_LOCAL}/dba/etc/${i} ]; then
            ln -s ${ORACLE_DATA}/etc/${i} ${ORACLE_LOCAL}/dba/etc/${i}
        fi
    done
    if [ ! -L ${ORACLE_BASE}/etc/oratab ]; then
        ln -s ${ORACLE_DATA}/etc/oratab ${ORACLE_BASE}/etc/oratab
    fi
}
# - EOF Functions -------------------------------------------------------

# ---------------------------------------------------------------------------
# SIGINT handler
# ---------------------------------------------------------------------------
function int_db() {
    echo "---------------------------------------------------------------"
    echo "Stopping container."
    echo "SIGINT received, shutting down database ${ORACLE_SID}!"
    echo "---------------------------------------------------------------"
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
    echo "---------------------------------------------------------------"
    echo "Stopping container."
    echo "SIGTERM received, shutting down database ${ORACLE_SID}!"
    echo "---------------------------------------------------------------"
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
    echo "---------------------------------------------------------------"
    echo "SIGKILL received, shutting down database ${ORACLE_SID}!"
    echo "---------------------------------------------------------------"
    sqlplus / as sysdba <<EOF
    shutdown abort;
    exit;
EOF
    lsnrctl stop
}

# - Initialization ------------------------------------------------------
# Check whether container has enough memory
# Github issue #219: Prevent integer overflow,
# only check if memory digits are less than 11 (single GB range and below) 
if [ `cat /sys/fs/cgroup/memory/memory.limit_in_bytes | wc -c` -lt 11 ]; then
   if [ `cat /sys/fs/cgroup/memory/memory.limit_in_bytes` -lt 2147483648 ]; then
      echo "Error: The container doesn't have enough memory allocated."
      echo "A database container needs at least 2 GB of memory."
      echo "You currently only have $((`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`/1024/1024/1024)) GB allocated to the container."
      exit 1
   fi
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
    echo "Error: The ORACLE_SID must only be up to 12 characters long."
    exit 1
fi

# Check whether SID is alphanumeric
# Github issue #246: Cannot start OracleDB image
if [[ "$ORACLE_SID" =~ [^a-zA-Z0-9] ]]; then
    echo "Error: The ORACLE_SID must be alphanumeric."
    exit 1
fi

# Check whether database already exists
if [ -d ${ORACLE_DATA}/oradata/${ORACLE_SID} ]; then
    move_directories
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

    # Execute custom provided setup scripts
    ${ORADBA_BIN}/${CONFIG_SCRIPT} ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/setup
fi

# Check whether database is up and running
${ORADBA_BIN}/${CHECK_SCRIPT}
if [ $? -eq 0 ]; then
    echo "---------------------------------------------------------------"
    echo " - DATABASE ${ORACLE_SID} IS READY TO USE!"
    echo "---------------------------------------------------------------"
    # Execute custom provided startup scripts
    ${ORADBA_BIN}/${CONFIG_SCRIPT} ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/startup
else
    echo "---------------------------------------------------------------"
    echo " - DATABASE SETUP FOR ${ORACLE_SID} WAS NOT SUCCESSFUL:"
    echo " - Please check output for further info!"
    echo "---------------------------------------------------------------"
fi;

# Tail on alert log and wait (otherwise container will exit)
echo "---------------------------------------------------------------"
echo "   Tail output of alert log from ${ORACLE_SID}:"
echo "---------------------------------------------------------------"
echo "The following output is now a tail of the alert.log:"
tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID
# --- EOF -------------------------------------------------------------------