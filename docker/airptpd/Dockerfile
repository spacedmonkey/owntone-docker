FROM alpine:3.20 AS build

ARG LIBAIRPTP_REF=0.7

RUN apk add --no-cache build-base autoconf automake pkgconf libevent-dev git libcap-setcap

WORKDIR /src
RUN git clone https://github.com/owntone/libairptp.git . \
    && git checkout "${LIBAIRPTP_REF}" \
    && autoreconf -vi \
    && ./configure --enable-daemon --prefix=/usr \
    && make \
    && make install-strip DESTDIR=/out \
    && setcap cap_net_bind_service=+ep /out/usr/sbin/airptpd

FROM alpine:3.20

RUN apk add --no-cache libevent \
    && adduser -D -H -s /sbin/nologin airptpd

COPY --from=build /out/usr/sbin/airptpd /usr/sbin/airptpd

# Binds PTP UDP ports 319 (event) and 320 (general) via the file capability
# above, and publishes its state to OwnTone through POSIX shared memory
# (/dev/shm/airptp_shm)
USER airptpd
ENTRYPOINT ["/usr/sbin/airptpd", "-f"]
