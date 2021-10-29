#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis - Part of Accenture, Platform Factory - Transactional Data Platform
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 53_config_database.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: Configure database using custom scripts 
# Notes......: Script is a wrapper for custom setup script in SCRIPTS_ROOT 
#              All files in folder SCRIPTS_ROOT will be executet but not in 
#              any subfolder. Currently just *.sh and *.sql files are supported.
#              sh   : Shell scripts will be executed
#              sql  : SQL files will be executed via sqlplus as SYSDBA
#              To ensure proper order it is recommended to prefix your scripts
#              with a number. For example 01_instance.sh, 
#              02_schemaextention.sql, etc.
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------

# use parameter 1 as script root
SCRIPTS_ROOT="$1";

# Check whether parameter has been passed on
if [ -z "$SCRIPTS_ROOT" ]; then
   echo "$0: No SCRIPTS_ROOT passed on, no scripts will be run";
   exit 1;
fi;

# Execute custom provided files (only if directory exists and has files in it)
if [ -d "$SCRIPTS_ROOT" ] && [ -n "$(ls -A $SCRIPTS_ROOT)" ]; then

  echo "";
  echo " - Executing user defined scripts"

  for f in $SCRIPTS_ROOT/*; do
      case "$f" in
          *.sh)     echo " - $0: running $f"; . "$f" ;;
          *.sql)    echo " - $0: running $f"; echo "exit" | $ORACLE_HOME/bin/sqlplus -s "/ as sysdba" @"$f"; echo ;;
          *)        echo " - $0: ignoring $f" ;;
      esac
      echo "";
  done
  
  echo "INFO: Finish executing user defined scripts"
  echo "";

fi
# --- EOF -------------------------------------------------------------------