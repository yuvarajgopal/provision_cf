#!/bin/bash

CFT_CORE_VERSION="1.5.1"

AWSCLI_CONFIG='/root/.aws/config'

. /usr/local/etc/sncr-aws-env.sh

logger -s -t configure-nat "NODENAME=$NODENAME NODEINDEX=$NODEINDEX DOMAIN=$DOMAIN"

# TODO

mkdir -p /etc/sysctl.d > /dev/null 2>&1

echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/nat.conf
echo 'net.ipv4.conf.eth0.send_redirects = 1' >> /etc/sysctl.d/nat.conf

sysctl -p /etc/sysctl.d/nat.conf
rc=$?

logger -s -t configure-nat "sysctls applied (rc=$rc)"


/sbin/iptables --flush

/sbin/iptables -t nat -A POSTROUTING -o eth0 -s 0.0.0.0/0 -j MASQUERADE
rc=$?

logger -s -t configure-nat "iptables modified (rc=$rc)"

/etc/init.d/iptables save

service iptables start

chkconfig iptables on
