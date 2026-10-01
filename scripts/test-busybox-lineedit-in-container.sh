#!/bin/sh
set -eu

work=$(mktemp -d)
tar -xjf /project/build/cache/busybox-1.37.0.tar.bz2 -C "$work"
cd "$work/busybox-1.37.0"
patch -p1 < /project/patches/busybox/901-lineedit-prefix-history.patch
make defconfig >/dev/null
sed -i \
    -e 's/^# CONFIG_UNICODE_SUPPORT is not set$/CONFIG_UNICODE_SUPPORT=y/' \
    -e 's/^CONFIG_SUBST_WCHAR=.*/CONFIG_SUBST_WCHAR=63/' \
    -e 's/^CONFIG_LAST_SUPPORTED_WCHAR=.*/CONFIG_LAST_SUPPORTED_WCHAR=4351/' \
    .config
yes '' | make oldconfig >/dev/null
make -j2 busybox >/dev/null
python3 /project/scripts/test-busybox-lineedit.py "$PWD/busybox"
