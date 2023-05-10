#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Transactional Data Platform
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 74_check_oudsm_console.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: check the status of the OUDSM console for docker HEALTHCHECK 
# Notes......: Script is a wrapper for a simple curl. It makes sure, that the 
#              status of the docker OUDSM console is checked and the exit code
#              is docker compliant (0 or 1).
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

# - Environment Variables ---------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------
# Default values for host and ports
export HOST=$(hostname 2>/dev/null ||cat /etc/hostname ||echo $HOSTNAME)   # Hostname
export PORT=${PORT:-7001}                               # Default HTTP port
# - EOF Environment Variables -----------------------------------------------

# run OUD status check
URL="http://${HOST}:$PORT/oudsm/"
curl -sSf ${URL} >/dev/null 2>&1

# normalize output for docker....
OUD_ERROR=$?
if [ ${OUD_ERROR} -gt 0 ]; then
    echo "$0: OUDSM check (${URL}) did return error ${OUD_ERROR}"
    exit 1
else
    exit 0
fi
# --- EOF -------------------------------------------------------------------