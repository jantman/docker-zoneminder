# =============================================================================
# Stage 1: Builder - Compile ZoneMinder 1.38.4 from source
# =============================================================================
FROM debian:13.6 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG ZM_VERSION=1.38.4
# zmeventnotificationNg. Normally a release tag of ZoneMinder/zmeventnotificationNg;
# repo and ref are both ARGs so a fork can be tested without editing the clone below.
#
# ###########################################################################
# # RELEASED AGAINST A FORK, DELIBERATELY. This points at                   #
# # jantman/zmeventnotificationNg @ issues/48, which is                     #
# # ZoneMinder/zmeventnotificationNg#49 -- Ready for review, not yet merged #
# # upstream. It restores the ES 6 join of config zone patterns onto        #
# # ZM-imported zone geometry by name, which is what lets objectconfig.yml  #
# # drop every hardcoded `coords:` line and set import_zm_zones: "yes".     #
# #                                                                         #
# # The SHA cannot move, but the commit would become UNREACHABLE once       #
# # issues/48 is deleted after merging, and the fetch below would fail. So  #
# # jantman/zmeventnotificationNg carries the annotated tag                 #
# # `image-pin-pr49` on this exact commit: a tag is a ref, so the commit    #
# # survives its branch. Do not delete that tag while any released image    #
# # pins this SHA.                                                          #
# #                                                                         #
# # Releases built this way carry the `-fork` version suffix. Repin to      #
# # ZoneMinder/zmeventnotificationNg at a release tag once #49 lands, and   #
# # drop the suffix.                                                        #
# ###########################################################################
ARG ZMES_REPO=https://github.com/jantman/zmeventnotificationNg.git
ARG ZMES_REF=50beae7d5f36f1d45a4b5505180e76685da9fc52

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

# Fetch the ZM Event Notification Server (ES 7 / zmeventnotificationNg) at a pinned ref.
# Done after the ZoneMinder build so bumping ZMES_REF does not invalidate the ZM
# compile cache.
#
# init + fetch rather than `clone --branch`, because --branch takes a ref NAME and this
# pins a commit SHA. Shallow-fetching one SHA keeps the clone as cheap as --depth 1 was;
# GitHub serves reachable SHAs to a want request.
RUN mkdir -p /src/zmeventnotification \
    && cd /src/zmeventnotification \
    && git init -q \
    && git remote add origin ${ZMES_REPO} \
    && git fetch -q --depth 1 origin ${ZMES_REF} \
    && git checkout -q FETCH_HEAD \
    && rm -rf /src/zmeventnotification/.git \
    # Prove the fork actually landed. ZMES carries no version string that would
    # distinguish issues/48 from the v7.0.29 tag, so without this a silently wrong
    # ref would ship an image whose only symptom is zone patterns quietly not
    # joining -- the exact failure mode of T094, which nothing signalled for a day.
    && grep -q "def normalize_zone_name" \
        /src/zmeventnotification/hook/zmes_hook_helpers/utils.py

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM debian:13.6

ENV ZM_DB_HOST=mariadb
ENV ZM_DB_NAME=zm
ENV ZM_DB_USER=zmuser
ENV ZM_DB_PASS=zmpass
ENV ZM_DB_SSL=no
# this is just a default
ENV TZ=America/New_York

ARG DEBIAN_FRONTEND=noninteractive
ARG GO2RTC_VERSION=v1.9.14
# pyzmNg publishes to PyPI under the name "pyzm"; the 2.x series is pyzmNg.
# The [ml] extra brings shapely (zone polygons, required by pyzm.ml.filters), numpy,
# Pillow, onnx and portalocker. Do NOT use [serve] or [full] - those pull inference
# machinery (ultralytics, fastapi) that this container must not have; it does no
# inference, and a local fallback would mask an outage of the pyzm.serve gateway.
#
# ###########################################################################
# # RELEASED AGAINST A FORK, DELIBERATELY. Normally "pyzm[ml]==<version>"   #
# # from PyPI. This installs from a fork instead:                           #
# #   jantman/pyzmNg @ integration/66-68, a merge of two open PRs:          #
# #     ZoneMinder/pyzmNg#69 (issues/68) -- zone_match_strategy. THIS is    #
# #       what this image needs. Zone filtering runs HERE, client-side, in  #
# #       pyzm.ml.filters via the hook -- not in the pyzm.serve gateway,    #
# #       whose /infer takes flat form fields and never sees a             #
# #       DetectorConfig. objectconfig.yml sets first_intersecting to       #
# #       restore ES 6 zone resolution.                                     #
# #     ZoneMinder/pyzmNg#67 (issues/66) -- GPU-fallback retry and the      #
# #       `processor` key on /models. Gateway-side; carried along only so   #
# #       this image and docker-pyzm-serve run one identical pyzm build.    #
# #                                                                        #
# # The SHA cannot move, but the commit would become UNREACHABLE once the   #
# # PR branches are deleted after merging, and pip could no longer fetch    #
# # it. jantman/pyzmNg carries the annotated tag `image-pin-pr67-pr69` on   #
# # this exact commit so it survives its branch; do not delete that tag     #
# # while any released image pins this SHA.                                 #
# #                                                                        #
# # Restore the PyPI pin once both PRs are released upstream, and drop the  #
# # `-fork` suffix from this image's version.                               #
# ###########################################################################
ARG PYZM_REPO=https://github.com/jantman/pyzmNg.git
ARG PYZM_REF=271bf98c33c28edca231c0f617d79887acd3a001
# ES 7 removed animation/GIF generation; the consuming hook re-implements it via
# Event.extract_frames(), which needs imageio.
ARG IMAGEIO_VERSION=2.37.4
ARG NEWRELIC_VERSION=13.4.0

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
        # ZMES-specific Perl modules (see upstream install.sh)
        libcrypt-mysql-perl \
        libcrypt-openssl-rsa-perl \
        libdbi-perl \
        libmodule-build-perl \
        libyaml-libyaml-perl \
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

# Install pyzmNg and the one ZMES Perl dependency Debian does not package
RUN pip install --break-system-packages \
        "pyzm[ml] @ git+${PYZM_REPO}@${PYZM_REF}" \
        "imageio==${IMAGEIO_VERSION}" \
        "newrelic==${NEWRELIC_VERSION}" \
    && cpanm -i 'Net::WebSocket::Server' \
    # Prove the pyzm fork landed. integration/66-68 does NOT bump the version, so
    # pip reports 2.5.1 either way and a fallback to the PyPI release would be
    # invisible -- including to the `pyzm:{}` version the hook logs at startup.
    # ZoneMatchStrategy exists only on ZoneMinder/pyzmNg#69.
    && python3 -c "from pyzm.models.config import ZoneMatchStrategy; \
assert ZoneMatchStrategy.FIRST_INTERSECTING.value == 'first_intersecting'" 

# Enable Apache modules
RUN a2enmod rewrite && a2enmod cgi && a2enmod headers && a2enmod expires

# Download go2rtc binary
RUN wget -q -O /usr/local/bin/go2rtc \
        https://github.com/AlexxIT/go2rtc/releases/download/${GO2RTC_VERSION}/go2rtc_linux_amd64 \
    && chmod +x /usr/local/bin/go2rtc

# Copy content files and the pinned ES 7 checkout from the builder stage
COPY ./content/ /tmp/
COPY --from=builder /src/zmeventnotification/ /tmp/zmeventnotification/

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
    # ES 7 split the event server into a ZmEventNotification::* Perl module tree that must
    # be on @INC. Version.pm carries a hardcoded fallback that upstream's install.sh
    # rewrites from the VERSION file; do the same so `zmeventnotification.pl --version`
    # does not report 7.0.0.
    && install -m 0755 -o root -g root -d /usr/share/perl5/ZmEventNotification \
    && install -m 0644 -o root -g root /tmp/zmeventnotification/ZmEventNotification/*.pm /usr/share/perl5/ZmEventNotification/ \
    && ES_VERSION="$(tr -d '[:space:]' < /tmp/zmeventnotification/VERSION)" \
    && sed -i "s/FALLBACK_VERSION = '[^']*'/FALLBACK_VERSION = '${ES_VERSION}'/" \
        /usr/share/perl5/ZmEventNotification/Version.pm \
    && grep -q "FALLBACK_VERSION = '${ES_VERSION}'" /usr/share/perl5/ZmEventNotification/Version.pm \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/pushapi_plugins/pushapi_pushover.py /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_event_start.sh /var/lib/zmeventnotification/bin/zm_event_start.sh \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_event_end.sh /var/lib/zmeventnotification/bin/zm_event_end.sh \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_detect.py /var/lib/zmeventnotification/bin/zm_detect.py \
    && install -m 0755 -o www-data -g www-data /tmp/zmeventnotification/hook/zm_train_faces.py /var/lib/zmeventnotification/bin/zm_train_faces.py \
    # Install the zmes_hook_helpers Python package (common_params, utils, push)
    && cd /tmp/zmeventnotification/hook && pip install --break-system-packages . \
    && rm -Rf /tmp/*

# Build-time smoke test. This repo has no test suite, so this is what stops a broken
# dependency set from ever being pushed. The first three checks are the consumer's
# verification block verbatim; the last two assert the CPU-only constraint.
RUN python3 -c "import pyzm, shapely, newrelic, imageio, cv2, numpy; print('pyzm', pyzm.__version__)" \
    && python3 -c "import zmes_hook_helpers.utils, zmes_hook_helpers.common_params, zmes_hook_helpers.push" \
    && /var/lib/zmeventnotification/bin/zm_detect.py --bareversion \
    && perl -MZmEventNotification::Version -e 'print "ES $ZmEventNotification::Version::VERSION\n"' \
    && test -x /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && python3 -c "import cv2, sys; sys.exit(0 if not hasattr(cv2, 'cuda') or cv2.cuda.getCudaEnabledDeviceCount() == 0 else 1)" \
    && ! pip list 2>/dev/null | grep -iE '^(torch|ultralytics|onnxruntime-gpu|nvidia-|opencv-python)'

VOLUME /var/cache/zoneminder
VOLUME /var/log/zm

# Copy entrypoint, make it executable and run it
COPY entrypoint.sh /opt/
RUN chmod +x /opt/entrypoint.sh

# "$@" must be quoted: unquoted, bash re-splits each argument on whitespace, which mangles
# any command containing spaces (e.g. python3 -c "import pyzm, cv2").
ENTRYPOINT [ "/bin/bash", "-c", "source ~/.bashrc && exec /opt/entrypoint.sh \"$@\"", "--" ]

EXPOSE 80
EXPOSE 9000
EXPOSE 1984
EXPOSE 8555
