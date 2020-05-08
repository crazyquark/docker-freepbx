#!/bin/bash -x

#https://docs.docker.com/engine/admin/multi-service_container/

/etc/init.d/mysql start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start mysql: $status"
  exit $status
fi

# Run the one time install if this is the first time we are running
if [ ! -f /etc/freepbx.conf ]; then
  pushd /usr/src/freepbx
  # Start an asterisk instance just for install
  ./start_asterisk start
  ./install -n
  status=$?
  
  if [ $status -ne 0 ]; then
    echo "Failed to install FreePBX: $status"
    exit $status
  fi

  fwconsole chown
  fwconsole ma upgradeall
  fwconsole ma downloadinstall backup pm2

  fwconsole chown
  fwconsole ma refreshsignatures
  fwconsole reload 
  
  # Stop asterisk post install
  echo 'Done installing FreePBX' && sleep 10
  ./start_asterisk kill
  popd
fi

# Restore backup if exists
if [ -f /backup/new.tgz ]; then
  echo "Restoring backup from /backup/new.tgz"
  php /var/www/html/admin/modules/backup/bin/restore.php --items=all --restore=/backup/new.tgz
  echo "Done"
  
  # Restart freepbx to load everything fine after restoring backup
  fwconsole stop
  status=$?
  if [ $status -ne 0 ]; then
    echo "Failed to restart fwconsole: $status"
    exit $status
  fi
fi

fwconsole start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start fwconsole: $status"
  exit $status
fi

/etc/init.d/apache2 start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start apache2: $status"
  exit $status
fi

/run/backup.sh &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start backup.sh: $status"
  exit $status
fi

/run/delete-old-recordings.sh &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start delete-old-recordings: $status"
  exit $status
fi

while /bin/true; do
  ps aux |grep mysqld |grep -q -v grep
  MYSQL_STATUS=$?
  ps aux |grep asterisk |grep -q -v grep
  ASTERISK_STATUS=$?
  ps aux |grep '/run/backup.sh' |grep -q -v grep
  BACKUPSCRIPT_STATUS=$?

  echo "Checking running processes..."
  if [ $MYSQL_STATUS -ne 0 -o $ASTERISK_STATUS -ne 0 -o $BACKUPSCRIPT_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    exit -1
  fi
  echo "OK"
  sleep 60
done