#!/bin/bash

set -o errexit

# Configure MariaDB client SSL globally so all callers (including zmupdate.pl) respect it
if [[ "${ZM_DB_SSL}" != "yes" ]]; then
    echo "ZM_DB_SSL is not 'yes'; configuring --skip-ssl globally for MariaDB client"
    printf '[client]\nskip-ssl\n' > /etc/mysql/mariadb.conf.d/99-skip-ssl.cnf
else
    rm -f /etc/mysql/mariadb.conf.d/99-skip-ssl.cnf
fi

# Ensure render group (GID 992) exists and www-data is a member, for VAAPI hardware acceleration
echo "Setting up render group for VAAPI hardware acceleration"
getent group render > /dev/null 2>&1 || groupadd -g 992 render
id -nG www-data | grep -qw render || usermod -aG render www-data

echo "Interpolating ZM_DB_* env vars into /etc/zm/zm.conf"
sed  -i "s|ZM_DB_HOST=.*|ZM_DB_HOST=${ZM_DB_HOST}|" /etc/zm/zm.conf
sed  -i "s|ZM_DB_NAME=.*|ZM_DB_NAME=${ZM_DB_NAME}|" /etc/zm/zm.conf
sed  -i "s|ZM_DB_USER=.*|ZM_DB_USER=${ZM_DB_USER}|" /etc/zm/zm.conf
sed  -i "s|ZM_DB_PASS=.*|ZM_DB_PASS=${ZM_DB_PASS}|" /etc/zm/zm.conf

# Returns true once mysql can connect.
mysql_ready() {
    mariadb-admin ping --host=$ZM_DB_HOST --user=$ZM_DB_USER --password=$ZM_DB_PASS > /dev/null 2>&1
}

# Ensure cache subdirectories exist (but do NOT recursive chown/chmod — too slow on large volumes)
mkdir -p /var/cache/zoneminder/{events,images,temp,cache}

echo "chown and chmod /etc/zm and /var/log/zm"
chown -R root:www-data /etc/zm
chown -R www-data:www-data /var/log/zm
chmod -R 770 /etc/zm /var/log/zm
[[ -e /run/zm ]] || install -m 0750 -o www-data -g www-data -d /run/zm

echo "Setting PHP timezone"
sed -i "s|;date\.timezone =.*|date.timezone = ${TZ}|" /etc/php/8.4/apache2/php.ini

echo "Setting up directories in /run tmpfs"
install -m 0755 -o root -g root -d /run/apache2
install -m 1777 -o root -g root -d /run/lock
install -m 0755 -o www-data -g www-data -d /run/zm /run/apache2/socks /run/lock/apache2

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

# Ensure database schema is up to date, then freshen config
DB_VERSION=$(mariadb -u$ZM_DB_USER -p$ZM_DB_PASS --host=$ZM_DB_HOST --batch --skip-column-names -e "SELECT Value FROM ${ZM_DB_NAME}.Config WHERE Name='ZM_DYN_DB_VERSION';" 2>/dev/null || echo "")

if [[ -n "$DB_VERSION" ]]; then
    echo "Database version: $DB_VERSION. Running zmupdate.pl to ensure schema is current..."
    su -c "zmupdate.pl --version=${DB_VERSION} -nointeractive" -s /bin/bash www-data
fi

echo "Running zmupdate.pl -f to freshen configuration..."
su -c 'zmupdate.pl -f' -s /bin/bash www-data

/usr/bin/s6-svscan /etc/services.d
