#!/bin/bash

set -o errexit

echo "Interpolating ZM_DB_* env vars into /etc/zm/zm.conf"
sed  -i "s|ZM_DB_HOST=.*|ZM_DB_HOST=${ZM_DB_HOST}|" /etc/zm/zm.conf
sed  -i "s|ZM_DB_NAME=.*|ZM_DB_NAME=${ZM_DB_NAME}|" /etc/zm/zm.conf
sed  -i "s|ZM_DB_USER=.*|ZM_DB_USER=${ZM_DB_USER}|" /etc/zm/zm.conf
sed  -i "s|ZM_DB_PASS=.*|ZM_DB_PASS=${ZM_DB_PASS}|" /etc/zm/zm.conf

# Returns true once mysql can connect.
mysql_ready() {
    mariadb-admin ping --host=$ZM_DB_HOST --user=$ZM_DB_USER --password=$ZM_DB_PASS > /dev/null 2>&1
}

# check if Directory inside of /var/cache/zoneminder are present.
if [ ! -d /var/cache/zoneminder/events ]; then
    echo "Creating /var/cache/zoneminder subdirectories and setting permissions"
    mkdir -p /var/cache/zoneminder/{events,images,temp,cache}
    chown -R root:www-data /var/cache/zoneminder
    chmod -R 770 /var/cache/zoneminder
fi

echo "chown and chmod /etc/zm and /var/log/zm"
chown -R root:www-data /etc/zm /var/log/zm
chmod -R 770 /etc/zm /var/log/zm

# waiting for mysql
echo "Pinging MySQL database server"
while !(mysql_ready); do
    >&2 echo "MariaDB not answering ping yet; try again in 3s..."
    sleep 3
done

# check if database is empty and fill it if necessary
echo "Checking count of tables in ${ZM_DB_NAME} database"
EMPTYDATABASE=$(mariadb -u$ZM_DB_USER -p$ZM_DB_PASS --host=$ZM_DB_HOST --batch --skip-column-names -e "use ${ZM_DB_NAME} ; show tables;" | wc -l )
echo "Database has ${EMPTYDATABASE} tables"

if [[ $EMPTYDATABASE != 0 ]]; then
    echo 'Database already configured.'
else
    if [[ "${ZM_DB_NAME}" != "zm" ]]; then
        # if ZM_DB_NAME different that zm
        echo "Interpolating database name into /usr/share/zoneminder/db/zm_create.sql"
        cp /usr/share/zoneminder/db/zm_create.sql /usr/share/zoneminder/db/zm_create.sql.bak
        sed -i "s|-- Host: localhost Database: .*|-- Host: localhost Database: ${ZM_DB_NAME}|" /usr/share/zoneminder/db/zm_create.sql
        sed -i "s|-- Current Database: .*|-- Current Database: ${ZM_DB_NAME}|" /usr/share/zoneminder/db/zm_create.sql
        sed -i "s|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ .*|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ \`${ZM_DB_NAME}\` \;|" /usr/share/zoneminder/db/zm_create.sql
        sed -i "s|USE .*|USE ${ZM_DB_NAME} \;|" /usr/share/zoneminder/db/zm_create.sql
        cp /usr/share/zoneminder/db/triggers.sql /usr/share/zoneminder/db/triggers.sql.bak
        sed -i "s|-- Host: localhost Database: .*|-- Host: localhost Database: ${ZM_DB_NAME}|" /usr/share/zoneminder/db/triggers.sql
        sed -i "s|-- Current Database: .*|-- Current Database: ${ZM_DB_NAME}|" /usr/share/zoneminder/db/triggers.sql
        sed -i "s|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ .*|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ \`${ZM_DB_NAME}\` \;|" /usr/share/zoneminder/db/triggers.sql
        sed -i "s|USE .*|USE ${ZM_DB_NAME} \;|" /usr/share/zoneminder/db/triggers.sql
    fi

    # prep the database for zoneminder
    echo "Executing /usr/share/zoneminder/db/zm_create.sql to create database"
    mariadb -u $ZM_DB_USER -p$ZM_DB_PASS -h $ZM_DB_HOST $ZM_DB_NAME < /usr/share/zoneminder/db/zm_create.sql
    # create triggers
    echo "Executing /usr/share/zoneminder/db/triggers.sql to set up database triggers"
    mariadb -u $ZM_DB_USER -p$ZM_DB_PASS -h $ZM_DB_HOST $ZM_DB_NAME < /usr/share/zoneminder/db/triggers.sql
fi

zmupdate.pl -f
rm -rf /var/run/zm/*

/lib/systemd/systemd
