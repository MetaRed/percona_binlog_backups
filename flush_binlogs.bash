#!/bin/bash
# set -xv
# Mysql flush logs
# This will flush binlogs ever hour
# Written By : Richard Lopez
# Date : Dev 16th, 2013
#

# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
EMAIL=kahuna@meta.red
SERVER_NAME=$(hostname --fqdn)
PORT=3306
USERNAME=mysql_flush_user
PASSWORD=mysql_flush_user_pass
LOG_DIR=/path/to/backup/log/dir

# email function
notify_email(){
  mail -s "${0}: failed on ${SERVER_NAME}" $EMAIL
}

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" | notify_email
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" | notify_email
    exit 1
  fi
fi

# Run the Sql
mysql -u $USERNAME mysql --password=$PASSWORD  -P $PORT --skip-column-names -e "flush logs;"
if [ ! $? -eq 0 ]; then
    echo "Unable to flush mysql bin-logs: $LOG_DIR" | notify_email
    exit 1
fi

echo "flush complete: $(date)"
exit 0
