#!/bin/bash

export LOG_FACILITY="local1"
export LOG_TAG=`basename $0`"[$$]"

function logit() { # level message ...
  local level="$1"
  shift
  logger -t "$LOG_TAG"  -p ${LOG_FACILITY}.${level} -- "$@"
}

function INFO() {
  logit info "$@"
}
function WARN() {
  logit warn "$@"
}
function DEBUG() {
  logit debug "$@"
}
function ERROR() {
  logit error "$@"
}

function error_exit()
{
  ERROR install failed: $*
  exit 1
}


SNCR_AWS_ENV="/usr/local/etc/sncr-aws-env.sh"

if [ ! -r  $SNCR_AWS_ENV ]; then
  error_exit "$SNCR_AWS_ENV MISSING!"
fi

. $SNCR_AWS_ENV
. /usr/local/etc/sncr-aws-versions.sh

CHEF_SERVER_RPM=${CHEF_SERVER_RPM:="chef-server-11.1.3-1.el6.x86_64.rpm"}
CHEF_CLIENT_RPM=${CHEF_CLIENT_RPM:="chef-11.12.8-2.el6.x86_64.rpm"}
CHEF_REPO_SEED=${CHEF_REPO_SEED:="seed-chef-repo.tgz"}

CHEF_S3DIR=chef11

CHEF_REPO_HOME=/var/sncrdeploy/chef

# TODO: improve error handling

# installs chef server and client on rhel
#
# must be run as root
#
#  requires
#      the hostname must be the fqdn
#      the chefserver rpm in the public bucket
#      the git server up and its access pem in the private bucket
#

HOSTNAME=`hostname`

cd /tmp

setenforce 0

chkconfig iptables off
chkconfig ip6tables off

#service iptables stop
#service ip6tables stop

iptables -I INPUT 1 -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT 1 -p tcp -m tcp --dport 443 -j ACCEPT
service iptables save

INFO installing chef server $CHEF_SERVER_RPM from $PUBLICBUCKET

wget http://${PUBLICBUCKET}.s3.amazonaws.com/public/$CHEF_SERVER_RPM
yum -y install $CHEF_SERVER_RPM

/usr/local/sbin/create-chef-server-certificate.sh

chef-server-ctl reconfigure


# make chef server start at boot via @startup entry in root's crontab

crontab -l > root.crontab
sed -i.bak '/chef-server-ctl.*start/d' root.crontab
cat <<EOF root.crontab - > new.crontab
@reboot /usr/bin/chef-server-ctl start >> /var/log/chef-server.log 2>&1
EOF
crontab new.crontab


# put the validator.pem where the client needs it
mkdir -p /etc/chef
cp /etc/chef-server/chef-validator.pem /etc/chef


# now copy the keys to the private S3 bucket
aws s3 cp \
    /etc/chef-server/chef-validator.pem \
    s3://${PRIVATEBUCKET}/${CHEF_S3DIR}/

# install the chef client

INFO installing chef client $CHEF_CLIENT_RPM
wget http://${PUBLICBUCKET}.s3.amazonaws.com/public/$CHEF_CLIENT_RPM
yum -y install $CHEF_CLIENT_RPM

INFO create chef home
mkdir -p $CHEF_REPO_HOME
cd $CHEF_REPO_HOME
rm -rf chef-repo


INFO Fetching $CHEF_REPO_SEED from $PRIVATE_BUCKET

aws s3 cp s3://${PRIVATEBUCKET}/${CHEF_S3DIR}/$CHEF_REPO_SEED .

tar -xvf $CHEF_REPO_SEED

cd chef-repo

INFO create `pwd`/.chef/knife.rb

mkdir .chef
cp /etc/chef-server/admin.pem .chef
cp /etc/chef-server/chef-validator.pem .chef

cat <<EOF > .chef/knife.rb
log_level                :info
log_location             STDOUT
node_name                'admin'
client_key               '$CHEF_REPO_HOME/chef-repo/.chef/admin.pem'
validation_client_name   'chef-validator'
validation_key           '$CHEF_REPO_HOME/chef-repo/.chef/chef-validator.pem'
chef_server_url          '$CHEF_SERVER'
syntax_check_cache_path  '$CHEF_REPO_HOME/chef-repo/.chef/syntax_check_cache'
current_dir = File.dirname(__FILE__)
cookbook_path            ["#{current_dir}/../cookbooks"]
role_path                ["#{current_dir}/../roles"]
data_bag_path            ["#{current_dir}/../data_bags"]
environment_path         ["#{current_dir}/../environments"]
EOF

chmod 0644 .chef/knife.rb
chown root:root .chef/knife.rb

INFO Seeding the chef server from the chef-repo

for data_bag in $(ls data_bags)
do
  if [ -d "data_bags/$data_bag" ]
  then
    knife data bag create $data_bag
  fi
done
knife data bag from file -a
knife role from file roles/*.json
knife environment from file -a
knife cookbook upload -a

INFO set up chef client for roles $CHEF_ROLES

cd /etc/chef

cat <<EOF > /etc/chef/client.rb
node_name '$HOSTNAME'
environment '$CHEF_ENV'
log_level :info
log_location STDOUT
chef_server_url '$CHEF_SERVER'
validation_client_name 'chef-validator'
validation_key '/etc/chef/chef-validator.pem'

ssl_verify_mode :verify_peer

EOF
chmod 0644 /etc/chef/client.rb
chown root:root /etc/chef/client.rb

# create the roles.json file for the first chef-client runs.

# if commas separate the roles, convert them to spaces

CHEF_ROLES=$( echo $CHEF_ROLES | sed 's/,/ /g' )


(				# convert list of roles to json
    echo "{\"run_list\" : ["
    comma=""
    for r in $CHEF_ROLES; do
	echo "    $comma\"role[$r]\""
	comma=","
    done
    echo "  ]"
    echo "}"
) > roles.json
chmod 0644 roles.json
chown root:root roles.json

mkdir -p /etc/chef/ohai/hints
touch /etc/chef/ohai/hints/ec2.json

knife ssl fetch -c /etc/chef/client.rb

chef-client -j /etc/chef/roles.json > /var/log/chef-client-1.log || \
    chef-client -j /etc/chef/roles.json > /var/log/chef-client-2.log
rc=$?

if [ $rc = 0 ]; then
    INFO finished
    exit 0
else
    ERROR failed
    exit $rc
fi
