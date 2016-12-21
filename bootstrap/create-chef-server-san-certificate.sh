#!/bin/bash

REQUEST_CNF=/tmp/request.cnf
DAYS=365
CHEF_DIR=/etc/chef-server
KEY=$CHEF_DIR/chef.key
PEM=$CHEF_DIR/chef.pem

cat <<EOF > /tmp/request.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = PA
L = Bethlehem
O = Synchronoss Technologies, Inc.
OU = IT
CN = oh-chef01.devops.dev.cloud.synchronoss.net

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS = oh-chef.devops.dev.cloud.synchronoss.net
#DNS.2 = oh-chef01-eip.devops.dev.cloud.synchronoss.net

EOF

mkdir -p /etc/chef-server

openssl req -x509 -nodes -days $DAYS -newkey rsa:4096 \
    -keyout $KEY -out $PEM -config $REQUEST_CNF

chmod 0400 $PEM $KEY

if [ -r $CHEF_DIR/chef-server.rb ]; then
    # remove any ssl_certificate references if there is a .rb
    sed -i.bak  \
	-e "/nginx.*'ssl_certificate.*=/d" \
	-e "/nginx.*'ssl_certificate_key'.*=/d" \
	$CHEF_DIR/chef-server.rb
fi

cat <<EOF >> $CHEF_DIR/chef-server.rb
nginx['ssl_certificate'] = '/etc/chef-server/chef.pem'
nginx['ssl_certificate_key'] = '/etc/chef-server/chef.key'
EOF
