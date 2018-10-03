# OraDBA Initialization Scripts

Setup and initialization scripts for Oracle environments on Docker, Vagrant
boxes or standalone installations. They are especially used in my GitHub 
repositories [oehrlis/docker](https://github.com/oehrlis/docker), 
[oehrlis/docker-database](https://github.com/oehrlis/docker-database) and
[oehrlis/vagrant-boxes](https://github.com/oehrlis/vagrant-boxes) for 
installation and configuration.

A few hints and rules for using the scripts:

* The scripts can be executed individually or sequentially.
* For a complete setup they have to be executed in sequence.
* Scripts with the same prefix are usually variants and mutually exclusive. e.g. you run either ``00_setup_os_db.sh``  or ``00_setup_os_oud.sh``.
* The configuration and parameterization is done via environment variables. The scripts do use default values which can be overwritten by setting the corresponding environment variables. e.g. default ORACLE_DATA is set to ``/u01`` if an alternative path should be used ORACLE_DATA has to be set prior executing the scripts.

## Scripts

Scripts are located in the *bin* folder.

| Script                                             | Runas  | Description                                                                             |
| -------------------------------------------------- | ------ | --------------------------------------------------------------------------------------- |
| [00_setup_os_db.sh](bin/00_setup_os_db.sh)         | root   | Script to configure Oracle Enterprise Linux for Oracle Database installations.          |
| [00_setup_os_oud.sh](bin/00_setup_os_oud.sh)       | root   | Script to configure Oracle Enterprise Linux for Oracle Unified Directory installations. |
| [01_setup_db_11.2.sh](bin/01_setup_db_11.2.sh)     | oracle | Script to install Oracle Database 11.2.0.4                      |
| [01_setup_db_12.1.sh](bin/01_setup_db_12.1.sh)     | oracle | Script to install Oracle Database 12.1.0.2                      |
| [01_setup_db_12.2.sh](bin/01_setup_db_12.2.sh)     | oracle | Script to install Oracle Database 12.2.0.1                      |
| [01_setup_db_18.3.sh](bin/01_setup_db_18.3.sh)     | oracle | Script to install Oracle Database 18.3.0.0                      |
| [01_setup_oud_11g.sh](bin/01_setup_oud_11g.sh)     | oracle | Script to install Oracle Unified Directory 11g                  |
| [01_setup_oud_12c.sh](bin/01_setup_oud_12c.sh)     | oracle | Script to install Oracle Unified Directory 12c                  |
| [01_setup_oudsm_12c.sh](bin/01_setup_oudsm_12c.sh) | oracle | Script to install Oracle Unified Directory Service Manager 12c  |
| [02_setup_basenv.sh](bin/02_setup_basenv.sh)       | oracle | Script to setup and configure TVD-Basenv                        |
| [02_setup_oudbase.sh](bin/02_setup_oudbase.sh)     | oracle | Script to setup and configure OUD Base                          |

## Response Files

Response files are located in the *rsp* folder.

| Response file                                      | Description                                            |
| -------------------------------------------------- | ------------------------------------------------------ |
| [base_install.rsp.tmpl](rsp/base_install.rsp.tmpl) | Response file for Trivadis BasEnv installation         |
| [oud_install.rsp.tmpl](rsp/oud_install.rsp.tmpl)   | Generic response file for OUD and OUDSM installations  |
| [db_install.rsp.tmpl](rsp/db_install.rsp.tmpl)     | Response file for Oracle database binary installations |

## Install the Scripts

The scripts can be downloaded directly from GitHub. Usually done to ``/tmp`` folder and extracted to ``/opt``.

```bash
curl -f https://codeload.github.com/oehrlis/oradba_init/zip/master -o /tmp/oradba_init.zip
unzip -o /tmp/oradba_init.zip -d /opt
mv /opt/oradba_init-master /opt/oradba
mv /opt/oradba/README.md /opt/oradba/doc
rm -rf /tmp/oradba_init.zip
```

Start using the Scripts.

```bash
cd /opt/oradba/bin
```

## Todo

* java install script
* unique patch script for all
* start script for java after oud
* start patch after oud or db
