# =============================================================================
# Stage 1: Builder - Compile ZoneMinder 1.38.0 from source
# =============================================================================
FROM debian:13.3 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG ZM_VERSION=1.38.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        # Build tools
        build-essential \
        cmake \
        git \
        pkg-config \
        # Required libraries
        libjpeg62-turbo-dev \
        default-libmysqlclient-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libavcodec-dev \
        libavdevice-dev \
        libavfilter-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        libswscale-dev \
        libbz2-dev \
        zlib1g-dev \
        # Optional but recommended
        libpcre2-dev \
        libvlc-dev \
        libvncserver-dev \
        libv4l-dev \
        libmosquittopp-dev \
        libgsoap-dev \
        gsoap \
        nlohmann-json3-dev \
        libunwind-dev \
        # Perl (needed for cmake checks and ZM Perl modules)
        perl \
        libdate-manip-perl \
        libdbd-mysql-perl \
        libphp-serialization-perl \
        libsys-mmap-perl \
        libwww-perl \
        libdata-uuid-perl \
        libcrypt-eksblowfish-perl \
        libdata-entropy-perl \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --branch ${ZM_VERSION} --depth 1 --recurse-submodules \
        https://github.com/ZoneMinder/zoneminder.git /src/zoneminder

WORKDIR /src/zoneminder

RUN cmake \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_SKIP_RPATH=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DZM_WEB_USER=www-data \
        -DZM_WEB_GROUP=www-data \
        -DZM_CONFIG_DIR=/etc/zm \
        -DZM_CONFIG_SUBDIR=/etc/zm/conf.d \
        -DZM_RUNDIR=/run/zm \
        -DZM_SOCKDIR=/run/zm \
        -DZM_TMPDIR=/tmp/zm \
        -DZM_LOGDIR=/var/log/zm \
        -DZM_WEBDIR=/usr/share/zoneminder/www \
        -DZM_CGIDIR=/usr/lib/zoneminder/cgi-bin \
        -DZM_CACHEDIR=/var/cache/zoneminder \
        -DZM_CONTENTDIR=/var/lib/zoneminder \
        -DZM_DIR_EVENTS=/var/cache/zoneminder/events \
        -DZM_SYSTEMD=OFF \
        -DBUILD_MAN=OFF \
        -DZM_NO_X10=ON \
        . \
    && make -j$(nproc) \
    && make DESTDIR=/zminstall install

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM debian:13.3

ENV ZM_DB_HOST=mariadb
ENV ZM_DB_NAME=zm
ENV ZM_DB_USER=zmuser
ENV ZM_DB_PASS=zmpass
ENV ZM_DB_SSL=no
# this is just a default
ENV TZ=America/New_York

ARG DEBIAN_FRONTEND=noninteractive
ARG GO2RTC_VERSION=v1.9.14

# Install runtime dependencies
RUN apt-get update \
    && apt-get upgrade --yes \
    && apt-get install --yes --no-install-recommends \
        # Web server and PHP
        apache2 \
        libapache2-mod-php \
        php \
        php-mysql \
        php-gd \
        php-apcu \
        php-intl \
        php-xml \
        php-curl \
        # Media
        ffmpeg \
        gifsicle \
        # Database client
        mariadb-client \
        # Process supervision
        s6 \
        # Tools
        wget \
        git \
        gnupg2 \
        sudo \
        zip \
        javascript-common \
        arp-scan \
        net-tools \
        iproute2 \
        tzdata \
        ca-certificates \
        # ZMES build deps (needed for cpanm and pip install)
        build-essential \
        cpanminus \
        python3-pip \
        python3-requests \
        python3-opencv \
        # Perl runtime modules for ZoneMinder
        libdate-manip-perl \
        libdatetime-perl \
        libdbd-mysql-perl \
        libphp-serialization-perl \
        libsys-mmap-perl \
        libwww-perl \
        liburi-perl \
        libdata-dump-perl \
        libdata-uuid-perl \
        libcrypt-eksblowfish-perl \
        libcryptx-perl \
        libdata-entropy-perl \
        libfile-slurp-perl \
        libnumber-bytes-human-perl \
        libsys-cpu-perl \
        libsys-meminfo-perl \
        libclass-std-fast-perl \
        libsoap-wsdl-perl \
        libio-socket-multicast-perl \
        libio-socket-ssl-perl \
        libdigest-sha-perl \
        libmime-lite-perl \
        libmime-tools-perl \
        libmodule-load-conditional-perl \
        libnet-sftp-foreign-perl \
        libarchive-zip-perl \
        libdevice-serialport-perl \
        libimage-info-perl \
        libio-interface-perl \
        libjson-maybexs-perl \
        liburi-encode-perl \
        # ZMES-specific Perl modules
        libconfig-inifiles-perl \
        libcrypt-mysql-perl \
        libmodule-build-perl \
        libyaml-perl \
        libjson-perl \
        liblwp-protocol-https-perl \
        # Shapely/GEOS for ZMES object detection hooks
        libgeos-dev \
        # VAAPI hardware acceleration
        intel-media-va-driver \
        # Shared libraries needed by ZM binaries
        libjpeg62-turbo \
        libpcre2-8-0 \
        libmosquittopp1 \
        libunwind8 \
        libgsoap-2.8.135 \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled ZoneMinder from builder
COPY --from=builder /zminstall /

# Create ZM directories and set permissions (normally done by Debian package postinst)
RUN mkdir -p /etc/zm/conf.d \
    && mkdir -p /var/cache/zoneminder/{events,images,temp,cache} \
    && mkdir -p /var/log/zm \
    && mkdir -p /var/lib/zoneminder \
    && mkdir -p /run/zm \
    && mkdir -p /tmp/zm \
    && chown -R root:www-data /etc/zm \
    && chown -R www-data:www-data /var/cache/zoneminder /var/log/zm /var/lib/zoneminder /run/zm /tmp/zm \
    && chmod -R 770 /etc/zm /var/log/zm

# Install pyzm and ZMES Perl dependency
RUN pip install --break-system-packages pyzm \
    && cpanm -i 'Net::WebSocket::Server'

# Enable Apache modules
RUN a2enmod rewrite && a2enmod cgi && a2enmod headers && a2enmod expires

# Download go2rtc binary
RUN wget -q -O /usr/local/bin/go2rtc \
        https://github.com/AlexxIT/go2rtc/releases/download/${GO2RTC_VERSION}/go2rtc_linux_amd64 \
    && chmod +x /usr/local/bin/go2rtc

# Copy content files
COPY ./content/ /tmp/

# Install config files, s6 services, ZMES files
RUN install -m 0644 -o root -g root /tmp/zm-site.conf /etc/apache2/sites-available/zm-site.conf \
    && install -m 0644 -o www-data -g www-data /tmp/zmcustom.conf /etc/zm/conf.d/zmcustom.conf \
    && install -m 0644 -o root -g root /tmp/status.conf /etc/apache2/mods-available/status.conf \
    && install -m 0644 -o root -g root /tmp/go2rtc.yaml /etc/zm/go2rtc.yaml \
    # s6 service directories
    && install -m 0755 -o root -g root -d /etc/services.d /etc/services.d/zoneminder /etc/services.d/apache2 /etc/services.d/go2rtc \
    && install -m 0755 -o root -g root /tmp/zoneminder-run /etc/services.d/zoneminder/run \
    && install -m 0755 -o root -g root /tmp/zoneminder-finish /etc/services.d/zoneminder/finish \
    && install -m 0755 -o root -g root /tmp/apache2-run /etc/services.d/apache2/run \
    && install -m 0755 -o root -g root /tmp/go2rtc-run /etc/services.d/go2rtc/run \
    # Apache site config
    && a2dissite 000-default \
    && a2ensite zm-site \
    # ZMES directories and files
    && bash -c 'install -m 0755 -o www-data -g www-data -d /var/lib/zmeventnotification /var/lib/zmeventnotification/{bin,contrib,images,mlapi,known_faces,unknown_faces,misc,push}' \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/zmeventnotification.pl /usr/bin/zmeventnotification.pl \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/pushapi_plugins/pushapi_pushover.py /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_event_start.sh /var/lib/zmeventnotification/bin/zm_event_start.sh \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_event_end.sh /var/lib/zmeventnotification/bin/zm_event_end.sh \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_detect.py /var/lib/zmeventnotification/bin/zm_detect.py \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_train_faces.py /var/lib/zmeventnotification/bin/zm_train_faces.py \
    # Install ZMES hook helpers Python package and newrelic
    && pip install --break-system-packages newrelic \
    && cd /tmp/zmeventnotification/hook && pip -v install --break-system-packages . \
    && rm -Rf /tmp/*

VOLUME /var/cache/zoneminder
VOLUME /var/log/zm

# Copy entrypoint, make it executable and run it
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT [ "/bin/bash", "-c", "source ~/.bashrc && /opt/entrypoint.sh ${@}", "--" ]

EXPOSE 80
EXPOSE 9000
EXPOSE 1984
EXPOSE 8555
