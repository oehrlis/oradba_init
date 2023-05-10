#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Data Platforms
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 72_create_oudsm_domain.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Helper script to create the OUDSM domain  
# Notes......: Script to create an OUDSM domain.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# TODO.......:
# ---------------------------------------------------------------------------
# - Customization -------------------------------------------------------------
ORADBA_BIN=$(dirname ${BASH_SOURCE[0]})
# - End of Customization ------------------------------------------------------

# - Script Variables --------------------------------------------------------
# - Set script names for miscellaneous start, check and config scripts.
# ---------------------------------------------------------------------------
# Default name for OUD instance
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export CREATE_SCRIPT_PYTHON=${CREATE_SCRIPT_PYTHON:-"72_create_oudsm_domain.py"}
# - EOF Script Variables ----------------------------------------------------

# - Environment Variables ---------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------
# Default name for OUD instance
export DOMAIN_NAME=${DOMAIN_NAME:-oudsm_domain}

# Default values for the instance home and admin directory
export OUD_INSTANCE_ADMIN=${OUD_INSTANCE_ADMIN:-${ORACLE_DATA}/admin/${DOMAIN_NAME}}
export OUDSM_DOMAIN_BASE=${OUDSM_DOMAIN_BASE:-"$ORACLE_DATA/domains"}
export DOMAIN_HOME=${OUDSM_DOMAIN_BASE}/${DOMAIN_NAME}

# Default values for host and ports
export HOST=$(hostname 2>/dev/null ||cat /etc/hostname ||echo $HOSTNAME)   # Hostname
export PORT=${PORT:-7001}                               # Default HTTP port
export PORT_SSL=${PORT_SSL:-7002}                       # Default HTTPS port

# Default value for the directory
export ADMIN_USER=${ADMIN_USER:-'weblogic'} # Default directory admin user
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-""}             # Default directory admin password
export PWD_FILE=${PWD_FILE:-${OUD_INSTANCE_ADMIN}/etc/${DOMAIN_NAME}_pwd.txt}
# - EOF Environment Variables -----------------------------------------------

function gen_password {
# Purpose....: generate a password string
# -----------------------------------------------------------------------
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

echo "--- Setup OUDSM environment on volume ${ORACLE_DATA} --------------------"

# create instance directories on volume
mkdir -v -p ${ORACLE_DATA}
for i in admin backup etc instances domains log scripts; do
    mkdir -v -p ${ORACLE_DATA}/${i}
done
mkdir -v -p ${OUD_INSTANCE_ADMIN}/etc
mkdir -v -p ${OUD_INSTANCE_ADMIN}/create
cp ${ORADBA_BIN}/${CREATE_SCRIPT_PYTHON} ${OUD_INSTANCE_ADMIN}/create/${CREATE_SCRIPT_PYTHON}
# create oudtab file for OUD Base
OUDTAB=${ORACLE_DATA}/etc/oudtab
# create oudtab file for OUD Base, comment is just for documenttion..
OUDTAB=${ORACLE_DATA}/etc/oudtab
if [ -f "${OUDTAB}" ]; then
    echo "${DOMAIN_NAME}:${PORT}:${PORT_SSL}:::OUDSM" >>${OUDTAB}
else
    echo "# OUD Config File"                                                     >${OUDTAB}
    echo "#  1: OUD Instance Name"                                              >>${OUDTAB}
    echo "#  2: OUD LDAP Port"                                                  >>${OUDTAB}
    echo "#  3: OUD LDAPS Port"                                                 >>${OUDTAB}
    echo "#  4: OUD Admin Port"                                                 >>${OUDTAB}
    echo "#  5: OUD Replication Port"                                           >>${OUDTAB}
    echo "#  6: Directory type eg. OUD, OID, ODSEE or OUDSM"                    >>${OUDTAB}
    echo "# -----------------------------------------------"                    >>${OUDTAB}
    echo "${DOMAIN_NAME}:${PORT}:${PORT_SSL}:::OUDSM" >>${OUDTAB}
fi

# check if we have a password file
if [ -f "${OUD_INSTANCE_ADMIN}/etc/${DOMAIN_NAME}_pwd.txt" ]; then
    echo "    found password file ${OUD_INSTANCE_ADMIN}/etc/${DOMAIN_NAME}_pwd.txt"
    export ADMIN_PASSWORD=$(cat ${OUD_INSTANCE_ADMIN}/etc/${DOMAIN_NAME}_pwd.txt)
fi
# generate password if it is still empty
if [ -z ${ADMIN_PASSWORD} ]; then
    # Auto generate Oracle WebLogic Server admin password
    ADMIN_PASSWORD=$(gen_password 12)
    echo "---------------------------------------------------------------"
    echo "    Oracle WebLogic Server Auto Generated OUDSM Domain:"
    echo "    ----> 'weblogic' admin password: $ADMIN_PASSWORD"
    echo "---------------------------------------------------------------"
fi 
sed -i -e "s|ADMIN_PASSWORD|$ADMIN_PASSWORD|g" ${OUD_INSTANCE_ADMIN}/create/${CREATE_SCRIPT_PYTHON}
echo $ADMIN_PASSWORD > ${OUD_INSTANCE_ADMIN}/etc/${DOMAIN_NAME}_pwd.txt

echo "--- Create WebLogic Server Domain (${DOMAIN_NAME}) -----------------------------"
echo "  DOMAIN_NAME=${DOMAIN_NAME}"
echo "  DOMAIN_HOME=${DOMAIN_HOME}"
echo "  PORT=${PORT}"
echo "  PORT_SSL=${PORT_SSL}"
echo "  ADMIN_USER=${ADMIN_USER}"

# Create an empty domain
${ORACLE_HOME}/oracle_common/common/bin/wlst.sh \
    -skipWLSModuleScanning ${OUD_INSTANCE_ADMIN}/create/${CREATE_SCRIPT_PYTHON}

if [ $? -eq 0 ]; then
    echo "--- Successfully created WebLogic Server Domain (${DOMAIN_NAME}) --------------"
else 
    echo "--- ERROR creating WebLogic Server Domain (${DOMAIN_NAME}) --------------------"
fi
${DOMAIN_HOME}/bin/setDomainEnv.sh
# --- EOF -------------------------------------------------------------------
