#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 51_start_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: Helper script to start the Oracle database
# Notes......: Script to start an Oracle database.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# Modified...: 
# see git revision history for more information on changes/updates
# ------------------------------------------------------------------------------

# - Environment Variables ------------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ------------------------------------------------------------------------------

# - EOF Environment Variables --------------------------------------------------

# - Initialization -------------------------------------------------------------
if [ "$ORACLE_HOME" == "" ]; then
  script_name=`basename "$0"`
  echo "$script_name: ERROR - ORACLE_HOME is not set. Please set ORACLE_HOME and PATH before invoking this script."
  exit 1;
fi
# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------
# Start Listener
$ORACLE_HOME/bin/lsnrctl start

# Start database in mount mode
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
  STARTUP;
  exit;
EOF

db_role=$($ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
set heading off feedback off verify off echo off
SELECT database_role FROM v\$database;
exit;
EOF
)

# Trim whitespace from db_role
db_role=$(echo $db_role | xargs)

# If the database role is PHYSICAL STANDBY, close the database
if [ "$db_role" == "PHYSICAL STANDBY" ]; then
  $ORACLE_HOME/bin/sqlplus / as sysdba <<EOF
  ALTER DATABASE CLOSE;
  exit;
EOF
fi
# --- EOF ----------------------------------------------------------------------