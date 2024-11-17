FROM alpine:latest AS build
ARG XEN_VERSION=4.19.0
WORKDIR /usr/src

# build dependencies
RUN apk update && apk add build-base git flex bison perl bash coreutils argp-standalone \
    attr-dev curl-dev linux-headers openssl-dev python3-dev xz-dev ocaml ocamlbuild ocaml-ocamldoc dev86 iasl util-linux-dev \
    py3-setuptools ncurses-dev spice-dev xz-dev yajl-dev zlib-dev zstd-dev perl-dev openssl-dev e2fsprogs-dev curl-dev \
    attr-dev dtc-dev meson samurai patchelf sphinx

# check out xen sources
ENV XEN_VERSION=${XEN_VERSION}
ADD https://github.com/xen-project/xen.git#RELEASE-${XEN_VERSION} /usr/src/xen
WORKDIR /usr/src/xen
COPY ./patches-oxenstored ./patches-oxenstored

# configure xen build system
RUN ./configure --prefix=/usr --enable-xen --enable-tools --disable-stubdom --disable-docs

# copy xen configuration
COPY configs/xen-x86_64.config ./xen/.config

# patch build system
RUN for patch in patches-oxenstored/*.patch; do patch -p1 < $patch; done

# build oxenstore
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/include all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/call all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/ctrl all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/devicemodel all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/foreignmemory all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/gnttab all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/guest all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/evtchn all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/toolcore all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/toollog all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -C tools/libs/store all V=1 nosharedlibs=y
RUN CFLAGS="-O2 -Wall -static" LDFLAGS="-static" make -j$(nproc) -C tools/ocaml all nosharedlibs=y && strip tools/ocaml/xenstored/oxenstored

# build xen
RUN make xen -j$(nproc)
RUN make install-xen
RUN mkdir /xenboot; ([ -f /boot/xen ] && cp /boot/xen /xenboot/xen) || \
  ([ -f /boot/xen.gz ] && cp /boot/xen.gz /xenboot/xen.gz)

RUN apk update && apk add build-base git flex bison perl bash coreutils argp-standalone attr-dev curl-dev linux-headers openssl-dev python3-dev xz-dev ocaml ocamlbuild ocaml-ocamldoc dev86 iasl util-linux-dev py3-setuptools ncurses-dev spice-dev xz-dev yajl-dev zlib-dev zstd-dev perl-dev openssl-dev e2fsprogs-dev curl-dev attr-dev dtc-dev meson samurai patchelf

WORKDIR /usr/src
RUN git clone https://xenbits.xen.org/git-http/qemu-xen.git
WORKDIR /usr/src/qemu-xen
COPY ./build-qemu.sh .
RUN sh build-qemu.sh

## copy final oxenstored into a scratch image
FROM scratch AS oxenstored
COPY --from=build /usr/src/xen/tools/ocaml/xenstored/oxenstored /usr/sbin/oxenstored
COPY --from=build /usr/src/xen/tools/ocaml/xenstored/oxenstored.conf /etc/xen/oxenstored.conf
COPY ./oxenstored.service /usr/lib/systemd/system/oxenstored.service

# sysroot for qemu-xen
FROM alpine:latest AS sysroot
RUN mkdir -p /opt/edera/qemu-xen/sysroot && apk update && apk add --root /opt/edera/qemu-xen/sysroot --initdb && \
    cp /etc/apk/repositories /opt/edera/qemu-xen/sysroot/etc/apk/repositories && \
    cp -R /etc/apk/keys /opt/edera/qemu-xen/sysroot/etc/apk/keys && \
    apk add --root /opt/edera/qemu-xen/sysroot \
        so:libpixman-1.so.0 \
        so:libz.so.1 \
        so:libjpeg.so.8 \
        so:libsasl2.so.3 \
        so:libfdt.so.1 \
        so:libgio-2.0.so.0 \
        so:libgobject-2.0.so.0 \
        so:libglib-2.0.so.0 \
        so:libzstd.so.1 \
        so:libncursesw.so.6 \
        so:libgmodule-2.0.so.0 \
        so:libspice-server.so.1 \
        so:libcurl.so.4 \
        so:libbz2.so.1 \
        so:libmount.so.1 \
        so:libintl.so.8 \
        so:libffi.so.8 \
        so:libpcre2-8.so.0 \
        so:libssl.so.3 \
        so:libcrypto.so.3 \
        so:libopus.so.0 \
        so:libgstreamer-1.0.so.0 \
        so:libgstapp-1.0.so.0 \
        so:liborc-0.4.so.0 \
        so:liblz4.so.1 \
        so:libstdc++.so.6 \
        so:libcares.so.2 \
        so:libnghttp2.so.14 \
        so:libidn2.so.0 \
        so:libpsl.so.5 \
        so:libbrotlidec.so.1 \
        so:libblkid.so.1 \
        so:libgstbase-1.0.so.0 \
        so:libgcc_s.so.1 \
        so:libunistring.so.5 \
        so:libbrotlicommon.so.1 \
        so:libeconf.so.0

RUN printf "/opt/edera/qemu-xen/sysroot/lib\n/opt/edera/qemu-xen/sysroot/usr/lib\n" > /opt/edera/qemu-xen/sysroot/etc/ld-musl-$(apk --print-arch).path

FROM scratch AS final
COPY --from=build /usr/src/qemu-xen/output/opt/edera/qemu-xen /opt/edera/qemu-xen
COPY --from=sysroot /opt/edera/qemu-xen/sysroot /opt/edera/qemu-xen/sysroot
COPY --from=build /xenboot/* /boot/
COPY --from=build /usr/lib64/efi/xen.efi /usr/share/efi/xen.efi
COPY --from=build /usr/src/xen/xen/.config /boot/xen.config
COPY --from=build /usr/src/xen/tools/ocaml/xenstored/oxenstored /usr/sbin/oxenstored
COPY --from=build /usr/src/xen/tools/ocaml/xenstored/oxenstored.conf /etc/xen/oxenstored.conf
COPY ./oxenstored.service /usr/lib/systemd/system/oxenstored.service
