#!/bin/bash
# -----------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Transactional Data Platform
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# -----------------------------------------------------------------------------
# Name.......: 56_clone_database.sh
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
LOCAL_DB_MASTER=${2:-"SDBM_master.tgz"}     # DB Master file
LOCAL_DB_MASTER_NAME=${3:-$(basename $LOCAL_DB_MASTER .tgz|cut -d_ -f 2)}
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
echo "ORADBA_BIN $ORADBA_BIN"

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

# Check if parameter is not empty
if [ -z "${LOCAL_ORACLE_SID}" ] ; then
    CleanAndQuit 20
fi

# - Main ----------------------------------------------------------------------
echo "INFO: Start to clone DB environment for SID ${LOCAL_ORACLE_SID} on ${HOST} at $(date)"
echo "INFO: Check for read only home ------------------------------------------"
if [ $($ORACLE_HOME/bin/orabasehome) == "$ORACLE_HOME" ]; then 
    echo "INFO: Regular Oracle home -----------------------------------------------"
    ORACLE_DBS=$ORACLE_HOME/dbs; 
else
    echo "INFO: read only Oracle home ---------------------------------------------"
    ORACLE_DBS=$ORACLE_BASE/dbs;
fi

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
    # set some variables
    typeset -l ORACLE_SID_lowercase=${ORACLE_SID}
    BE_ORA_ADMIN_SID=${BE_ORA_ADMIN_SID:-${ORACLE_BASE}/admin/${ORACLE_SID}}
    # cleanup/remove the admin files
    rm -rf ${BE_ORA_ADMIN_SID}/arch/*
    rm -rf ${BE_ORA_ADMIN_SID}/backup/*
    rm -rf ${BE_ORA_ADMIN_SID}/dpdump/*
    rm -rf ${BE_ORA_ADMIN_SID}/adump/*
    rm -rf ${BE_ORA_ADMIN_SID}/pfile/*
    rm -rf ${BE_ORA_ADMIN_SID}/etc/*
    rm -rf ${BE_ORA_ADMIN_SID}/log/*

    # cleanup/remove the files - diag, fast_recovery_area and startup init${SID}.ora
    rm -rf ${ORACLE_BASE}/diag/rdbms/${ORACLE_SID_lowercase}/${ORACLE_SID}
    rm -rf ${ORACLE_BASE}/audit/${ORACLE_SID}
    rm -rf ${ORACLE_DBS}/*${ORACLE_SID}*
    rm -rf /u??/fast_recovery_area/${ORACLE_SID}/*

    # cleanup/remove the data files
    rm -rf /u??/oradata/${ORACLE_SID}/*
fi

# Create New DB Environment
echo "INFO: Create DB environment for ${LOCAL_ORACLE_SID} ---------------------"
${ORADBA_BIN}/${DB_ENV_SCRIPT} ${LOCAL_ORACLE_SID}
BE_ORA_ADMIN_SID=${BE_ORA_ADMIN_SID:-${ORACLE_BASE}/admin/${ORACLE_SID}}
# set database environment 
if [ -f "$HOME/.BE_HOME" ]; then
    . $HOME/.BE_HOME
    . ${BE_HOME}/bin/basenv.ksh
    . ${BE_HOME}/bin/oraenv.ksh ${LOCAL_ORACLE_SID}           # source SID environment
else 
    ORACLE_SID=${LOCAL_ORACLE_SID}
fi

echo "INFO: Prepare DB master $LOCAL_DB_MASTER --------------------------------"
# get DB master
case $LOCAL_DB_MASTER in
  /*) DB_MASTER=${LOCAL_DB_MASTER} ;;
  *)  DB_MASTER=${SOFTWARE}/${LOCAL_DB_MASTER} ;;
esac

# extract DB_MASTER_NAME from Master file
DB_MASTER_NAME=${LOCAL_DB_MASTER_NAME:-$(basename $LOCAL_DB_MASTER .tgz|cut -d_ -f 2)}

# check and create directory
if [ ! -d "${ORACLE_ARCH}/backup/" ]; then
    mkdir -p ${ORACLE_ARCH}/backup/ >/dev/null 2>&1 || CleanAndQuit 12 ${ORACLE_ARCH}/backup/
elif [ ! -w "${ORACLE_ARCH}/backup/" ]; then
    CleanAndQuit 13 ${ORACLE_ARCH}/backup/
fi

# unpack DB master
tar zxvf ${DB_MASTER} -C ${ORACLE_ARCH}/backup/

# define MASTER ORACLE_ROOT
export MASTER_ORACLE_ROOT=$(grep -i oracle_base ${ORACLE_ARCH}/backup/${DB_MASTER_NAME}/init_${DB_MASTER_NAME}.ora|sed "s/.*'\(\/u..\)\/.*'.*/\1/")
export MASTER_ORACLE_ROOT=${MASTER_ORACLE_ROOT:-"/u00"}

echo "INFO: Prepare password file ---------------------------------------------"
# Prepare password file
if [ -f "${ORACLE_ARCH}/backup/orapw${DB_MASTER_NAME}" ]; then
    echo "INFO: use existing password file ${ORACLE_ARCH}/backup/orapw${DB_MASTER_NAME}"
    cp ${ORACLE_ARCH}/backup/orapw${DB_MASTER_NAME} ${BE_ORA_ADMIN_SID}/pfile/orapw${ORACLE_SID}
    ln -s ${BE_ORA_ADMIN_SID}/pfile/orapw${ORACLE_SID} ${ORACLE_DBS}/orapw${ORACLE_SID}
else
    echo "INFO: generate new password file ${BE_ORA_ADMIN_SID}/pfile/orapw${ORACLE_SID}"
    # generate password if it is still empty
    if [ -z ${ORACLE_PWD} ]; then
        echo "INFO: generate password"
        ORACLE_PWD=$(gen_password 12| sed 's/./&-/4')
    fi 
    mkdir -p "${BE_ORA_ADMIN_SID}/etc"
    echo "${ORACLE_PWD}" > "${BE_ORA_ADMIN_SID}/etc/${ORACLE_SID}_password.txt"
    orapwd force=y password=${ORACLE_PWD} file=${BE_ORA_ADMIN_SID}/pfile/orapw${ORACLE_SID}
    ln -s ${BE_ORA_ADMIN_SID}/pfile/orapw${ORACLE_SID} ${ORACLE_DBS}/orapw${ORACLE_SID}
fi

echo "INFO: Perpare init.ora file (${BE_ORA_ADMIN_SID}/pfile/init$ORACLE_SID.ora) "
# Perpare init.ora file
sed -e "s/${DB_MASTER_NAME}/$ORACLE_SID/g" \
    ${ORACLE_ARCH}/backup/${DB_MASTER_NAME}/init_${DB_MASTER_NAME}.ora \
    >${BE_ORA_ADMIN_SID}/pfile/init$ORACLE_SID.ora

# adjust init.ora file
sed -i -n -E -e '/^\*\.(control_files=|db_recovery_file_dest=|.*_file_name_convert=|.*audit_file_dest=|.*diagnostic_dest=)/!p' \
    -e "\$a\*\.control_files='$ORACLE_DATA/oradata/$ORACLE_SID/control01$ORACLE_SID.dbf','$ORACLE_ARCH/oradata/$ORACLE_SID/control02$ORACLE_SID.dbf'" \
    -e "\$a\*\.db_recovery_file_dest='$ORACLE_ARCH/fast_recovery_area'" \
    -e "\$a\*\.audit_file_dest='$BE_ORA_ADMIN_SID/adump'" \
    -e "\$a\*\.diagnostic_dest='$ORACLE_BASE'" \
    -e "\$a\*\.db_file_name_convert='$DB_MASTER_NAME','$ORACLE_SID'" \
    -e "\$a\*\.pdb_file_name_convert='$DB_MASTER_NAME','$ORACLE_SID'" \
    -e "\$a\*\.log_file_name_convert='$DB_MASTER_NAME','$ORACLE_SID'" ${BE_ORA_ADMIN_SID}/pfile/init$ORACLE_SID.ora
    
echo "INFO: Create spfile ($BE_ORA_ADMIN_SID/pfile/spfile$ORACLE_SID.ora) -----"
# create spfile
$ORACLE_HOME/bin/sqlplus / as sysdba <<EOF
create spfile='$BE_ORA_ADMIN_SID/pfile/spfile$ORACLE_SID.ora' from pfile='$BE_ORA_ADMIN_SID/pfile/init$ORACLE_SID.ora';
host echo spfile=$BE_ORA_ADMIN_SID/pfile/spfile$ORACLE_SID.ora >$ORACLE_DBS/init$ORACLE_SID.ora
startup nomount;
exit;
EOF

echo "INFO: Clone Database from $DB_MASTER_NAME to $ORACLE_SID ----------------"
if [ "${ORACLE_ROOT}" == "${MASTER_ORACLE_ROOT}" ]; then
    # clone database
    $ORACLE_HOME/bin/rman <<EOF
connect auxiliary /
run {
duplicate database '$DB_MASTER_NAME' to '$ORACLE_SID'
backup location '${ORACLE_ARCH}/backup/$DB_MASTER_NAME' NOFILENAMECHECK;
}
EOF
else
    # clone database
    $ORACLE_HOME/bin/rman <<EOF
connect auxiliary /
run {
duplicate database '$DB_MASTER_NAME' to '$ORACLE_SID'
backup location '${ORACLE_ARCH}/backup/$DB_MASTER_NAME' NOFILENAMECHECK
    LOGFILE
      GROUP 1 ('$ORACLE_ROOT/oradata/$ORACLE_SID/redog1m1$ORACLE_SID.dbf', 
               '$ORACLE_DATA/oradata/$ORACLE_SID/redog1m2$ORACLE_SID.dbf') SIZE 200M REUSE, 
      GROUP 2 ('$ORACLE_ROOT/oradata/$ORACLE_SID/redog2m1$ORACLE_SID.dbf', 
               '$ORACLE_DATA/oradata/$ORACLE_SID/redog2m2$ORACLE_SID.dbf') SIZE 200M REUSE, 
      GROUP 3 ('$ORACLE_ROOT/oradata/$ORACLE_SID/redog3m1$ORACLE_SID.dbf', 
               '$ORACLE_DATA/oradata/$ORACLE_SID/redog3m2$ORACLE_SID.dbf') SIZE 200M REUSE;
}
EOF
fi

# config rman.conf file
echo "target=/"                  >  ${BE_ORA_ADMIN_SID}/etc/rman.conf
echo "catalog=rman/rman@catalog" >> ${BE_ORA_ADMIN_SID}/etc/rman.conf

cat << EOF >${BE_ORA_ADMIN_SID}/etc/rman.conf
target=/
catalog=rman/rman@catalog
CF_ChannelType="disk"
CF_ChannelNo=2
CF_Compress=1
CF_BckPathParm="${ORACLE_ARCH}/backup/$ORACLE_SID"
CF_MailIfOk=2
EOF

# remove backup files after restore
rm -rf ${ORACLE_ARCH}/backup/$DB_MASTER_NAME

echo "INFO: Configure $ORACLE_SID ---------------------------------------------"
# Execute custom provided setup scripts
${ORADBA_BIN}/${DB_CONFIG_SCRIPT} ${INSTANCE_INIT}/setup

echo "INFO: Finish creating the DB environment on $(hostname) at $(date)"
# --- EOF ---------------------------------------------------------------------
