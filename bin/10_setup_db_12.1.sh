#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 10_setup_db_12.1.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: wrapper script to install Oracle 12.1 databases binaries
# Notes......: Script just set the 12.1 specific variables an call 10_setup_db.sh
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
export DB_BASE_PKG=${DB_BASE_PKG:-"linuxamd64_12102_database_1of2.zip"}
export DB_BASE2_PKG=${DB_BASE2_PKG:-"linuxamd64_12102_database_2of2.zip"}
export DB_EXAMPLE_PKG=${DB_EXAMPLE_PKG:-""}
export DB_PATCH_PKG=${DB_PATCH_PKG:-"p29494060_121020_Linux-x86-64.zip"}
export DB_OJVM_PKG=${DB_OJVM_PKG:-"p29774383_121020_Linux-x86-64.zip"}
export DB_OPATCH_PKG=${DB_OPATCH_PKG:-"p6880880_121010_Linux-x86-64.zip"}
export RESPONSFILE_VERSION=${RESPONSFILE_VERSION:-"oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.1.0"}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"12.1.0.2"}
export ORACLE_MAJOR_RELEASE="121"

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
# - EOF Environment Variables -----------------------------------------------

# - Main --------------------------------------------------------------------
# call db installation script
${ORADBA_BIN}/10_setup_db.sh
# --- EOF --------------------------------------------------------------------