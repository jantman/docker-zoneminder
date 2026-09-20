FROM debian:13.6

ENV ZM_DB_HOST=mariadb
ENV ZM_DB_NAME=zm
ENV ZM_DB_USER=zmuser
ENV ZM_DB_PASS=zmpass
ENV ZM_DB_SSL=no
# this is just a default
ENV TZ=America/New_York

ARG DEBIAN_FRONTEND=noninteractive
# Full Debian version string of the official ZoneMinder package, not just the upstream
# version: the separator before the vendor suffix changed mid-series (1.38.0-trixie1 ..
# 1.38.2-trixie1, then 1.38.3+trixie1, 1.38.4+trixie1), so it cannot be reconstructed.
ARG ZM_VERSION=1.38.4+trixie1
# zmeventnotificationNg (ES 7). A release tag of ZoneMinder/zmeventnotificationNg.
# v7.0.30 released ZoneMinder/zmeventnotificationNg#49, which joins config zone
# patterns onto ZM-imported zone geometry by name -- what lets objectconfig.yml drop
# every hardcoded `coords:` line and set import_zm_zones: "yes". Images before
# 1.38.4-jantman2 carried that commit as a fork pin; do not pin below v7.0.30.
ARG ZMES_VERSION=v7.0.31
ARG GO2RTC_VERSION=v1.9.14
# pyzmNg publishes to PyPI under the name "pyzm"; the 2.x series is pyzmNg.
# The [ml] extra brings shapely (zone polygons, required by pyzm.ml.filters), numpy,
# Pillow, onnx and portalocker. Do NOT use [serve] or [full] - those pull inference
# machinery (ultralytics, fastapi) that this container must not have; it does no
# inference, and a local fallback would mask an outage of the pyzm.serve gateway.
#
# pyzmNg 2.5.2 released ZoneMinder/pyzmNg#69, which adds zone_match_strategy.
# This image is the side that needs it: zone filtering runs client-side here, in
# pyzm.ml.filters via the hook -- not in the pyzm.serve gateway, whose /infer takes
# flat form fields and never sees a DetectorConfig. objectconfig.yml sets
# first_intersecting to restore ES 6 zone resolution. Images before
# 1.38.4-jantman2 carried that commit as a fork pin; do not pin below 2.5.2.
ARG PYZM_VERSION=2.5.3
# ES 7 removed animation/GIF generation; the consuming hook re-implements it via
# Event.extract_frames(), which needs imageio.
ARG IMAGEIO_VERSION=2.37.4
ARG NEWRELIC_VERSION=13.4.0

# Add the official ZoneMinder 1.38 repository -- Debian's own zoneminder package is 1.36.x
# in trixie, forky and sid alike, so 1.38 comes only from here. Flat repo (trailing slash,
# no components). The key is scoped to this one source with signed-by rather than dropped
# into trusted.gpg.d, so it cannot vouch for Debian's own archives, and its fingerprint is
# hardcoded and asserted -- deliberately not an ARG, since overriding it would defeat the
# point -- so a substituted key fails the build instead of being trusted silently.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates wget gnupg2 \
    && install -m 0755 -d /etc/apt/keyrings \
    && wget -q -O /etc/apt/keyrings/zmrepo.asc \
        https://zmrepo.zoneminder.com/debian/archive-keyring.gpg \
    && gpg --show-keys --with-colons /etc/apt/keyrings/zmrepo.asc \
        | awk -F: '/^fpr:/{print $10}' | grep -qx E148DCEBF90919B49C68F056A8C670C86F88B031 \
    && chmod 0644 /etc/apt/keyrings/zmrepo.asc \
    && echo 'deb [signed-by=/etc/apt/keyrings/zmrepo.asc] https://zmrepo.zoneminder.com/debian/release-1.38 trixie/' \
        > /etc/apt/sources.list.d/zoneminder.list \
    && rm -rf /var/lib/apt/lists/*

# Satisfy two ZoneMinder Depends with a dummy package instead of the real thing.
#
#   policykit-1 | pkexec        -> pkexec -> polkitd -> libpam-systemd -> systemd
#   rsyslog | system-log-daemon -> rsyslog
#
# Neither is reachable in this image. zmsystemctl.pl is the only pkexec consumer (pkexec is
# its shebang), and zmpkg.pl only calls it when `ps -o comm= -p 1` reports systemd -- PID 1
# here is s6-svscan, so that branch never runs. Nothing logs to syslog either: ZoneMinder
# logs to /var/log/zm and the s6 services log to the container's stdout.
#
# policykit-1 and system-log-daemon are both pure virtual packages with no real provider,
# so Provides: on them satisfies the alternatives without shadowing or displacing anything
# real. Built with dpkg-deb rather than equivs: equivs pulls autoconf, groff-base, man-db
# and libmagic1t64, which survive an autoremove and cost more than the systemd they save.
RUN mkdir -p /tmp/zmdeps/DEBIAN \
    && printf '%s\n' \
        'Package: zoneminder-container-deps' \
        'Version: 1.0' \
        'Architecture: all' \
        'Maintainer: docker-zoneminder <none@example.com>' \
        'Provides: policykit-1, system-log-daemon' \
        'Section: misc' \
        'Priority: optional' \
        'Description: Satisfy ZoneMinder deps that are unreachable in this container' \
        ' Stands in for polkit and a syslog daemon; see the Dockerfile for why.' \
        > /tmp/zmdeps/DEBIAN/control \
    && dpkg-deb --build /tmp/zmdeps /tmp/zoneminder-container-deps.deb \
    && dpkg -i /tmp/zoneminder-container-deps.deb \
    && rm -rf /tmp/zmdeps /tmp/zoneminder-container-deps.deb

# Install ZoneMinder from the official package, plus the runtime dependencies that are ours
# rather than ZoneMinder's. Anything the zoneminder package already declares as a Depends is
# deliberately absent from this list -- the whole ZoneMinder Perl module wall, ffmpeg, sudo,
# zip, javascript-common, arp-scan, net-tools, iproute2, the php-* extensions, and the
# libav*/libjpeg/libmariadb/libmosquittopp/libgsoap/libjwt/libvncclient shared libraries.
# apache2 and libapache2-mod-php are only Recommends, so they stay explicit.
RUN apt-get update \
    && apt-get upgrade --yes \
    && apt-get install --yes --no-install-recommends \
        zoneminder=${ZM_VERSION} \
        # Web server and PHP
        apache2 \
        libapache2-mod-php \
        php \
        # Media
        gifsicle \
        # Database client: the entrypoint calls mariadb and mariadb-admin directly
        mariadb-client \
        # Process supervision
        s6 \
        # Tools
        git \
        tzdata \
        # ZMES build deps (needed for cpanm and pip install)
        build-essential \
        cpanminus \
        python3-pip \
        python3-requests \
        python3-opencv \
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
    && rm -rf /var/lib/apt/lists/*

# Fetch the ZM Event Notification Server (ES 7 / zmeventnotificationNg) at a pinned tag.
# Done after the package install so bumping ZMES_VERSION does not invalidate that layer.
RUN git clone --branch ${ZMES_VERSION} --depth 1 \
        https://github.com/ZoneMinder/zmeventnotificationNg.git /tmp/zmeventnotification \
    && rm -rf /tmp/zmeventnotification/.git

# Apply the ownership and modes this image has always used. This must run after the
# zoneminder package, whose postinst rewrites /etc/zm to its own preference of
# www-data:root 640. The entrypoint re-applies all of this at every start.
#
# The package ships /etc/zm/conf.d, /var/log/zm and all four /var/cache/zoneminder
# subdirectories itself, so only /run/zm has to be created -- it comes from tmpfiles.d,
# which needs a systemd this image deliberately does not have. /var/tmp/zm (the package's
# ZM_TMPDIR, backing ZM_DIR_EXPORTS and ZM_PATH_SWAP) is deliberately not created either:
# zmpkg.pl's verifyFolder() mkdirs it at every start.
RUN install -m 0750 -o www-data -g www-data -d /run/zm \
    && chown -R root:www-data /etc/zm \
    && chown -R www-data:www-data /var/cache/zoneminder /var/log/zm \
    && chmod -R 770 /etc/zm /var/log/zm

# Install pyzmNg and the one ZMES Perl dependency Debian does not package
RUN pip install --break-system-packages \
        "pyzm[ml]==${PYZM_VERSION}" \
        "imageio==${IMAGEIO_VERSION}" \
        "newrelic==${NEWRELIC_VERSION}" \
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
# dependency set from ever being pushed. The first five checks cover ZMES and its consumer's
# verification block; the next two assert the CPU-only constraint; the last three assert
# what installing ZoneMinder from the package is for -- a fresh database seeded with ffmpeg
# enabled, and no init system, policy daemon, message bus or syslog daemon dragged in
# behind it.
RUN python3 -c "import pyzm, shapely, newrelic, imageio, cv2, numpy; print('pyzm', pyzm.__version__)" \
    && python3 -c "import zmes_hook_helpers.utils, zmes_hook_helpers.common_params, zmes_hook_helpers.push" \
    && /var/lib/zmeventnotification/bin/zm_detect.py --bareversion \
    && perl -MZmEventNotification::Version -e 'print "ES $ZmEventNotification::Version::VERSION\n"' \
    && test -x /var/lib/zmeventnotification/bin/pushapi_pushover.py \
    && python3 -c "import cv2, sys; sys.exit(0 if not hasattr(cv2, 'cuda') or cv2.cuda.getCudaEnabledDeviceCount() == 0 else 1)" \
    && ! pip list 2>/dev/null | grep -iE '^(torch|ultralytics|onnxruntime-gpu|nvidia-|opencv-python)' \
    && grep -q "'ZM_OPT_FFMPEG', Value = '1'" /usr/share/zoneminder/db/zm_create.sql \
    && ! dpkg-query -W -f='${Package} ${Status}\n' systemd systemd-sysv polkitd pkexec rsyslog dbus 2>/dev/null | grep -q 'install ok installed' \
    && test ! -e /sbin/init

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
