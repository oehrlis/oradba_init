#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 54_check_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.04
# Revision...: 
# Purpose....: check the status of the Oracle database for docker HEALTHCHECK 
# Notes......: Script does check the DB open mode using sqlplus and return and  
#              make sure that the exit code is docker compliant (0, 1 or 2).
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

export ORACLE_SID=$(grep $ORACLE_HOME /etc/oratab | grep -iv '^#' |cut -d: -f1|head -1)
export POSITIVE_RETURN="READ WRITE"
export ORAENV_ASK=NO
. oraenv
# - EOF Environment Variables -------------------------------------------

# Check Oracle DB status and store it in status
status=`$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
   set heading off;
   set pagesize 0;
   SELECT open_mode FROM v\\$database;
   exit;
EOF`

# Store return code from SQL*Plus
ret=$?

# SQL Plus execution was successful and PDB is open
if [ $ret -eq 0 ] && [ "$status" = "$POSITIVE_RETURN" ]; then
   exit 0;
# PDB is not open
elif [ "$status" != "$POSITIVE_RETURN" ]; then
   exit 1;
# SQL Plus execution failed
else
   exit 2
fi
# --- EOF -------------------------------------------------------------------