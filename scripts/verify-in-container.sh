#!/bin/sh
set -eu

image=/project/output/openwrt-25.12.5-zapret2-doh-passwall2-mediatek-filogic-snr_snr-cpe-ax2-squashfs-sysupgrade.itb
manifest=/project/output/openwrt-25.12.5-zapret2-doh-passwall2-mediatek-filogic-snr_snr-cpe-ax2.manifest
test -s "$image"
test -s "$manifest"

for package in zapret2 luci-app-zapret2 https-dns-proxy luci-app-https-dns-proxy \
    luci-app-passwall2 xray-core geoview tcping v2ray-geoip v2ray-geosite \
    dnsmasq-full kmod-nft-socket kmod-nft-tproxy kmod-nft-nat \
    kmod-nf-socket kmod-nf-tproxy kmod-nf-conntrack-netlink \
    luci-base luci-mod-admin-full luci-mod-network luci-mod-status \
    luci-mod-system luci-theme-bootstrap luci-app-firewall \
    luci-app-package-manager uhttpd uhttpd-mod-ubus firewall4 dropbear kmod-mt7915e \
    kmod-mt7981-firmware mt7981-wo-firmware fitblk uboot-envtools \
    kmod-crypto-hw-safexcel; do
    grep -q "^$package - " "$manifest"
done
for package in dnsmasq sing-box ppp ppp-mod-pppoe odhcp6c odhcpd-ipv6only \
    luci-proto-ppp luci-proto-ipv6 kmod-ppp kmod-pppoe kmod-pppox \
    kmod-slhc; do
    if grep -q "^$package - " "$manifest"; then
        echo "Unexpected package in image: $package" >&2
        exit 1
    fi
done
grep -q '^busybox - 1.37.0-r7$' "$manifest"
grep -q '^luci-app-passwall2 - 26.9.16-r1$' "$manifest"
grep -q '^xray-core - 26.9.9-r1$' "$manifest"
grep -q '^dnsmasq-full - 2.93-r1$' "$manifest"

check_dir=$(mktemp -d)
dumpimage -T flat_dt -p 2 -o "$check_dir/rootfs.squashfs" "$image" >/dev/null
unsquashfs -no-progress -d "$check_dir/root" "$check_dir/rootfs.squashfs" \
    bin/busybox \
    etc/config/zapret2 \
    etc/config/https-dns-proxy \
    etc/config/passwall2 \
    etc/uci-defaults/90-ssh-wan \
    etc/uci-defaults/luci-app-passwall2 \
    etc/profile.d/90-color-prompt.sh \
    etc/rc.d \
    etc/init.d/zapret2 \
    etc/init.d/https-dns-proxy \
    etc/init.d/passwall2 \
    lib/modules \
    usr/share/passwall2/0_default_config \
    usr/bin/xray \
    usr/sbin/dnsmasq \
    opt/zapret2/init.d/openwrt/custom.d/50-discord_media.sh \
    opt/zapret2/ipset/zapret_hosts_discord.txt \
    opt/zapret2/ipset/zapret_hosts_user_exclude.txt \
    usr/share/openwrt-custom/ssh_key.pub >/dev/null

for file in \
    etc/config/zapret2 \
    etc/config/https-dns-proxy \
    etc/config/passwall2 \
    etc/uci-defaults/90-ssh-wan \
    etc/profile.d/90-color-prompt.sh \
    opt/zapret2/init.d/openwrt/custom.d/50-discord_media.sh \
    opt/zapret2/ipset/zapret_hosts_discord.txt \
    opt/zapret2/ipset/zapret_hosts_user_exclude.txt \
    usr/share/openwrt-custom/ssh_key.pub; do
    cmp "/project/overlay/$file" "$check_dir/root/$file"
done

test -f "$check_dir/root/etc/init.d/zapret2"
test -x "$check_dir/root/bin/busybox"
test -f "$check_dir/root/etc/init.d/https-dns-proxy"
test -f "$check_dir/root/etc/init.d/passwall2"
test -x "$check_dir/root/usr/bin/xray"
test -x "$check_dir/root/usr/sbin/dnsmasq"
grep -q "option enabled '0'" "$check_dir/root/usr/share/passwall2/0_default_config"
passwall_config="$check_dir/root/etc/config/passwall2"
test "$(grep -c '^config shunt_rules ' "$passwall_config")" -eq 3
for rule in Telegram Meta OpenAI; do
    grep -qx "config shunt_rules '$rule'" "$passwall_config"
done
for setting in \
    "enabled '0'" \
    "node 'rulenode'" \
    "type 'Xray'" \
    "protocol '_shunt'" \
    "default_node '_direct'" \
    "direct_dns_protocol 'udp'" \
    "direct_dns '127.0.0.1:5053'" \
    "remote_dns_protocol 'udp'" \
    "remote_dns '127.0.0.1:5054'" \
    "remote_dns_detour 'direct'"; do
    grep -qx "[[:space:]]*option $setting" "$passwall_config"
done
if grep -Eq 'examplenode|passwall2\.github|option (PrivateIP|shunt_group|group) ' "$passwall_config"; then
    echo 'Unexpected default node or shunt rule group in Passwall2 config' >&2
    exit 1
fi
grep -aq 'nftset' "$check_dir/root/usr/sbin/dnsmasq"
for module in nf_conntrack_netlink nf_socket_ipv4 nf_socket_ipv6 \
    nf_tproxy_ipv4 nf_tproxy_ipv6 nft_nat nft_socket nft_tproxy; do
    test -f "$check_dir/root/lib/modules/6.12.94/$module.ko"
done
test -x "$check_dir/root/etc/uci-defaults/90-ssh-wan"
sh -n "$check_dir/root/etc/uci-defaults/90-ssh-wan"
sh -n "$check_dir/root/etc/profile.d/90-color-prompt.sh"
find "$check_dir/root/etc/rc.d" -type l -name '*zapret2' | grep -q .
find "$check_dir/root/etc/rc.d" -type l -name '*https-dns-proxy' | grep -q .

echo 'Образ проверен: BusyBox, Passwall2/Xray, dnsmasq-full с nftset, модули ядра, настройки и автозапуск zapret2/DoH присутствуют.'
