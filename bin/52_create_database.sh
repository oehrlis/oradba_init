#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 52_create_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Helper script to create the Oracle database
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
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------
export ORACLE_SID=${1:-TDB183C}                 # Default name for Oracle database
export ORACLE_PDB=${2:-PDB1}                    # Check whether ORACLE_PDB is passed on
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}       # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}       # Oracle data folder eg volume for docker
export ORACLE_ARCH=${ORACLE_DATA:-"/u01"}       # Oracle arch folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"18.3.0.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"

export CONTAINER=${3:-"false"}                  # Check whether CONTAINER is passed on
# define oradba specific variables
export ORADBA_BIN="${ORADBA_INIT}"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder
export ORADBA_RSP_FILE=${ORADBA_RSP_FILE:-"dbca18.0.0.rsp.tmpl"} # oradba init response file
export ORADBA_DBC_FILE=${ORADBA_DBC_FILE:-"dbca18.0.0.dbc.tmpl"}
export TEMPLATE=$(basename $ORADBA_DBC_FILE .tmpl)
export ORACLE_PWD=${ORACLE_PWD:-""}             # Default admin password

HOSTNAME_BIN=$(command -v hostname)                             # get the binary for hostname
HOSTNAME_BIN=${HOSTNAME_BIN:-"cat /proc/sys/kernel/hostname"}   # fallback to /proc/sys/kernel/hostname
export HOST=$(${HOSTNAME_BIN})

export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}
# - EOF Environment Variables -------------------------------------------

# generate a password
if [ -z ${ORACLE_PWD} ]; then
    # Auto generate Oracle WebLogic Server admin password
    while true; do
        s=$(cat /dev/urandom | tr -dc "A-Za-z0-9" | fold -w 10 | head -n 1)
        if [[ ${#s} -ge 10 && "$s" == *[A-Z]* && "$s" == *[a-z]* && "$s" == *[0-9]*  ]]; then
            break
        else
            echo "Password does not Match the criteria, re-generating..."
        fi
    done
    echo "------------------------------------------------------------------------"
    echo "    Oracle Database Server auto generated password:"
    echo "    ----> User        : SYS, SYSTEM AND PDBADMIN"
    echo "    ----> Password    : $s"
    echo "------------------------------------------------------------------------"
else
    s=${ORACLE_PWD}
    echo "------------------------------------------------------------------------"
    echo "    Oracle Database Server use pre defined password:"
    echo "    ----> User        : SYS, SYSTEM AND PDBADMIN"
    echo "    ----> Password    : $s"
    echo "------------------------------------------------------------------------"
fi

# write password file
mkdir -p "${ORACLE_BASE}/admin/${ORACLE_SID}/etc"
export ORACLE_PWD=$s
echo "${ORACLE_PWD}" > "${ORACLE_BASE}/admin/${ORACLE_SID}/etc/${ORACLE_SID}_password.txt"

echo "ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: ORACLE_PWD";

# Replace place holders in response file
mkdir -p ${ORACLE_BASE}/tmp/
cp -v ${ORADBA_RSP}/${ORADBA_RSP_FILE} ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"                  ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_DATA###|$ORACLE_DATA|g"                  ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_ARCH###|$ORACLE_ARCH|g"                  ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"                  ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g"                    ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g"                    ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g"                    ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###CONTAINER###|$CONTAINER|g"                      ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###TEMPLATE###|$TEMPLATE|g"                        ${ORACLE_BASE}/tmp/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g"  ${ORACLE_BASE}/tmp/dbca.rsp

# Replace place holders in response file
cp -v ${ORADBA_RSP}/${ORADBA_DBC_FILE} ${ORACLE_HOME}/assistants/dbca/templates/$TEMPLATE
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"  ${ORACLE_HOME}/assistants/dbca/templates/$TEMPLATE
sed -i -e "s|###ORACLE_DATA###|$ORACLE_DATA|g"  ${ORACLE_HOME}/assistants/dbca/templates/$TEMPLATE
sed -i -e "s|###ORACLE_ARCH###|$ORACLE_ARCH|g"  ${ORACLE_HOME}/assistants/dbca/templates/$TEMPLATE
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g"    ${ORACLE_HOME}/assistants/dbca/templates/$TEMPLATE

# If there is greater than 8 CPUs default back to dbca memory calculations
# dbca will automatically pick 40% of available memory for Oracle DB
# The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
# However, bigger environment can and should use more of the available memory
# This is due to Github Issue #307
if [ `nproc` -gt 8 ]; then
   sed -i -e "s|totalMemory=2048||g" ${ORACLE_BASE}/tmp/dbca.rsp
fi;

# update listener.ora
sed -i -e "s|<HOSTNAME>|${HOST}|g" ${TNS_ADMIN}/listener.ora

# Start LISTENER and run DBCA
lsnrctl status || lsnrctl start
dbca -silent -createDatabase -responseFile ${ORACLE_BASE}/tmp/dbca.rsp ||
    cat ${ORACLE_BASE}/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log ||
    cat ${ORACLE_BASE}/cfgtoollogs/dbca/$ORACLE_SID.log

echo "$ORACLE_SID= 
    (DESCRIPTION = 
        (ADDRESS = (PROTOCOL = TCP)(HOST=${HOST})(PORT = 1521))
            (CONNECT_DATA =
                (SERVER = DEDICATED)
            (SERVICE_NAME = $ORACLE_SID)
        )
    )" >> ${TNS_ADMIN}/tnsnames.ora

# Remove second control file, fix local_listener, make PDB auto open
sqlplus / as sysdba << EOF
    ALTER SYSTEM SET local_listener='';
    exit;
EOF

# adjust basenv
MY_ORACLE_SID=${ORACLE_SID}
. "$HOME/.BE_HOME"                                          # load BE_HOME
. "$HOME/.TVDPERL_HOME"                                     # load TVDPERL_HOME
. ${BE_HOME}/bin/basenv.sh                                  # source basenv
. /u00/app/oracle/local/dba/bin/oraenv.ksh ${MY_ORACLE_SID}    # source SID environment

sed -i "/$MY_ORACLE_SID/{s/;[0-9][0-9];/;10;/}" $ETC_BASE/sidtab
# --- EOF -------------------------------------------------------------------