#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 10_setup_db_18.3.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: wrapper script to install Oracle 18.3 databases binaries
# Notes......: Script just set the 18.3 specific variables an call 10_setup_db.sh
#              to setup the DB binaries.
# Reference..: --
# License....: Licensed under the Universal Permissive License v 1.0 as 
#              shown at http://oss.oracle.com/licenses/upl.
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------
# - Environment Variables ---------------------------------------------------
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define the software packages
export DB_BASE_PKG=${DB_BASE_PKG:-"LINUX.X64_180000_db_home.zip"}
export DB_EXAMPLE_PKG=${DB_EXAMPLE_PKG:-"LINUX.X64_180000_examples.zip"}
export DB_PATCH_PKG=${DB_PATCH_PKG:-""}
export DB_OJVM_PKG=${DB_OJVM_PKG:-""}
export DB_OPATCH_PKG=${DB_OPATCH_PKG:-"p6880880_180000_Linux-x86-64.zip"}
export RESPONSFILE_VERSION=${RESPONSFILE_VERSION:-"oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v18.0.0"}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"18.3.0.0"}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
# - EOF Environment Variables -----------------------------------------------

# - Main --------------------------------------------------------------------
# call db installation script
${ORADBA_BIN}/10_setup_db.sh
# --- EOF --------------------------------------------------------------------