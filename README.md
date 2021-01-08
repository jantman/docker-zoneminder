# jantman/docker-zoneminder

Docker container for [zoneminder v1.32.3][3]

"ZoneMinder the top Linux video camera security and surveillance solution. ZoneMinder is intended for use in single or multi-camera video security applications, including commercial or home CCTV, theft prevention and child, family member or home monitoring and other domestic care scenarios such as nanny cam installations. It supports capture, analysis, recording, and monitoring of video data coming from one or more video or network cameras attached to a Linux system. ZoneMinder also support web and semi-automatic control of Pan/Tilt/Zoom cameras using a variety of protocols. It is suitable for use as a DIY home video security system and for commercial or professional video security and surveillance. It can also be integrated into a home automation system via X.10 or other protocols. If you're looking for a low cost CCTV system or a more flexible alternative to cheap DVR systems then why not give ZoneMinder a try?"

## Differences from upstream QuantumObject/docker-zoneminder

This repo/image is forked from [QuantumObject/docker-zoneminder](https://github.com/QuantumObject/docker-zoneminder) / [quantumobject/docker-zoneminder](https://hub.docker.com/r/quantumobject/docker-zoneminder) for my own purposes. The differences are as follows:

* cambozola has been removed, as I don't use it
* zmeventnotification.pl is being used at version 6.0.6
* Apache2 mod_headers is enabled, so you can set CORS headers if you need
* Various database changes, with the assumption that you're creating the initial database and users outside of this image/container:
  * the ZM database name, user, and password are set in ``/etc/zm/zm.conf`` at startup
  * ``mysqladmin ping`` is changed to use the ZM user and password, instead of the MySQL root user and password
  * MySQL root user and password are no longer needed
* improvements to the config copying/linking process, for existing configurations; link in ``zmeventnotification_secrets.ini`` and apache2 ``zoneminder.conf`` if present
* run ``zmupdate.pl -nointeractive`` on _every_ start up, to gracefully handle ZM upgrades

### WARNING - Automatic Database Upgrades

This image runs ``zmupdate.pl -nointeractive`` on every startup, to upgrade the ZoneMinder MySQL database when the ZM version (Docker image version) is updated. This could potentially be dangerous. It's assumed that you're (1) regularly backing up your database, (2) backing up your database before updating the image, and (3) using a specific tag version of the image, to ensure that updates only happen intentionally.

## Install dependencies

- [Docker][2]

To install docker in Ubuntu 18.04 use the commands:

```bash
sudo apt-get update
sudo wget -qO- <https://get.docker.com/> | sh
```

 To install docker in other operating systems check [docker online documentation][4]

## Usage

To run with MySQL in a separate container use the command below:

```bash
docker network create net
docker run -d -e TZ=America/New_York -e MYSQL_USER=zmuser -e MYSQL_PASSWORD=zmpass -e MYSQL_DATABASE=zm -e MYSQL_ROOT_PASSWORD=mysqlpsswd -e MYSQL_ROOT_HOST=% --net net --name db mysql/mysql-server:5.7
echo "wait until MySQL startup..."
docker run -d --shm-size=4096m -e TZ=America/New_York -e ZM_DB_HOST=db --net net --name zm -p 80:80 quantumobject/docker-zoneminder
```

## Set the timezone per environment variable

    -e TZ=Europe/London

or in yml:

  environment:

     - TZ=Europe/London

Default value is America/New_York .

## Accessing the Zoneminder applications

After that check with your browser at addresses plus the port assigned by docker:

- <http://host_ip:port/zm/>

Them log in with login/password : admin/admin , Please change password right away and check on-line [documentation][6] to configure zoneminder.

note: ffmpeg was added and path for it is /usr/bin/ffmpeg  if needed for configuration at options .

and if you change System=> "Authenticate user logins to ZoneMinder" you at this moment need to change "Method used to relay authentication information " to "None" if this not done you will be unable to see live view. This only recommended if you are using https to protect password(This relate to a misconfiguration or problem with this container still trying to find a better solutions).

if timeline fail please check TimeZone at php.ini is the correct one for your server( default is America/New York).

To access the container from the server that the container is running :

$ docker exec -it container_id /bin/bash

## Docker Swarm deployment

This projects is implemented to be deployed as docker-compose or swarm stack. Here an example of the docker swarm stack

```yml
version: '3.2'

services:
  db:
    image: mysql/mysql-server:5.7
    hostname: db
    networks:
      net:
        aliases:
          - db
    volumes:
      - $PWD/mysql:/var/lib/mysql
      - $PWD/conf/mysql:/etc/mysql:ro
    environment:
     - TZ=America/Argentina/Buenos_Aires
     - MYSQL_USER=zmuser
     - MYSQL_PASSWORD=zmpass
     - MYSQL_DATABASE=zm
     - MYSQL_ROOT_PASSWORD=mysqlpsswd
     - MYSQL_ROOT_HOST=%
    deploy:
      mode: replicated
      replicas: 1
      endpoint_mode: dnsrr
      restart_policy:
       condition: on-failure
       max_attempts: 3
       window: 120s
  web:
    image: quantumobject/docker-zoneminder
    networks:
      - net
    volumes:
      - /var/empty
      - $PWD/backups:/var/backups
      - $PWD/zoneminder:/var/cache/zoneminder
      - type: tmpfs
        target: /dev/shm
    environment:
     - TZ=America/Argentina/Buenos_Aires
     - VIRTUAL_HOST=zm.localhost, stream0.localhost
     - SERVICE_PORTS="80"
     - ZM_SERVER_HOST=node.0
     - ZM_DB_HOST=db
    deploy:
      mode: replicated
      replicas: 0
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
    depends_on:
      - db
  stream:
    image: quantumobject/docker-zoneminder
    networks:
      - net
    volumes:
      - /var/empty
      - $PWD/backups:/var/backups
      - $PWD/zoneminder:/var/cache/zoneminder
      - type: tmpfs
        target: /dev/shm
    environment:
     - TZ=America/Argentina/Buenos_Aires
     - VIRTUAL_HOST=stream{{.Task.Slot}}.localhost
     - SERVICE_PORTS="80"
     - ZM_SERVER_HOST=node.{{.Task.Slot}}
     - ZM_DB_HOST=db
    deploy:
      mode: replicated
      replicas: 0
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
    depends_on:
      - web
  lb:
    image: dockercloud/haproxy:1.6.7.1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - target: 80
        published: 80
        protocol: tcp
    networks:
      - net
    environment:
     - TZ=America/Argentina/Buenos_Aires
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
    depends_on:
      - node0
networks:
  net:
    driver: overlay
```

above docker-compose.yml stack example asume a directory structure at $PWD as is

```bash
$PWD/mysql      # (MySQL Data, drwxr-xr-x 6   27 27)
$PWD/zoneminder # (directory for images, drwxrwx--- 5 root 33)
$PWD/backup     # (directory for backups, drwxr-xr-x 2 root root)
$PWD/conf       # (configuration files, drwxrwxr-x  7 1000 1000, only conf/mysql/my.cnf is required)
cat conf/mysql/my.cnf
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/5.7/en/server-configuration-defaults.html

[mysqld]
#
# Remove leading # and set to the amount of RAM for the most important data
# cache in MySQL. Start at 70% of total RAM for dedicated server, else 10%.
# innodb_buffer_pool_size = 128M
#
# Remove leading # to turn on a very important data integrity option: logging
# changes to the binary log between backups.
# log_bin
#
# Remove leading # to set options mainly useful for reporting servers.
# The server defaults are faster for transactions and fast SELECTs.
# Adjust sizes as needed, experiment to find the optimal values.
# join_buffer_size = 128M
# sort_buffer_size = 2M
# read_rnd_buffer_size = 2M
skip-host-cache
skip-name-resolve
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
secure-file-priv=/var/lib/mysql-files
user=mysql

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
sql_mode = NO_ENGINE_SUBSTITUTION
max_connections = 500
```

to deploy above stack first initialize your swarm at least with one node for testing

```bash
docker swarm init
docker stack deploy -c docker-compose.yml zm
echo "wait for a few seconds to MySQL start for the first time"
docker service scale zm_web=1
echo "go to ZoneMinder console Options-Servers and declare node.0->stream0.localhost and node.1 ... node.3, finally start"
docker service scale zm_stream=3
docker service ls
```

the docker image used for load balancing is a modified version of dockercloud/haproxy specially targeted for
using {{.Task.Slot}} placeholder in DNS name resolution, see more details at

- <https://github.com/marcelo-ochoa/dockercloud-haproxy.git>

## More Info

About zoneminder [www.zoneminder.com][1]

To help improve this container [quantumobject/docker-zoneminder][5]

For additional info about us and our projects check our site [www.quantumobject.org][7]

[1]:http://www.zoneminder.com/
[2]:https://www.docker.com
[3]:http://www.zoneminder.com/downloads
[4]:http://docs.docker.com
[5]:https://github.com/QuantumObject/docker-zoneminder
[6]:http://www.zoneminder.com/wiki/index.php/Documentation
[7]:https://www.quantumobject.org
