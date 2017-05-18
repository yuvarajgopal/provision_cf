#!/bin/bash -v

CFT_CORE_VERSION="1.6.1"

function error_exit()
{
  logger chef client install: chef client failed
  exit 1
}

. /usr/local/etc/sncr-aws-env.sh
. /usr/local/etc/sncr-aws-versions.sh


METADATA=http://169.254.169.254/latest/meta-data
I_ID=$( wget -q -O - $METADATA/instance-id )
I_IP=$( wget -q -O - $METADATA/local-ipv4 )

export HOME=/root

CHEF_CLIENT_RPM=${CHEF_CLIENT_RPM:="chef-11.12.8-2.el6.x86_64.rpm"}
CHEF_ORG=${CHEF_ORG:-chef}

CHEFS3DIR=chef11

cd /tmp

logger chef client install: installing $CHEF_CLIENT_RPM
wget http://${PUBLICBUCKET}.s3.amazonaws.com/public/$CHEF_CLIENT_RPM
yum -y install $CHEF_CLIENT_RPM

logger chef client install: pulling client keys...

mkdir -p /etc/chef
cd /etc/chef


VALIDATOR="chef-validator"

# if we are using a chef org, make sure the server address is correct
# and set the name of the validator

if [ "$CHEF_ORG" != "chef" ]; then
  case "$CHEF_SERVER" in
      */organizations/*) ;;
      *) CHEF_SERVER="$CHEF_SERVER/organizations/$CHEF_ORG";;
  esac
  VALIDATOR="${CHEF_ORG}-validator"
fi

aws s3 cp s3://${PRIVATEBUCKET}/${CHEFS3DIR}/${VALIDATOR}.pem ${VALIDATOR}.pem
chown root:root ${VALIDATOR}.pem
chmod 0600 ${VALIDATOR}.pem

aws s3 cp s3://${PRIVATEBUCKET}/${CHEFS3DIR}/encrypted_data_bag_secret encrypted_data_bag_secret
chown root:root encrypted_data_bag_secret
chmod 0600 encrypted_data_bag_secret

CHEF_NODE_NAME="${NODENAME}${NODEINDEX}-${I_ID}"

cat <<EOF > client.rb
# this file was generated as instance creation time

node_name   '${CHEF_NODE_NAME}'
environment '${CHEF_ENV}'
log_level :info
log_location STDOUT
chef_server_url '${CHEF_SERVER}'
validation_client_name  '${CHEF_ORG}-validator'
validation_key '/etc/chef/${CHEF_ORG}-validator.pem'
no_lazy_load true
EOF

if [ -n "$CHEF_PROXY" -a "$CHEF_PROXY" != "none" ]; then
    cat <<EOF >> client.rb
https_proxy '${CHEF_PROXY}'
EOF
fi


cat <<EOF >> client.rb

# The following ssl settings might not be working yet
# Verify all HTTPS connections (recommended)

ssl_verify_mode :verify_none

# OR, Verify only connections to chef-server
#verify_api_cert true
EOF

chmod 0644 client.rb
chown root:root client.rb


# build the initial run-list roles.json

# if commas separate the roles, convert them to spaces

CHEF_ROLES=$( echo $CHEF_ROLES | sed 's/,/ /g' )

( # convert run list json
echo "{ \"run_list\" : ["
for role in $CHEF_ROLES; do
  echo "  \"role[$role]\","
done
echo "  ]"
echo "}"
) > roles.json

role_list=$( echo $CHEF_ROLES |
    sed -e 's/\([^ ]*\)/role[\1]/g' -e 's/  */,/g' )

# remove comma at end of last role
(( num = `wc -l < roles.json` - 2 ))
sed -i "${num}s/,$//" roles.json

chmod 0644 roles.json
chown root:root roles.json

if [ "$CHEF_ORG" = "chef" ]; then
    knife ssl fetch -c /etc/chef/client.rb
fi

mkdir -p /etc/chef/ohai/hints
touch /etc/chef/ohai/hints/ec2.json
touch /etc/chef/ohai/hints/iam.json

# first, register this node on the chef server
chef-client -E "${CHEF_ENV}"

# use knife to set this nodes run list
knife node run_list set "$CHEF_NODE_NAME" "$role_list" -c /etc/chef/client.rb

# now do the client runs

chef-client -E ${CHEF_ENV}  >/var/log/chef-client-1.log 2>&1 || \
    chef-client -E ${CHEF_ENV} >/var/log/chef-client-2.log 2>&1


#chef-client -E ${CHEF_ENV} -j roles.json >/var/log/chef-client-1.log 2>&1 || \
#    chef-client -E ${CHEF_ENV} -j roles.json >/var/log/chef-client-2.log 2>&1

rc="$?"

sleep 20

# the result code the chef-client will get returned to the caller

exit $rc
