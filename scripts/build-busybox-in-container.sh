#!/bin/sh
set -eu

build_dir=$(mktemp -d)
sdk_name=openwrt-sdk-25.12.5-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64
sdk_dir="$build_dir/$sdk_name"
recipe_dir="$sdk_dir/package/utils/busybox"

tar --zstd -xf "/project/build/cache/$sdk_name.tar.zst" -C "$build_dir"
tar -xzf /project/build/cache/openwrt-v25.12.5.tar.gz -C "$build_dir" \
    openwrt-25.12.5/package/utils/busybox
mkdir -p "$sdk_dir/package/utils"
cp -a "$build_dir/openwrt-25.12.5/package/utils/busybox" "$recipe_dir"
cp /project/patches/busybox/901-lineedit-prefix-history.patch "$recipe_dir/patches/"
cp /project/build/cache/busybox-1.37.0.tar.bz2 "$sdk_dir/dl/"

python3 - "$recipe_dir" <<'PY'
from pathlib import Path
import sys

recipe = Path(sys.argv[1])
makefile = recipe / "Makefile"
text = makefile.read_text()
before = "PKG_RELEASE:=6\n"
assert text.count(before) == 1
makefile.write_text(text.replace(before, "PKG_RELEASE:=7\n"))

for config in (recipe / "Config-defaults.in", recipe.parents[2] / "Config-build.in"):
    text = config.read_text()
    for symbol, kind, old, new in (
        ("UNICODE_SUPPORT", "bool", "n", "y"),
        ("SUBST_WCHAR", "int", "0", "63"),
        ("LAST_SUPPORTED_WCHAR", "int", "0", "4351"),
    ):
        before = f"config BUSYBOX_DEFAULT_{symbol}\n\t{kind}\n\tdefault {old}\n"
        assert text.count(before) == 1
        text = text.replace(before, before.replace(f"default {old}", f"default {new}"))
    config.write_text(text)
PY

cd "$sdk_dir"
make defconfig
grep -q '^CONFIG_BUSYBOX_DEFAULT_UNICODE_SUPPORT=y$' .config
grep -q '^CONFIG_BUSYBOX_DEFAULT_SUBST_WCHAR=63$' .config
grep -q '^CONFIG_BUSYBOX_DEFAULT_LAST_SUPPORTED_WCHAR=4351$' .config
grep -q '^CONFIG_PACKAGE_busybox=y$' .config
sed -i 's/^CONFIG_PACKAGE_busybox-selinux=m$/# CONFIG_PACKAGE_busybox-selinux is not set/' .config
make package/utils/busybox/compile CONFIG_AUTOREMOVE=

busybox_config=$(find build_dir -type f -path '*/busybox-default/busybox-1.37.0/.config' -print -quit)
test -n "$busybox_config"
cp "$busybox_config" /project/build/cache/busybox-1.37.0-r7.config
grep -q '^CONFIG_UNICODE_SUPPORT=y$' "$busybox_config"
grep -q '^CONFIG_SUBST_WCHAR=63$' "$busybox_config"
grep -q '^CONFIG_LAST_SUPPORTED_WCHAR=4351$' "$busybox_config"
grep -q '^CONFIG_FEATURE_EDITING_HISTORY=256$' "$busybox_config"

package=$(find bin -type f -name 'busybox-1.37.0-r7.apk' -print -quit)
test -n "$package"
cp "$package" /project/build/cache/busybox-1.37.0-r7.apk
