#!/bin/sh
set -eu

build_dir=$(mktemp -d)
tar --zstd -xf /imagebuilder.tar.zst -C "$build_dir"
imagebuilder_dir="$build_dir/openwrt-imagebuilder-25.12.5-mediatek-filogic.Linux-x86_64"
test -d "$imagebuilder_dir/packages"
cp /project/vendor/routerich/*.apk "$imagebuilder_dir/packages/"
cp /project/vendor/passwall2/*.apk "$imagebuilder_dir/packages/"
cp /project/build/cache/busybox-1.37.0-r7.apk "$imagebuilder_dir/packages/"
cd "$imagebuilder_dir"

make image \
    PROFILE=snr_snr-cpe-ax2 \
    PACKAGES='luci-base luci-mod-admin-full luci-theme-bootstrap luci-app-firewall luci-app-package-manager rpcd-mod-rrdns uhttpd uhttpd-mod-ubus zapret2 luci-app-zapret2 https-dns-proxy luci-app-https-dns-proxy luci-app-passwall2 xray-core dnsmasq-full -dnsmasq kmod-nft-socket kmod-nft-tproxy kmod-nft-nat kmod-nf-socket kmod-nf-tproxy kmod-nf-conntrack-netlink -ppp -ppp-mod-pppoe -odhcp6c -odhcpd-ipv6only' \
    FILES=/project/overlay \
    BIN_DIR=/output \
    EXTRA_IMAGE_NAME=zapret2-doh-passwall2
