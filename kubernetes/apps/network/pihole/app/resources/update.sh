#!/bin/bash

set -Eeuo pipefail

# use dnscrypt-proxy, and add coredns in case there's no dns container up
printf "nameserver 192.168.0.51\nnameserver 10.43.0.10" > /etc/resolv.conf

# Use fast temporary storage for SQLite operations
if [ -f "/final/gravity.db" ]; then
	echo "copying existing config to fast temporary storage"
	cp -a /final/. /tmp-pihole/
	rm /etc/pihole -rf
	ln -s /tmp-pihole /etc/pihole
elif [ ! -f "/etc/pihole/gravity.db" ]; then
	# run gravity to cause db to get created on fast storage
	echo "creating gravity db on fast temporary storage"
	rm /etc/pihole -rf
	ln -s /tmp-pihole /etc/pihole
	pihole -g
fi

### Allowlist items
# new sqlite approach based for PiHole v6
echo;
echo "Prepping allowlists"
echo "https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt
https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/optional-list.txt
https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/referral-sites.txt
https://tholinka.github.io/projects/hosts/allowlist" | sort > /tmp/allow.list

echo "getting current allowlists"
pihole-FTL sql /etc/pihole/gravity.db "SELECT address FROM adlist WHERE type=1" | sort > /tmp/current-allow.list

to_remove=$(comm -23 /tmp/current-allow.list /tmp/allow.list)
echo "Disabling lists not in the combined allow lists from db: $to_remove"
if [ -n "$to_remove" ]; then
	while IFS= read -r url; do
		[ -z "$url" ] && continue
		pihole-FTL sql /etc/pihole/gravity.db "UPDATE adlist SET enabled=0 WHERE address='$url' AND type=1;" || true
	done <<< "$to_remove"
fi

to_add="$(comm -13 /tmp/current-allow.list /tmp/allow.list)"
echo "Inserting new allow lists into db: $to_add"
echo "$to_add" | xargs -I{} pihole-FTL sql /etc/pihole/gravity.db "INSERT INTO adlist (address, comment, enabled, type) VALUES ('{}', 'allowlist, added `date +%F`', 1, 1);"

echo "Done with allowlist"

### Deny list items
# new sqlite approach based on https://discourse.pi-hole.net/t/blocklist-management-in-pihole-v5/31971/9
echo;
echo "getting current adlists"
pihole-FTL sql /etc/pihole/gravity.db "SELECT address FROM adlist WHERE type=0" | sort > /tmp/current.list

echo "Downloading adlist from wally3k.firebog.net"
curl "https://v.firebog.net/hosts/lists.php?type=tick" | sort > /tmp/firebog.list

echo "Adding tholinka.github.io tracking lists"

echo "https://tholinka.github.io/projects/hosts/wintracking/normal
https://tholinka.github.io/projects/hosts/hosts" | sort > /tmp/tholinka.list

cat /tmp/firebog.list /tmp/tholinka.list | sort > /tmp/combined.list

to_remove="$(comm -23 /tmp/current.list /tmp/combined.list)"
echo "Disabling lists not in the combined lists from db: $to_remove"

if [ -n "$to_remove" ]; then
	while IFS= read -r url; do
		[ -z "$url" ] && continue
		pihole-FTL sql /etc/pihole/gravity.db "UPDATE adlist SET enabled=0 WHERE address='$url' AND type=0;" || true
	done <<< "$to_remove"
fi

to_add="$(comm -13 /tmp/current.list /tmp/combined.list)"
echo "Inserting new lists into db: $to_add"
if [ -n "$to_add" ]; then
	while IFS= read -r url; do
		[ -z "$url" ] && continue
		pihole-FTL sql /etc/pihole/gravity.db "INSERT INTO adlist (address, comment, enabled, type) VALUES ('$url', 'added `date +%F`', 1, 0);" || true
	done <<< "$to_add"
fi

echo;
echo "Running pihole gravity"
echo;

pihole -g

echo;
echo "Updating pihole.toml"

pihole-FTL --config misc.etc_dnsmasq_d true
pihole-FTL --config dns.blockESNI false
pihole-FTL --config dns.domain.name internal
pihole-FTL --config webserver.domain "pihole.${SECRET_DOMAIN}"
pihole-FTL --config dns.revServers '[
	"true,192.168.0.0/24,192.168.11.1,server.local",
	"true,192.168.3.0/24,192.168.11.1,computer.local"
	]'
pihole-FTL --config dns.reply.host.force4 true
pihole-FTL --config dns.reply.host.IPv4 192.168.2.254
pihole-FTL --config dns.reply.blocking.force4 true
pihole-FTL --config dns.reply.blocking.IPv4 192.168.2.254
pihole-FTL --config misc.nice -999
pihole-FTL --config misc.check.load false
pihole-FTL --config dns.ignoreLocalhost true
pihole-FTL --config ntp.ipv4.active false
pihole-FTL --config ntp.ipv6.active false
pihole-FTL --config ntp.sync.active false

echo;
echo "copying config from fast temporary storage to persistent volume"
cp -a /tmp-pihole/. /final/

# use only dnscrypt-proxy
echo 'nameserver 192.168.2.253' > /etc/resolv.conf