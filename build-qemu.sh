#!/bin/sh
set -e

[ "$(apk --print-arch)" = "x86_64" ] && target="i386" || target="aarch64"

export CFLAGS="-O2 -Wall -Wno-error"
echo "Building for: $target"
env PKG_CONFIG_PATH="/usr/src/xen/tools/pkg-config:/usr/lib/pkg-config:/usr/share/pkg-config" \
./configure --prefix=/opt/edera/qemu-xen --enable-xen --target-list="${target}-softmmu" \
  --extra-cflags="-I/usr/src/xen/tools/include -I/usr/src/xen/tools/libxc -I/usr/src/xen/tools/xenstore" \
  --extra-ldflags="-L/usr/src/xen/tools/libs/call -L/usr/src/xen/tools/libs/store -L/usr/src/xen/tools/libs/toollog -lxencall -lxenstore -lxentoollog"
make -j"$(nproc)"
make install DESTDIR="/usr/src/qemu-xen/output"

for PROG in elf2dmp qemu-edid qemu-ga qemu-img qemu-io qemu-nbd qemu-pr-helper qemu-storage-daemon qemu-system-${target} qemu-vmsr-helper; do
  echo "Setting interpreter for $PROG"
  [ -x "/usr/src/qemu-xen/output/opt/edera/qemu-xen/bin/$PROG" ] && patchelf --set-interpreter "/opt/edera/qemu-xen/sysroot/lib/ld-musl-$(apk --print-arch).so.1" --add-rpath /opt/edera/qemu-xen/sysroot/lib --add-rpath /opt/edera/qemu-xen/sysroot/usr/lib "/usr/src/qemu-xen/output/opt/edera/qemu-xen/bin/$PROG";
done

echo "Build complete"

exit 0
