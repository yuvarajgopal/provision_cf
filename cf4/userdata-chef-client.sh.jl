"#!/bin/bash","\n",
"","\n",
"exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1","\n",
"","\n",
"export HOME=/root","\n",
"export PATH=$PATH:/usr/local/sbin","\n",
"","\n",
"logger -s -t userdata 'create the environment descriptor file'","\n",
"","\n",
"SNCR_AWS_ENV='/usr/local/etc/sncr-aws-env.sh'","\n",
"","\n",
"cat <<EOF > $SNCR_AWS_ENV","\n",
"DOMAIN='",{ "Ref" : "Domain" }, "'","\n",
"NODENAME='",{ "Ref" : "NodeName" }, "'","\n",
"NODEINDEX='",{ "Ref" : "NodeIndex" }, "'","\n",
"PRIVATEBUCKET='",{ "Ref" : "PrivateBucketName" }, "'","\n",
"PUBLICBUCKET='",{ "Ref" : "PublicBucketName" }, "'","\n",
"PROJECT_NAME='",{ "Ref" : "Project" }, "'","\n",
"PROJECT_ENV='",{ "Ref" : "Environment" }, "'","\n",
"AWS_REGION='",{ "Ref" : "AWS::Region" }, "'","\n",
"OPS_ALERTS_TOPIC='",{ "Ref" : "OpsAlertsTopic" }, "'","\n",
"CHEF_ENV='",{ "Ref" : "ChefEnv" }, "'","\n",
"CHEF_ROLES='",{ "Ref" : "ChefRoles" }, "'","\n",
"CHEF_ORG='",{ "Ref" : "ChefOrg" }, "'","\n",
"CHEF_SERVER='",{ "Ref" : "ChefServerURL" }, "'","\n",
"CHEF_PROXY='",{ "Ref" : "ChefProxyURL" }, "'","\n",
"EXTRA_HELPER='",{ "Ref" : "ExtraHelper" }, "'","\n",
"CF_WAIT_HANDLE='",{ "Ref" : "WaitHandle" }, "'","\n",
"","\n",
"export DOMAIN NODENAME NODEINDEX","\n",
"export PRIVATEBUCKET PUBLICBUCKET","\n",
"export PROJECT_NAME PROJECT_ENV","\n",
"export AWS_REGION","\n",
"export OPS_ALERTS_TOPIC","\n",
"export CHEF_ENV CHEF_ROLES CHEF_ORG CHEF_SERVER CHEF_PROXY","\n",
"export CF_WAIT_HANDLE","\n",
"EOF","\n",
"","\n",
"chmod 0644 $SNCR_AWS_ENV","\n",
"chown root:root $SNCR_AWS_ENV","\n",
". $SNCR_AWS_ENV","\n",
"","\n",
"yum update --security -y","\n",
"","\n",
"cd /usr/local/sbin","\n",
"","\n",
"logger -s -t userdata 'fetch the helper scripts'","\n",
"helpers='configure-network.sh mount-disks.sh install-awscli.sh install-chef-client.sh signal-wait-handle.sh sncr-aws-versions.sh'","\n",
"","\n",
"if [ -z \"$EXTRA_HELPER\" ]; then","\n",
"  EXTRA_HELPER=\"none\"","\n",
"fi","\n",
"","\n",
"if [ \"$EXTRA_HELPER\" != \"none\" ]; then","\n",
"  helpers=\"$helpers $EXTRA_HELPER\"","\n",
"fi","\n",
"","\n",
"","\n",
"for helper in $helpers; do","\n",
"  logger -s -t userdata \"Fetching $helper\"","\n",
"  wget http://${PUBLICBUCKET}.s3.amazonaws.com/public/$helper","\n",
"  chmod 0544 $helper","\n",
"  chown root:root $helper","\n",
"done","\n",
"","\n",
"logger -s -t userdata 'move the versions file to /usr/local/etc'","\n",
"mv -f sncr-aws-versions.sh /usr/local/etc","\n",
"","\n",
"install-awscli.sh","\n",
"mount-disks.sh","\n",
"configure-network.sh","\n",
"if [ \"$EXTRA_HELPER\" != \"none\" ]; then","\n",
"  $EXTRA_HELPER","\n",
"fi","\n",
"","\n",
"install-chef-client.sh","\n",
"","\n",
"rc=$?","\n",
"signal-wait-handle.sh $rc \"install-chef-client ${NODENAME}${NODEINDEX}\"","\n",
"","\n",
"echo \"Initiating a reboot\"","\n",
"sync","\n",
"sync","\n",
"reboot","\n"
