#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 63_config_oud_instance.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Configure OUD instance using custom scripts 
# Notes......: Script is a wrapper for custom setup script in SCRIPTS_ROOT 
#              All files in folder SCRIPTS_ROOT will be executet but not in 
#              any subfolder. Currently just *.sh, *.ldif and *.conf files 
#              are supported.
#              sh   : Shell scripts will be executed
#              ldif : LDIF files will be loaded via ldapmodify
#              conf : Config files will be loaded via dsconfig
#              To ensure proper order it is recommended to prefix your scripts
#              with a number. For example 01_instance.conf, 
#              02_schemaextention.ldif, etc.
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
# - EOF Script Variables ----------------------------------------------------

# Default name for OUD instance
export OUD_INSTANCE=${OUD_INSTANCE:-oud_docker}

# Default values for the instance home and admin directory
export OUD_INSTANCE_ADMIN=${OUD_INSTANCE_ADMIN:-${ORACLE_DATA}/admin/${OUD_INSTANCE}}
export OUD_INSTANCE_HOME=${OUD_INSTANCE_HOME:-"${OUD_INSTANCE_BASE}/${OUD_INSTANCE}"}

# Default values for host and ports
export HOST=$(hostname 2>/dev/null ||cat /etc/hostname ||echo $HOSTNAME)   # Hostname
export PORT=${PORT:-1389}                               # Default LDAP port
export PORT_ADMIN=${PORT_ADMIN:-4444}                   # Default admin port

# Default value for the directory
export ADMIN_USER=${ADMIN_USER:-'cn=Directory Manager'} # Default directory admin user
export PWD_FILE=${PWD_FILE:-${OUD_INSTANCE_ADMIN}/etc/${OUD_INSTANCE}_pwd.txt}

# default folder for OUD instance init scripts
export INSTANCE_INIT=${INSTANCE_INIT:-$ORACLE_DATA/config}
# - EOF Environment Variables -----------------------------------------------

# use parameter 1 as script root
SCRIPTS_ROOT="$1";

# Check whether parameter has been passed on
if [ -z "${SCRIPTS_ROOT}" ]; then
   echo "$0: No SCRIPTS_ROOT passed on, no scripts will be run";
   exit 1;
fi

# Execute custom provided files (only if directory exists and has files in it)
if [ -d "${SCRIPTS_ROOT}" ] && [ -n "$(ls -A ${SCRIPTS_ROOT})" ]; then
    echo "";
    echo "--- Executing user defined scripts -------------------------------------"

# Loop over the files in the current directory
    for f in $(find ${SCRIPTS_ROOT} -maxdepth 1 -type f|sort); do
        # Skip ldif and conf file if a bash script with same name exists
        if [ -f "$(dirname $f)/$(basename $f .ldif).sh" ]; then
            echo "INFO: skip file $f, bash script with same name exists."
            continue
        elif [ -f "$(dirname $f)/$(basename $f .conf).sh" ]; then
            echo "INFO: skip file $f, bash script with same name exists."
            continue
        elif [ -f "$(dirname $f)/$(basename $f .sh).sh" ]; then
            echo "INFO: bash script $f."
        else
            echo "INFO: no bash script for file $f."
        fi
        echo "--- --------------------------------------------------------------------"
        case "$f" in
            *.sh)     echo "INFO: running $f"; "$f" ;;
            *.ldif)   echo "INFO: running $f"; echo "exit" | ${OUD_INSTANCE_HOME}/OUD/bin/ldapmodify --defaultAdd --hostname ${HOST} --port ${PORT} --bindDN "${ADMIN_USER}" --bindPasswordFile ${PWD_FILE} --filename "$f"; echo ;;
            *.conf)   echo "INFO: running $f"; echo "exit" | ${OUD_INSTANCE_HOME}/OUD/bin/dsconfig --hostname ${HOST}  --port ${PORT_ADMIN} --bindDN "${ADMIN_USER}" --bindPasswordFile ${PWD_FILE} --trustAll --no-prompt -F "$f"; echo ;;
            *)        echo "INFO: skip file $f" ;;
        esac
        echo "";
    done
    echo "--- Successfully executed user defined ---------------------------------"
  echo ""
else
    echo "--- no user defined scripts to execute ---------------------------------"
fi
# --- EOF -------------------------------------------------------------------