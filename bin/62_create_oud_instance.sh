#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 62_create_oud_instance.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Helper script to create the OUD instance 
# Notes......: Script to create an OUD instance. If configuration files are
#              provided, the will be used to configure the instance.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...: 
# see git revision history for more information on changes/updates
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
export CONFIG_SCRIPT=${CONFIG_SCRIPT:-"63_config_oud_instance.sh"}
# - EOF Script Variables ----------------------------------------------------

# - Environment Variables ---------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------
# Default name for OUD instance
export OUD_INSTANCE=${OUD_INSTANCE:-oud_docker}

# Default values for the instance home and admin directory
export OUD_INSTANCE_ADMIN=${OUD_INSTANCE_ADMIN:-${ORACLE_DATA}/admin/${OUD_INSTANCE}}
export OUD_INSTANCE_BASE=${OUD_INSTANCE_BASE:-"$ORACLE_DATA/instances"}
export OUD_INSTANCE_HOME=${OUD_INSTANCE_HOME:-"${OUD_INSTANCE_BASE}/${OUD_INSTANCE}"}

# set the OUD major version default is 12
export OUD_VERSION=${OUD_VERSION:-"12"}

# OUD 11g instance name and home path for installation
export INSTANCE_NAME=${INSTANCE_NAME:-"../../../../..${OUD_INSTANCE_HOME}"}

# Default values for host and ports
export HOST=$(hostname 2>/dev/null ||cat /etc/hostname ||echo $HOSTNAME)   # Hostname
export PORT=${PORT:-1389}                               # Default LDAP port
export PORT_SSL=${PORT_SSL:-1636}                       # Default LDAPS port
export PORT_HTTP=${PORT_HTTP:-8080}                     # Default LDAPS port
export PORT_HTTPS=${PORT_HTTPS:-10443}                  # Default LDAPS port
export PORT_REP=${PORT_REP:-8989}                       # Default replication port
export PORT_ADMIN=${PORT_ADMIN:-4444}                   # Default admin port
export PORT_ADMIN_HTTP=${PORT_ADMIN_HTTP:-8444}         # Default admin port

# Default value for the directory
export ADMIN_USER=${ADMIN_USER:-'cn=Directory Manager'} # Default directory admin user
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-""}             # Default directory admin password
export PWD_FILE=${PWD_FILE:-${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt}
export BASEDN=${BASEDN:-'dc=example,dc=com'}          # Default directory base DN
export SAMPLE_DATA=${SAMPLE_DATA:-'TRUE'}               # Flag to load sample data
export OUD_PROXY=${OUD_PROXY:-'FALSE'}                  # Flag to create proxy instance
export OUD_CUSTOM=${OUD_CUSTOM:-'FALSE'}                # Flag to create custom instance

# default folder for DB instance init scripts
export INSTANCE_INIT=${INSTANCE_INIT:-"${OUD_INSTANCE_ADMIN}/scripts"}
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

# Normalize CREATE_INSTANCE
export OUD_PROXY=$(echo $OUD_PROXY| sed 's/^false$/0/gi')
export OUD_PROXY=$(echo $OUD_PROXY| sed 's/^true$/1/gi')

# Normalize CREATE_INSTANCE
export OUD_CUSTOM=$(echo $OUD_CUSTOM| sed 's/^false$/0/gi')
export OUD_CUSTOM=$(echo $OUD_CUSTOM| sed 's/^true$/1/gi')

# Normalize SAMPLE_DATA and DIRECTORY_DATA
DIRECTORY_DATA="--addBaseEntry"
if [ -z ${SAMPLE_DATA} ]; then
    echo "SAMPLE_DATA is not set. Create base entry $BASEDN"
    DIRECTORY_DATA="--addBaseEntry"
elif [[ "${SAMPLE_DATA}" =~ ^[0-9]+$ ]]; then
    echo "SAMPLE_DATA is set to a number. Creating $SAMPLE_DATA sample entries"
    DIRECTORY_DATA="--sampleData $SAMPLE_DATA"
elif [[ "${SAMPLE_DATA^^}" =~ ^TRUE$ ]]; then
    echo "SAMPLE_DATA is true. Creating 100 sample entries"
    DIRECTORY_DATA="--sampleData 100"
else
    echo "SAMPLE_DATA is undefined. Create base entry $BASEDN"
    DIRECTORY_DATA="--addBaseEntry"
fi

echo "--- Setup OUD environment on volume ${ORACLE_DATA} ---------------------"
# create instance directories on volume
mkdir -v -p ${ORACLE_DATA}
for i in admin backup etc instances domains log scripts; do
    mkdir -v -p ${ORACLE_DATA}/${i}
done
mkdir -v -p ${OUD_INSTANCE_ADMIN}/etc

# create oudtab file for OUD Base, comment is just for documenttion..
OUDTAB=${ORACLE_DATA}/etc/oudtab
if [ -f "${OUDTAB}" ]; then
    echo "${OUD_INSTANCE}:${PORT}:${PORT_SSL}:${PORT_ADMIN}:${PORT_REP}:OUD"    >>${OUDTAB}
else
    echo "# OUD Config File"                                                     >${OUDTAB}
    echo "#  1: OUD Instance Name"                                              >>${OUDTAB}
    echo "#  2: OUD LDAP Port"                                                  >>${OUDTAB}
    echo "#  3: OUD LDAPS Port"                                                 >>${OUDTAB}
    echo "#  4: OUD Admin Port"                                                 >>${OUDTAB}
    echo "#  5: OUD Replication Port"                                           >>${OUDTAB}
    echo "#  6: Directory type eg. OUD, OID, ODSEE or OUDSM"                    >>${OUDTAB}
    echo "# -----------------------------------------------"                    >>${OUDTAB}
    echo "${OUD_INSTANCE}:${PORT}:${PORT_SSL}:${PORT_ADMIN}:${PORT_REP}:OUD"    >>${OUDTAB}
fi

# check if we have a password file
if [ -f "${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt" ]; then
    echo "    found password file ${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt"
    export ADMIN_PASSWORD=$(cat ${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt)
fi
# generate password if it is still empty
if [ -z ${ADMIN_PASSWORD} ]; then
    # Auto generate Oracle WebLogic Server admin password
    ADMIN_PASSWORD=$(gen_password 12)
    echo "---------------------------------------------------------------"
    echo " - Oracle Unified Directory Server auto generated instance"
    echo " - admin password :"
    echo " - ----> Directory Admin : ${ADMIN_USER} "
    echo " - ----> Admin password  : $ADMIN_PASSWORD"
    echo "---------------------------------------------------------------"
fi 

mkdir -p "${OUD_INSTANCE_ADMIN}/etc/"
echo $ADMIN_PASSWORD > ${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt

# set instant init location create folder if it does exists
if [ ! -d "${INSTANCE_INIT}/setup" ]; then
    INSTANCE_INIT="${ORACLE_BASE}/admin/${ORACLE_SID}/scripts"
fi

echo "--- Create OUD instance ------------------------------------------------"
echo "  OUD_INSTANCE       = ${OUD_INSTANCE}"
echo "  OUD_INSTANCE_BASE  = ${OUD_INSTANCE_BASE}"
echo "  OUD_INSTANCE_ADMIN = ${OUD_INSTANCE_ADMIN}"
echo "  INSTANCE_INIT      = ${INSTANCE_INIT}"
echo "  OUD_INSTANCE_HOME  = ${OUD_INSTANCE_HOME}"
echo "  PORT               = ${PORT}"
echo "  PORT_SSL           = ${PORT_SSL}"
echo "  PORT_HTTP          = ${PORT_HTTP}"
echo "  PORT_HTTPS         = ${PORT_HTTPS}"
echo "  PORT_REP           = ${PORT_REP}"
echo "  PORT_ADMIN         = ${PORT_ADMIN}"
echo "  PORT_REST_ADMIN    = ${PORT_REST_ADMIN}"
echo "  PORT_REST_HTTP     = ${PORT_REST_HTTP}"
echo "  PORT_REST_HTTPS    = ${PORT_REST_HTTPS}"
echo "  ADMIN_USER         = ${ADMIN_USER}"
echo "  BASEDN             = ${BASEDN}"
echo "  SAMPLE_DATA        = ${SAMPLE_DATA}"
echo "  OUD_PROXY          = ${OUD_PROXY}"
echo ""

if  [ ${OUD_CUSTOM} -eq 1 ]; then
    echo "--- Create OUD instance (${OUD_INSTANCE}) using custom scripts ---------"
    ${ORADBA_BIN}/${CONFIG_SCRIPT} ${INSTANCE_INIT}/setup
elif [ ${OUD_PROXY} -eq 0 ]; then
# Create an OUD directory
    if [ ${OUD_VERSION} == "12" ]; then
        echo "--- Create regular OUD 12c instance (${OUD_INSTANCE}) ----------------------"
        # Create an OUD 12c directory
        ${ORACLE_BASE}/product/${ORACLE_HOME_NAME}/oud/oud-setup \
            --cli \
            --instancePath "${OUD_INSTANCE_HOME}/OUD" \
            --rootUserDN "${ADMIN_USER}" \
            --rootUserPasswordFile "${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt" \
            --adminConnectorPort ${PORT_ADMIN} \
            --httpAdminConnectorPort ${PORT_ADMIN_HTTP} \
            --ldapPort ${PORT} \
            --httpPort ${PORT_HTTP} \
            --ldapsPort ${PORT_SSL} \
            --httpsPort ${PORT_HTTPS} \
            --generateSelfSignedCertificate \
            --enableStartTLS \
            --hostname ${HOST} \
            --baseDN "${BASEDN}" \
            ${DIRECTORY_DATA} \
            --serverTuning jvm-default \
            --offlineToolsTuning autotune \
            --no-prompt \
            --noPropertiesFile
    else
        echo "--- Create regular OUD 11g instance (${OUD_INSTANCE}) ----------------------"
        # Create an OUD 11g directory
        ${ORACLE_BASE}/product/${ORACLE_HOME_NAME}/oud-setup \
            --cli \
            --rootUserDN "${ADMIN_USER}" \
            --rootUserPasswordFile "${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt" \
            --adminConnectorPort ${PORT_ADMIN} \
            --ldapPort ${PORT} \
            --ldapsPort ${PORT_SSL} \
            --generateSelfSignedCertificate \
            --enableStartTLS \
            --baseDN "${BASEDN}" \
            ${DIRECTORY_DATA} \
            --serverTuning jvm-default \
            --offlineToolsTuning autotune \
            --no-prompt \
            --noPropertiesFile
    fi
    if [ $? -eq 0 ]; then
        echo "--- Successfully created regular OUD instance (${OUD_INSTANCE}) --------"
        # Execute custom provided setup scripts
        ${ORADBA_BIN}/${CONFIG_SCRIPT} ${INSTANCE_INIT}/setup
    else
        echo "--- ERROR creating regular OUD instance (${OUD_INSTANCE}) --------------"
        exit 1
    fi
elif [ ${OUD_PROXY} -eq 1 ]; then
# Create an OUD proxy server
    if [ ${OUD_VERSION} == "12" ]; then
        echo "--- Create regular OUD 12c proxy instance (${OUD_INSTANCE}) ----------------------"
        # Create an OUD 12c proxy server
        ${ORACLE_BASE}/product/${ORACLE_HOME_NAME}/oud/oud-proxy-setup \
            --cli \
            --instancePath "${OUD_INSTANCE_HOME}/OUD" \
            --rootUserDN "${ADMIN_USER}" \
            --rootUserPasswordFile "${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt" \
            --adminConnectorPort ${PORT_ADMIN} \
            --httpAdminConnectorPort ${PORT_ADMIN_HTTP} \
            --ldapPort ${PORT} \
            --httpPort ${PORT_HTTP} \
            --ldapsPort ${PORT_SSL} \
            --httpsPort ${PORT_HTTPS} \
            --generateSelfSignedCertificate \
            --enableStartTLS \
            --hostname ${HOST} \
            --no-prompt \
            --noPropertiesFile
    else
        echo "--- Create regular OUD 11c proxy instance (${OUD_INSTANCE}) ----------------------"
        # Create an OUD 11c proxy server
        ${ORACLE_BASE}/product/${ORACLE_HOME_NAME}/oud-proxy-setup \
            --cli \
            --rootUserDN "${ADMIN_USER}" \
            --rootUserPasswordFile "${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt" \
            --adminConnectorPort ${PORT_ADMIN} \
            --ldapPort ${PORT} \
            --ldapsPort ${PORT_SSL} \
            --generateSelfSignedCertificate \
            --enableStartTLS \
            --no-prompt \
            --noPropertiesFile
    fi
    if [ $? -eq 0 ]; then
        echo "--- Successfully created OUD proxy instance (${OUD_INSTANCE}) ----------"
        # Execute custom provided setup scripts
        ${ORADBA_BIN}/${CONFIG_SCRIPT} ${INSTANCE_INIT}/setup
    else
        echo "--- ERROR creating OUD proxy instance (${OUD_INSTANCE}) -----------------"
        exit 1
    fi
fi

# copy config scripts
if [ -d "${INSTANCE_INIT}/setup" ] && [ -d "${OUD_INSTANCE_ADMIN}/create" ]; then
    cp -vr ${INSTANCE_INIT}/setup/* ${OUD_INSTANCE_ADMIN}/create
fi
# --- EOF -------------------------------------------------------------------