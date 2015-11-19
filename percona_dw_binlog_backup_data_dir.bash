#!/bin/bash
# set -xv
# This is for Mysql Database BinLog Backup
# Written By : Richard Lopez
# Date : Jan 30th, 2013


# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
DATE=$(date +%Y%m%d)
EMAIL=kahuna@meta.red
LOCAL_BACKUP_DIR=/path/to/backup/dir
BINLOG_DIR=/path/to/mysql-bin
SERVER_NAME=$(hostname --fqdn)
USERNAME=mysql_backup_user
PASSWORD=mysql_backup_user_pass
LOG_DIR=/var/log/fx/percona_prod_database_backup/
BACKUP_LOG=${LOG_DIR}/mysql_binlog_backup_info.log
S3_BUCKET="s3://s3-link/bucket/"

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
    exit 1
  fi
fi

# make sure our local backup directory exists and is writable
if [ ! -d $LOCAL_BACKUP_DIR ]; then
   mkdir -p $LOCAL_BACKUP_DIR
   chown mysql.mysql $LOCAL_BACKUP_DIR
   if [ ! $? -eq 0 ]; then
      echo "Unable to create backup dir: $LOCAL_BACKUP_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
      exit 1
   fi
else
   touch $LOCAL_BACKUP_DIR/test
   rm $LOCAL_BACKUP_DIR/test
   if [ ! $? -eq 0 ]; then
      echo "Unable to write to backup dir: $LOCAL_BACKUP_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
      exit 1
   fi
fi

# make sure our local binlog directory is writable
touch $BINLOG_DIR/test
rm $BINLOG_DIR/test
   if [ ! $? -eq 0 ]; then
      echo "Unable to write to binlog dir: ${BINLOG_DIR}" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
      exit 1
   fi

# GET THE CURRENT BINLOG FILE USED BY MYSQL
BINLOG_IN_USE=$(/usr/bin/mysql -N -s -u $USERNAME -p$PASSWORD -e "SHOW MASTER STATUS" | /usr/bin/awk '{ print $1 }')

# SAVE ALL BINLOG FILES CREATED IN THE LAST HOUR TO THE BACKUP FOLDER AND ARCHIVE THEM
# DO NOT INCLUDE THE BINLOG FILE CURRENTLY USED BY MYSQL OR THE mysql-bin.index FILE
cd ${BINLOG_DIR}
for i in $(find . -type f ! -name ${BINLOG_IN_USE} ! -name mysql-bin.index ! -mmin +59 | cut -d/ -f2); do      

rsync -av --progress $i ${LOCAL_BACKUP_DIR}
     if [ ! $? -eq 0 ]; then
        echo "Unable to rsync binlog $i from binlog dir: ${BINLOG_DIR} to backup dir: ${LOCAL_BACKUP_DIR}" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
        exit 1
     fi
cd ${LOCAL_BACKUP_DIR}
TIMESTAMP=$(stat -c %y $i | awk '{ print $2 }' | cut -d. -f1 | awk -F: '{ print $1 $2 }')
BINLOG_NUM=$(echo $i | cut -d. -f2)
tar --remove-files -I pigz -cvf ${SERVER_NAME}-${DATE}-${TIMESTAMP}-binlog-${BINLOG_NUM}.tar.gz $i
  if [ ! $? -eq 0 ]; then
     echo "Unable create binlog archive of $i on backup dir: ${LOCAL_BACKUP_DIR}" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
     exit 1
  fi
chown fxsync:fxsync ${SERVER_NAME}-${DATE}-${TIMESTAMP}-binlog-${BINLOG_NUM}.tar.gz
sudo -u fxsync -i aws s3 cp ${LOCAL_BACKUP_DIR}/${SERVER_NAME}-${DATE}-${TIMESTAMP}-binlog-${BINLOG_NUM}.tar.gz $S3_BUCKET
   if [ ! $? -eq 0 ]; then
       echo "Unable to copy backup file: ${LOCAL_BACKUP_DIR}/${SERVER_NAME}-${DATE}-${TIMESTAMP}-binlog-${BINLOG_NUM}.tar.gz to $S3_BUCKET" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
       exit 1
   fi
cd ${BINLOG_DIR}

done

cd ${LOCAL_BACKUP_DIR}
find ${LOCAL_BACKUP_DIR} -name "${SERVER_NAME}*-binlog-*.tar.gz" -mtime +15 -exec rm -f {} \;

exit 0
