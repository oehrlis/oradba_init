#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Data Platforms
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
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------

# - Environment Variables ---------------------------------------------------
# - Set default values for environment variables if not yet defined. 
# ---------------------------------------------------------------------------

export ORACLE_SID=$(grep $ORACLE_HOME /etc/oratab | grep -iv '^#' |cut -d: -f1|head -1)
export POSITIVE_RETURN="READ WRITE"
export STANDBY_RETURN="MOUNTED READ ONLY"
export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1
# - EOF Environment Variables -------------------------------------------


# - Check Oracle DB status --------------------------------------------------
status_and_role=`$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
   set heading off;
   set pagesize 0;
   SELECT open_mode || ',' || database_role FROM v\\$database;
   exit;
EOF`

# Store return code from SQL*Plus
ret=$?

# Parse the output into variables
status=$(echo $status_and_role | cut -d, -f1)
role=$(echo $status_and_role | cut -d, -f2)

# Determine the appropriate action based on open_mode and database_role
if [ $ret -eq 0 ]; then
   if [ "$role" = "PRIMARY" ] && [ "$status" = "$POSITIVE_RETURN" ]; then
      echo "role is primary"
      exit 0
   elif [ "$role" = "PHYSICAL STANDBY" ] && [[ "$STANDBY_RETURN" =~ $status ]]; then
      echo "role is physical standby"
      exit 0
   else
      echo "Unknown state: role=$role, status=$status"
      exit 1
   fi
else
   echo "SQL*Plus execution failed"
   exit 2
fi
# --- EOF -------------------------------------------------------------------