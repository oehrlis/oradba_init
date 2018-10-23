#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 50_start_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Helper script to start the Oracle database
# Notes......: Script to start an Oracle database.
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

# - EOF Environment Variables -----------------------------------------------

# - Initialization ----------------------------------------------------------
if [ "$ORACLE_HOME" == "" ]; then
  script_name=`basename "$0"`
  echo "$script_name: ERROR - ORACLE_HOME is not set. Please set ORACLE_HOME and PATH before invoking this script."
  exit 1;
fi

# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# Start Listener
$ORACLE_HOME/bin/lsnrctl start

# Start database
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
   STARTUP;
   exit;
EOF
# --- EOF -------------------------------------------------------------------