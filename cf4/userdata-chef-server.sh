#!/bin/bash

exec > >(tee /var/log/userdata.log|logger -t userdata -s 2>/dev/console) 2>&1

export HOME=/root
export PATH=$PATH:/usr/local/sbin

logger -s -t userdata 'create the environment descriptor file'

SNCR_AWS_ENV='/usr/local/etc/sncr-aws-env.sh'

cat <<EOF > $SNCR_AWS_ENV
DOMAIN='{Ref:Domain}'
NODENAME='{Ref:NodeName}'
PRIVATEBUCKET='{Ref:PrivateBucketName}'
PUBLICBUCKET='{Ref:PublicBucketName}'
PROJECT_NAME='{Ref:Project}'
PROJECT_ENV='{Ref:Environment}'
AWS_REGION='{Ref:AWS::Region}'
OPS_ALERTS_TOPIC='{Ref:OpsAlertsTopic}'
CHEF_SERVER='{Ref:ChefServerURL}'
CHEF_ENV='{Ref:ChefEnv}'
CHEF_ROLES='{Ref:ChefRoles}'
CF_WAIT_HANDLE='{Ref:WaitHandle}'

export DOMAIN NODENAME NODEINDEX
export PUBLICBUCKET PRIVATEBUCKET
export PROJECT_NAME PROJECT_ENV
export AWS_REGION
export OPS_ALERTS_TOPIC
export CHEF_SERVER CHEF_ENV CHEF_ROLES
export CF_WAIT_HANDLE
EOF
chmod 0644 $SNCR_AWS_ENV

chown root:root $SNCR_AWS_ENV

. $SNCR_AWS_ENV

yum update --security -y

cd /usr/local/sbin



logger -s -t userdata 'fetch the helper scripts'

helpers='configure-network.sh mount-disks.sh install-awscli.sh install-chef-server.sh signal-wait-handle.sh sncr-aws-versions.sh create-chef-server-certificate.sh'

for helper in $helpers; do
  logger -s -t userdata "Fetching $helper "
  wget http://${PUBLICBUCKET}.s3.amazonaws.com/public/$helper
  chmod u=rx,go=r $helper
  chown root:root $helper
done

logger -s -t userdata 'move the versions file to /usr/local/etc'
mv -f sncr-aws-versions.sh /usr/local/etc

# now start executing the helpers

install-awscli.sh

mount-disks.sh

configure-network.sh

install-chef-server.sh

# for now, guarantee success
rc=0

signal-wait-handle.sh $rc 'install chef server'

echo "Initiating a reboot"
sync
sync
reboot
