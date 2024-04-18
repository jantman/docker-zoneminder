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
         cpanminus \
         ffmpeg \
         gifsicle \
         git \
         gnupg2 \
         libapache2-mod-php \
         libconfig-inifiles-perl \
         libcrypt-mysql-perl \
         libcrypt-eksblowfish-perl \
         libmodule-build-perl \
         libyaml-perl \
         libjson-perl \
         liblwp-protocol-https-perl \
         libgeos-dev \
         lsb-release \
         mariadb-client \
         php \
         php-mysql \
         python3-pip \
         python3-requests \
         python3-opencv \
         s6 \
         wget \
         zoneminder \
    && /usr/bin/pip install --break-system-packages pyzm \
    && apt-get clean \
    && a2enmod rewrite \
    && a2enmod cgi \
    && a2enmod headers \
    && a2enmod expires

RUN /usr/bin/cpanm -i 'Net::WebSocket::Server'

COPY ./content/ /tmp/

RUN install -m 0644 -o root -g root /tmp/zm-site.conf /etc/apache2/sites-available/zm-site.conf \
    && install -m 0644 -o www-data -g www-data /tmp/zmcustom.conf /etc/zm/conf.d/zmcustom.conf \
    && install -m 0755 -o root -g root -d /etc/services.d /etc/services.d/zoneminder /etc/services.d/apache2 \
    && install -m 0755 -o root -g root /tmp/zoneminder-run /etc/services.d/zoneminder/run \
    && install -m 0755 -o root -g root /tmp/zoneminder-finish /etc/services.d/zoneminder/finish \
    && install -m 0755 -o root -g root /tmp/apache2-run /etc/services.d/apache2/run \
    && install -m 0644 -o root -g root /tmp/status.conf /etc/apache2/mods-available/status.conf \
    && a2dissite 000-default \
    && a2ensite zm-site \
    && bash -c 'install -m 0755 -o www-data -g www-data -d /var/lib/zmeventnotification /var/lib/zmeventnotification/{bin,contrib,images,mlapi,known_faces,unknown_faces,misc,push}' \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/zmeventnotification.pl /usr/bin/zmeventnotification.pl \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/pushapi_plugins/pushapi_pushover.py /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_event_start.sh /var/lib/zmeventnotification/bin/zm_event_start.sh \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_event_end.sh /var/lib/zmeventnotification/bin/zm_event_end.sh \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_detect.py /var/lib/zmeventnotification/bin/zm_detect.py \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_train_faces.py /var/lib/zmeventnotification/bin/zm_train_faces.py \
    && pip install --break-system-packages newrelic \
    && cd /tmp/zmeventnotification/hook && pip -v install --break-system-packages . \
    && rm -Rf /tmp/*

VOLUME /var/cache/zoneminder
VOLUME /var/log/zm

# Copy entrypoint make it as executable and run it
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT [ "/bin/bash", "-c", "source ~/.bashrc && /opt/entrypoint.sh ${@}", "--" ]

EXPOSE 80
EXPOSE 9000
