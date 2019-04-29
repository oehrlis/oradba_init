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
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

export ORACLE_SID=${1:-TDB183C}                 # Default name for Oracle database
export ORACLE_PDB=${2:-PDB1}                    # Check whether ORACLE_PDB is passed on
export CONTAINER=${3:-"false"}                  # Check whether CONTAINER is passed on

export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"18.4.0.0"}
export ORACLE_BASE=${ORACLE_BASE:-"/u00/app/oracle"}
export ORACLE_HOME=${ORACLE_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE}/product/ -name sqlplus -type f|sort|tail -1)))}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-"${ORACLE_HOME}/lib:/usr/lib"}
    
export ORACLE_VERSION="$(${ORACLE_HOME}/bin/sqlplus -V|grep -ie 'Release\|Version'|sed 's/^.*\([0-9]\{2\}\.[0-9]\.[0-9]\.[0-9]\.[0-9]\).*$/\1/'|tail -1)"
export ORACLE_RELEASE="$(${ORACLE_HOME}/bin/sqlplus -V|grep -ie 'Release'|sed 's/^.*\([0-9]\{2\}\.[0-9]\.[0-9]\).*$/\1/'|tail -1)"

# define oradba specific variables
export ORADBA_BIN=${ORADBA_INIT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)}
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP=${ORADBA_RSP:-"${ORADBA_BASE}/rsp"}           # oradba init response file folder
export ORADBA_TEMPLATE_PREFIX=${ORADBA_TEMPLATE_PREFIX:-""}
export ORADBA_RSP_FILE=${ORADBA_RSP_FILE:-"dbca${ORACLE_RELEASE}.rsp.tmpl"} # oradba init response file
export ORADBA_DBC_FILE=${ORADBA_DBC_FILE:-"${ORADBA_TEMPLATE_PREFIX}dbca${ORACLE_RELEASE}.dbc.tmpl"}
export ORACLE_SID_ADMIN_ETC="${ORACLE_BASE}/admin/${ORACLE_SID}/etc"
export ORADBA_TEMPLATE=${ORADBA_TEMPLATE:-"${ORACLE_SID_ADMIN_ETC}/dbca${ORACLE_SID}.dbc"}
export ORADBA_RESPONSE=${ORADBA_RESPONSE:-"${ORACLE_SID_ADMIN_ETC}/dbca${ORACLE_SID}.rsp"}
export ORACLE_PWD=${ORACLE_PWD:-""}             # Default admin password

HOSTNAME_BIN=$(command -v hostname)                             # get the binary for hostname
HOSTNAME_BIN=${HOSTNAME_BIN:-"cat /proc/sys/kernel/hostname"}   # fallback to /proc/sys/kernel/hostname
export HOST=$(${HOSTNAME_BIN})
export DEFAULT_DOMAIN=${DEFAULT_DOMAIN:-$(hostname -d 2>/dev/null ||cat /etc/domainname ||echo "postgasse.org")}

export TNS_ADMIN=${TNS_ADMIN:-${ORACLE_BASE}/network/admin}

# default folder for DB instance init scripts
export INSTANCE_INIT=${INSTANCE_INIT:-"${ORACLE_BASE}/admin/${ORACLE_SID}/scripts"}
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

# set instant init location create folder if it does exists
if [ ! -d "${INSTANCE_INIT}/setup" ]; then
    INSTANCE_INIT="${ORACLE_BASE}/admin/${ORACLE_SID}/scripts"
fi

# inform what's done next...
echo "Create database instance ${ORACLE_SID} using:"
echo "ORACLE_SID            : ${ORACLE_SID}"
echo "HOST                  : ${HOST}"
echo "ORACLE_HOME           : ${ORACLE_HOME}"
echo "ORACLE_RELEASE        : ${ORACLE_RELEASE}"
echo "ORACLE_VERSION        : ${ORACLE_VERSION}"
echo "ORACLE_BASE           : ${ORACLE_BASE}"
echo "ORACLE_DATA           : ${ORACLE_DATA}"
echo "ORACLE_ARCH           : ${ORACLE_ARCH}"
echo "CONTAINER             : ${CONTAINER}"
echo "INSTANCE_INIT         : ${INSTANCE_INIT}"
echo "RESPONSE              : ${ORADBA_RSP_FILE}"
echo "TEMPLATE              : ${ORADBA_DBC_FILE}"
echo "ORADBA_TEMPLATE_PREFIX: ${ORADBA_TEMPLATE_PREFIX}"
echo "DB RESPONSE           : ${ORADBA_RESPONSE}"
echo "DB TEMPLATE           : ${ORADBA_TEMPLATE}"
echo "ORACLE_CHARACTERSET   : ${ORACLE_CHARACTERSET}"

# write password file
mkdir -p ${ORACLE_SID_ADMIN_ETC}
export ORACLE_PWD=$s
echo "${ORACLE_PWD}" > "${ORACLE_BASE}/admin/${ORACLE_SID}/etc/${ORACLE_SID}_password.txt"
echo "ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: ORACLE_PWD";

# Replace place holders in response file
cp -v ${ORADBA_RSP}/${ORADBA_DBC_FILE} ${ORADBA_TEMPLATE}
sed -i -e "s|###ORACLE_DATA###|$ORACLE_DATA|g"          ${ORADBA_TEMPLATE}
sed -i -e "s|###ORACLE_ARCH###|$ORACLE_ARCH|g"          ${ORADBA_TEMPLATE}
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g"            ${ORADBA_TEMPLATE}
sed -i -e "s|###DEFAULT_DOMAIN###|$DEFAULT_DOMAIN|g"    ${ORADBA_TEMPLATE}

# Replace place holders in response file
cp -v ${ORADBA_RSP}/${ORADBA_RSP_FILE} ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g"                  ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_DATA###|$ORACLE_DATA|g"                  ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_ARCH###|$ORACLE_ARCH|g"                  ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g"                  ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g"                    ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g"                    ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g"                    ${ORADBA_RESPONSE}
sed -i -e "s|###CONTAINER###|$CONTAINER|g"                      ${ORADBA_RESPONSE}
sed -i -e "s|###TEMPLATE###|${ORADBA_TEMPLATE}|g"               ${ORADBA_RESPONSE}
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g"  ${ORADBA_RESPONSE}

# If there is greater than 8 CPUs default back to dbca memory calculations
# dbca will automatically pick 40% of available memory for Oracle DB
# The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
# However, bigger environment can and should use more of the available memory
# This is due to Github Issue #307
if [ `nproc` -gt 8 ]; then
   sed -i -e "s|totalMemory=2048||g" ${ORACLE_SID_ADMIN_ETC}/$RESPONSE
fi;

# update listener.ora in general just for the Docker listener.ora
sed -i -e "s|<HOSTNAME>|${HOST}|g" ${TNS_ADMIN}/listener.ora

# Start LISTENER and run DBCA
$ORACLE_HOME/bin/lsnrctl status > /dev/null 2>&1 || $ORACLE_HOME/bin/lsnrctl start
$ORACLE_HOME/bin/dbca -silent -createDatabase -responseFile ${ORADBA_RESPONSE} 

echo "$ORACLE_SID= 
    (DESCRIPTION = 
        (ADDRESS = (PROTOCOL = TCP)(HOST=${HOST})(PORT = 1521))
            (CONNECT_DATA =
                (SERVER = DEDICATED)
            (SERVICE_NAME = $ORACLE_SID)
        )
    )" >> ${TNS_ADMIN}/tnsnames.ora

# Remove second control file, fix local_listener, make PDB auto open
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
    ALTER SYSTEM SET local_listener='';
    exit;
EOF

# Execute custom provided setup scripts
${ORADBA_BIN}/${CONFIG_SCRIPT} ${INSTANCE_INIT}/setup

# remove passwords from response file
sed -i -e "s|${ORACLE_PWD}|ORACLE_PASSWORD|g" ${ORADBA_RESPONSE}

# adjust basenv
MY_ORACLE_SID=${ORACLE_SID}
. "$HOME/.BE_HOME"                                          # load BE_HOME
. "$HOME/.TVDPERL_HOME"                                     # load TVDPERL_HOME
. ${BE_HOME}/bin/basenv.sh                                  # source basenv
. /u00/app/oracle/local/dba/bin/oraenv.ksh ${MY_ORACLE_SID} # source SID environment

sed -i "/$MY_ORACLE_SID/{s/;[0-9][0-9];/;10;/}" $ETC_BASE/sidtab
echo "[${MY_ORACLE_SID}]">$ETC_BASE/sid.${MY_ORACLE_SID}.conf
echo "${ORACLE_SID}:${ORACLE_HOME}:Y" >>${ORACLE_BASE}/etc/oratab

# --- EOF -------------------------------------------------------------------