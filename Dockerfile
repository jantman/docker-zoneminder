# Base Image
FROM debian:12.2

ENV ZM_DB_HOST=mariadb
ENV ZM_DB_NAME=zm
ENV ZM_DB_USER=zmuser
ENV ZM_DB_PASS=zmpass

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update \
    && apt install --yes --no-install-recommends \
         build-essential \
         apache2 \
         libjson-perl \
         mariadb-client \
         s6 \
         zoneminder \
    && apt-get clean \
    && a2enmod rewrite \
    && a2enmod cgi

COPY ./content/ /tmp/

RUN install -m 0644 -o root -g root /tmp/zoneminder.conf /etc/apache2/sites-available/zoneminder.conf \
    && install -m 0644 -o www-data -g www-data /dev/null /etc/zm/conf.d/zmcustom.conf \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification.pl /usr/bin/zmeventnotification.pl \
    && install -m 0755 -o www-data -g www-data -d /var/lib/zmeventnotification /var/lib/zmeventnotification/push /var/lib/zmeventnotification/bin \
    && install -m 0755 -o www-data -g www-data /tmp/pushapi_pushover.py /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && rm -Rf /tmp/* \
    && a2ensite zoneminder

# zmeventnotification installation
RUN /usr/bin/perl -MCPAN -e "install Config::IniFiles" \
    && /usr/bin/perl -MCPAN -e "install Net::WebSocket::Server"

VOLUME /var/cache/zoneminder
VOLUME /var/log/zm

# Copy entrypoint make it as executable and run it
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT [ "/bin/bash", "-c", "source ~/.bashrc && /opt/entrypoint.sh ${@}", "--" ]

EXPOSE 80
EXPOSE 9000
