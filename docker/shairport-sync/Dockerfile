FROM alpine:3.20 AS build

ARG SHAIRPORT_SYNC_REF=5.6.3

RUN apk add --no-cache build-base autoconf automake libtool pkgconf git \
        avahi-dev ffmpeg-dev libconfig-dev openssl-dev popt-dev soxr-dev xxd

WORKDIR /src
COPY claim-play-lock-before-thread.patch /tmp/
RUN git clone https://github.com/mikebrady/shairport-sync.git . \
    && git checkout "${SHAIRPORT_SYNC_REF}" \
    && git apply /tmp/claim-play-lock-before-thread.patch \
    && autoreconf -i \
    && ./configure --sysconfdir=/etc --with-avahi --with-ssl=openssl --with-soxr \
        --with-metadata --with-pipe --with-stdout \
    && make \
    && make install DESTDIR=/out

FROM alpine:3.20

RUN apk add --no-cache avahi dbus libconfig popt soxr libcrypto3 \
        ffmpeg-libavcodec ffmpeg-libavformat ffmpeg-libavutil ffmpeg-libswresample \
    && rm -f /etc/avahi/services/*.service \
    && mkdir -p /run/dbus

COPY --from=build /out/usr/local/bin/shairport-sync /usr/local/bin/shairport-sync
COPY --from=build --chmod=755 /src/docker/classic/run.sh /run.sh

ENTRYPOINT ["/run.sh"]
