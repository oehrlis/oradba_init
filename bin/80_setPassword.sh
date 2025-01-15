#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: 80_setPassword.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2020.03.11
# Revision...: 
# Purpose....: check the status of the OUDSM console for docker HEALTHCHECK 
# Notes......: Script is a wrapper for a simple curl. It makes sure, that the 
#              status of the docker OUDSM console is checked and the exit code
#              is docker compliant (0 or 1).
# Reference..: Oracle docker github rebository
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------
ORACLE_PWD=$1
ORACLE_SID="`grep $ORACLE_HOME /etc/oratab | cut -d: -f1`"
ORACLE_PDB="`ls -dl $ORACLE_BASE/oradata/$ORACLE_SID/*/ | grep -v pdbseed | awk '{print $9}' | cut -d/ -f6`"
ORAENV_ASK=NO
source oraenv

sqlplus / as sysdba << EOF
      ALTER USER SYS IDENTIFIED BY "$ORACLE_PWD";
      ALTER USER SYSTEM IDENTIFIED BY "$ORACLE_PWD";
      ALTER SESSION SET CONTAINER=$ORACLE_PDB;
      ALTER USER PDBADMIN IDENTIFIED BY "$ORACLE_PWD";
      exit;
EOF
# --- EOF -------------------------------------------------------------------