#!/bin/bash

CFT_CORE_VERSION="1.5.1"

AWSCLI_CONFIG='/root/.aws/config'

. /usr/local/etc/sncr-aws-env.sh

logger -s -t configure-network "NODENAME=$NODENAME NODEINDEX=$NODEINDEX DOMAIN=$DOMAIN"

# TODO
# handle cases where name, index, or domain are missing

#  !!! auto-scaled nodes and ONLY auto-scaled nodes
#  !!! MUST have a node index of all 0's (up to four currently)
#
#  when the nodindex is 0,
#     the hostname will be set to the nodes current hostname
#     which is of the form ip-ww-xx-yy-zz
#
#  if the hostname gets set to the standard, ${NODENAME}${NODEINDEX}
#    sudo, at least, fails

case "$NODEINDEX" in
    0|00|00|0000) HOSTNAME=$( hostname ) ;;
               *) HOSTNAME="${NODENAME}${NODEINDEX}" ;;
esac


FQDN=${HOSTNAME}.${DOMAIN}

NETCONF=/etc/sysconfig/network
METADATA=http://169.254.169.254/latest/meta-data

I_ID=$( wget -q -O - $METADATA/instance-id )
I_IP=$( wget -q -O - $METADATA/local-ipv4 )

echo >> /root/.bashrc export I_ID=$I_ID
. /root/.bashrc

echo $I_IP $FQDN $HOSTNAME >> /etc/hosts

sed -i "s/^HOSTNAME=.*/HOSTNAME=$FQDN/" $NETCONF
# make sure $NETCONF ends with a newline
echo >> $NETCONF

hostname $FQDN
