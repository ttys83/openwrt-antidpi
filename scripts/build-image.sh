#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
archive_name=openwrt-imagebuilder-25.12.5-mediatek-filogic.Linux-x86_64.tar.zst
archive="$project_dir/build/cache/$archive_name"
expected_sha256=7fb6cf626582ebcbfb46974da48c1eae577213f38879eaf6b1d982041e843461
archive_url="https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/$archive_name"
sdk_name=openwrt-sdk-25.12.5-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst
sdk_sha256=ff4a38a397caa2cfe1c39e18f84ddede14878221b3593c3f2c4cfe24e3ec4c25
source_name=openwrt-v25.12.5.tar.gz
source_sha256=19462c4d0d52824b33ae52f60ee5e66528bf103691aabdb5e1e15cc8924067df
busybox_name=busybox-1.37.0.tar.bz2
busybox_sha256=3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4

mkdir -p "$project_dir/build/cache" "$project_dir/output"
if [ ! -s "$archive" ]; then
    curl -fL --retry 3 "$archive_url" -o "$archive.part"
    mv "$archive.part" "$archive"
fi

actual_sha256=$(shasum -a 256 "$archive" | awk '{print $1}')
if [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "Image Builder checksum mismatch: $actual_sha256" >&2
    exit 1
fi

check_package() {
    expected=$1
    path=$2
    actual=$(shasum -a 256 "$path" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "Package checksum mismatch: $path" >&2
        exit 1
    fi
}

check_package bfa52fae9513a2e408fbbf3c3868c82c96b6eea5435d2f3e34ac1ba70503f726 \
    "$project_dir/vendor/routerich/zapret2-1.0.5.2-r1.apk"
check_package aaae5fa8e9d100939b7b4828610c0ffd52edd5ed0c6783f3ccec336eae7d4622 \
    "$project_dir/vendor/routerich/luci-app-zapret2-1.0.5.2-r1.apk"
check_package 094198fff9ebfad69517cd8e5588cc337151ece4f74c1326839c814029be00fe \
    "$project_dir/vendor/passwall2/geoview-0.2.6-r1.apk"
check_package 28de7c5274986ad7e049f52ac9e3d224dbe63d71f2951ed26f95d5f7ee9ae02e \
    "$project_dir/vendor/passwall2/luci-app-passwall2-26.9.16-r1.apk"
check_package 821d3be38dc6fe983307ab11b3085f4c26e4ab32b4ea2e8b27b81bbd9326c7b3 \
    "$project_dir/vendor/passwall2/tcping-0.3-r1.apk"
check_package 7c04711f44867d9e0c5eb41f7905e1c94a79bc09fc9411791efb36aeb72b6008 \
    "$project_dir/vendor/passwall2/v2ray-geoip-202609240030.1.apk"
check_package dc129f5f7e210734f0f2a58a68faa3ec219808d3c4d6b6e9eb8837f60cf0fbcb \
    "$project_dir/vendor/passwall2/v2ray-geosite-20260726062913-r1.apk"
check_package 5dc6790c7223b92b6ce3e169e424db8c85b06361be1f90c0a4411a8f6d8f204d \
    "$project_dir/vendor/passwall2/xray-core-26.9.9-r1.apk"

download_source() {
    name=$1
    expected=$2
    url=$3
    path="$project_dir/build/cache/$name"
    if [ ! -s "$path" ]; then
        curl -fL --retry 3 "$url" -o "$path.part"
        mv "$path.part" "$path"
    fi
    check_package "$expected" "$path"
}

download_source "$sdk_name" "$sdk_sha256" \
    "https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/$sdk_name"
download_source "$source_name" "$source_sha256" \
    https://codeload.github.com/openwrt/openwrt/tar.gz/refs/tags/v25.12.5
download_source "$busybox_name" "$busybox_sha256" \
    "https://busybox.net/downloads/$busybox_name"

docker build --platform linux/amd64 -t openwrt-custom-imagebuilder:25.12.5 "$project_dir"
busybox_package="$project_dir/build/cache/busybox-1.37.0-r7.apk"
busybox_inputs="$project_dir/build/cache/busybox-build-inputs.sha256"
current_inputs=$(shasum -a 256 \
    "$project_dir/patches/busybox/901-lineedit-prefix-history.patch" \
    "$project_dir/scripts/build-busybox-in-container.sh" \
    "$project_dir/Dockerfile" | shasum -a 256 | awk '{print $1}')
if [ ! -s "$busybox_package" ] || [ ! -f "$busybox_inputs" ] || \
    [ "$(cat "$busybox_inputs")" != "$current_inputs" ]; then
    docker run --rm --platform linux/amd64 \
        --user "$(id -u):$(id -g)" \
        -v "$project_dir:/project" \
        openwrt-custom-imagebuilder:25.12.5 \
        sh /project/scripts/build-busybox-in-container.sh
    echo "$current_inputs" > "$busybox_inputs"
fi

docker run --rm --platform linux/amd64 \
    --user "$(id -u):$(id -g)" \
    -v "$project_dir:/project:ro" \
    -v "$project_dir/output:/output" \
    -v "$archive:/imagebuilder.tar.zst:ro" \
    openwrt-custom-imagebuilder:25.12.5 \
    sh /project/scripts/in-container.sh

docker run --rm --platform linux/amd64 \
    -v "$project_dir:/project:ro" \
    openwrt-custom-imagebuilder:25.12.5 \
    sh /project/scripts/verify-in-container.sh
