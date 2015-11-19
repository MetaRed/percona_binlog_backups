#!/bin/bash
# 
# backs up the db binlog, copies backups to local backup dir
# -RL

EMAIL=bigkahuna@meta.red
SERVER_NAME=$(hostname --fqdn)

# flush the binlog
# exit if this fails since we need backups.
/path/to/script/dir/flush_binlogs.bash
if [ ! $? -eq 0 ]; then
  echo "${0} exited with nonzero status" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi

# copy binlog to local backup directory
# exit if this fails, since we need backups...
/path/to/script/dir/percona_dw_binlog_backup_data_dir.bash
if [ ! $? -eq 0 ]; then
  echo "${0} exited with nonzero status" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi
