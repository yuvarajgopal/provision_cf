#!/bin/bash

CFT_CORE_VERSION="1.5.1"

AWSCLI_CONFIG='/root/.aws/config'

. /usr/local/etc/sncr-aws-env.sh
. /usr/local/etc/sncr-aws-versions.sh

easy_install pip==${PIP_VERSION:="1.4.1"}
pip install awscli==${AWSCLI_VERSION:="1.1.0"}

mkdir -p $( dirname $AWSCLI_CONFIG )

cat <<EOF > $AWSCLI_CONFIG
[default]
region = $AWS_REGION
EOF

chmod 0600 $AWSCLI_CONFIG
chown root:root $AWSCLI_CONFIG
