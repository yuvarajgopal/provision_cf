#!/bin/bash

PRIMARY=$( hostname )

CHEF_DIR=/etc/chef-server
KEY=$CHEF_DIR/chef.key
PEM=$CHEF_DIR/chef.pem


SUBJ_CN="$PRIMARY"
SUBJ_O="Synchronoss Technologies, Inc."
SUBJ_OU="IT"
SUBJ_E="networkadmins@synchronoss.com"
SUBJ_L="Bethlehem"
SUBJ_ST="Pennsylvania"
SUBJ_C="US"


DAYS=3650
BITS=4096

mkdir -p $CHEF_DIR

openssl req -x509 -newkey rsa:$BITS -keyout $KEY -out $PEM -nodes -days $DAYS \
 -subj "/CN=$SUBJ_CN/O=$SUBJ_O/OU=$SUBJ_OU/L=$SUBJ_L/ST=$SUBJ_ST/C=$SUBJ_C"

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

# simple call was
# openssl req -x509 -newkey rsa:4096 -keyout chef.key -out chef.pem -nodes -days 365
