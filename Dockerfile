# Base Image
FROM debian:12.2

ENV ZM_DB_HOST=mariadb
ENV ZM_DB_NAME=zm
ENV ZM_DB_USER=zmuser
ENV ZM_DB_PASS=zmpass
# this is just a default
ENV TZ=America/New_York

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update \
    && apt-get upgrade --yes \
    && apt-get install --yes \
         apache2 \
         build-essential \
         ffmpeg \
         gnupg2 \
         libapache2-mod-php \
         libjson-perl \
         lsb-release \
         mariadb-client \
         php \
         php-mysql \
         python3-pip \
         python3-requests \
         s6 \
         zoneminder \
    && /usr/bin/pip install --break-system-packages pyzm \
    && apt-get clean \
    && a2enmod rewrite \
    && a2enmod cgi \
    && a2enmod headers \
    && a2enmod expires

# zmeventnotification installation
RUN /usr/bin/perl -MCPAN -e "install Config::IniFiles" \
    && /usr/bin/perl -MCPAN -e "install Net::WebSocket::Server"

COPY ./content/ /tmp/

RUN install -m 0644 -o root -g root /tmp/zm-site.conf /etc/apache2/sites-available/zm-site.conf \
    && install -m 0644 -o www-data -g www-data /tmp/zmcustom.conf /etc/zm/conf.d/zmcustom.conf \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification.pl /usr/bin/zmeventnotification.pl \
    && install -m 0755 -o www-data -g www-data -d /var/lib/zmeventnotification /var/lib/zmeventnotification/push /var/lib/zmeventnotification/bin \
    && install -m 0755 -o www-data -g www-data /tmp/pushapi_pushover.py /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && install -m 0755 -o root -g root -d /etc/services.d /etc/services.d/zoneminder /etc/services.d/apache2 \
    && install -m 0755 -o root -g root /tmp/zoneminder-run /etc/services.d/zoneminder/run \
    && install -m 0755 -o root -g root /tmp/zoneminder-finish /etc/services.d/zoneminder/finish \
    && install -m 0755 -o root -g root /tmp/apache2-run /etc/services.d/apache2/run \
    && rm -Rf /tmp/* \
    && a2dissite 000-default \
    && a2ensite zm-site

VOLUME /var/cache/zoneminder
VOLUME /var/log/zm

# Copy entrypoint make it as executable and run it
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT [ "/bin/bash", "-c", "source ~/.bashrc && /opt/entrypoint.sh ${@}", "--" ]

EXPOSE 80
EXPOSE 9000
