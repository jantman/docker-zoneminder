#!/bin/bash -ex
# This is really only useful for me, but feel free to edit for your own purposes...

SQLDUMP=zm.sql
CONFDIR=/mnt/backup/rsnapshot/telescreen/daily.0/rsnapshot/etc/zm
VOLUMEDIR=/opt/zm-test

if [ "$EUID" -ne 0 ]
  then echo "Please run as root or via sudo"
  exit 1
fi

if [[ ! -e zm.sql ]]; then
  echo "Please retrieve zm.sql"
  exit 1
fi

if [[ -e events.tar.gz ]]; then
  echo "Using existing events.tar.gz"
  TARFILE=$(readlink -f events.tar.gz)
else
  echo "Please create events.tar.gz from backup, via something like: for i in $(ls -1 /var/cache/zoneminder/events/ | grep -E '^[0-9]+$'); do find /var/cache/zoneminder/events/${i}/$(date +%Y-%m-%d) -type d | sort | tail -1; done | xargs -0 tar -cjvf /tmp/zm-events.tar.bz2"
  exit 1
fi

[[ -e $VOLUMEDIR ]] || mkdir -p $VOLUMEDIR

if mysql -B -e 'SHOW DATABASES;' | grep -q '^zm$'; then
  # zm database already exists
  echo "ZM database already exists; not restoring"
else
  echo "Creating zm database"
  mysql -B -e 'CREATE DATABASE zm;'
  echo "Restoring sql dump to zm database"
  mysql -B zm < $SQLDUMP
fi

if [[ -e ${VOLUMEDIR}/etc ]]; then
  echo "${VOLUMEDIR}/etc already exists"
else
  cp -a ${CONFDIR} ${VOLUMEDIR}/etc
fi

if [[ -e ${VOLUMEDIR}/cache/events ]]; then
  echo "Events directory already exists"
else
  echo "Create events directory"
  mkdir -p ${VOLUMEDIR}/cache/{events,images,temp,cache}
  pushd ${VOLUMEDIR}/cache/events
  tar -xjvf $TARFILE
  popd
fi
