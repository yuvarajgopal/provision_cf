#!/bin/bash

exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1

export HOME=/root
export PATH=$PATH:/usr/local/sbin

logger -s -t userdata 'create the environment descriptor file'

SNCR_AWS_ENV='/usr/local/etc/sncr-aws-env.sh'

cat <<EOF > $SNCR_AWS_ENV
DOMAIN='{Ref:Domain}'
NODENAME='{Ref:NodeName}'
NODEINDEX='{Ref:NodeIndex}'
PRIVATEBUCKET='{Ref:PrivateBucketName}'
PUBLICBUCKET='{Ref:PublicBucketName}'
PROJECT_NAME='{Ref:Project}'
PROJECT_ENV='{Ref:Environment}'
AWS_REGION='{Ref:AWS::Region}'
OPS_ALERTS_TOPIC='{Ref:OpsAlertsTopic}'
CHEF_ENV='{Ref:ChefEnv}'
CHEF_ROLES='{Ref:ChefRoles}'
CHEF_ORG='{Ref:ChefOrg}'
CHEF_SERVER='{Ref:ChefServerURL}'
CHEF_PROXY='{Ref:ChefProxyURL}'
CF_WAIT_HANDLE='{Ref:WaitHandle}'

export DOMAIN NODENAME NODEINDEX
export PRIVATEBUCKET PUBLICBUCKET
export PROJECT_NAME PROJECT_ENV
export AWS_REGION
export OPS_ALERTS_TOPIC
export CHEF_ENV CHEF_ROLES CHEF_ORG CHEF_SERVER CHEF_PROXY
export CF_WAIT_HANDLE
EOF

chmod 0644 $SNCR_AWS_ENV
chown root:root $SNCR_AWS_ENV
. $SNCR_AWS_ENV

yum update --security -y

cd /usr/local/sbin

logger -s -t userdata 'fetch the helper scripts'
helpers='configure-network.sh configure-nat.sh mount-disks.sh install-awscli.sh install-chef-client.sh signal-wait-handle.sh sncr-aws-versions.sh'

for helper in $helpers; do
  logger -s -t userdata "Fetching $helper"
  wget http://${PUBLICBUCKET}.s3.amazonaws.com/public/$helper
  chmod 0544 $helper
  chown root:root $helper
done

logger -s -t userdata 'move the versions file to /usr/local/etc'
mv -f sncr-aws-versions.sh /usr/local/etc

install-awscli.sh
mount-disks.sh
configure-network.sh
configure-nat.sh
install-chef-client.sh

rc=$?
signal-wait-handle.sh $rc "install-chef-client ${NODENAME}${NODEINDEX}"

echo "Initiating a reboot"
sync
sync
reboot
