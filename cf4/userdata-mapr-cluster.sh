#!/bin/bash

exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1

STACK='{Ref:AWS::StackName}'
REGION='{Ref:AWS::Region}'
CLUSTER_NAME='{Ref:ClusterName}'
MAPR_EDITION='{Ref:MapREdition}'
CLUSTER_COMPLETE_HANDLE='{Ref:ClusterCompleteHandle}'
MCS_WAIT_HANDLE='{Ref:MCSWaitHandle}'
DRILL_WAIT_HANDLE='{Ref:DrillWaitHandle}'

AWS='aws --output text'

function error_exit
{
 /opt/aws/bin/cfn-signal -e 1 --stack $STACK --region $REGION --resource ClusterNodes
 exit 1
}

## Install and Update CloudFormation
yum install -y https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm
easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz

## Signal that the node is up
/opt/aws/bin/cfn-signal -e 0 --stack $STACK --region $REGION --resource ClusterNodes

## Wait for all nodes to come on-line

resourceStatus=$($AWS cloudformation describe-stack-resources --region $REGION --stack-name $STACK --logical-resource-id ClusterNodes --query StackResources[].ResourceStatus )

while [ "$resourceStatus" != "CREATE_COMPLETE" ]; do
  sleep 30
  resourceStatus=$($AWS cloudformation describe-stack-resources --region $REGION --stack-name $STACK --logical-resource-id ClusterNodes --query StackResources[].ResourceStatus )
done

## Find the private IP of all the nodes launched by this template
$AWS ec2 describe-instances --region $REGION --filters 'Name=instance-state-name,Values=running' --query 'Reservations[].Instances[].[PrivateDnsName,AmiLaunchIndex,Tags[?Key == LQUOTED(aws:cloudformation:stack-name)] |[0].Value ]' |
grep -w $STACK |
sort -k 2 |
awk '{print $1" MAPRNODE"NR-1}' > /tmp/maprhosts

## Save off other cluster details in prep for configuration
echo "$CLUSTER_NAME" > /tmp/mkclustername
echo "$MAPR_EDITION" > /tmp/maprlicensetype

## Run the setup to start the various services and hadoop cluster
/home/mapr/sbin/deploy-mapr-ami.sh

## Adjust yum repo
echo [MapR_online] >> /etc/yum.repos.d/mapr.online.repo
echo name=MapR Technologies >> /etc/yum.repos.d/mapr.online.repo
echo baseurl=http://package.mapr.com/releases/v4.1.0/redhat/ >> /etc/yum.repos.d/mapr.online.repo
echo enabled=1 >> /etc/yum.repos.d/mapr.online.repo
echo gpgcheck=0 >> /etc/yum.repos.d/mapr.online.repo
echo protect=1 >> /etc/yum.repos.d/mapr.online.repo
echo  >> /etc/yum.repos.d/mapr.online.repo
echo [MapR_ecosystem_online] >> /etc/yum.repos.d/mapr.online.repo
echo name=MapR Technologies >> /etc/yum.repos.d/mapr.online.repo
echo baseurl=http://package.mapr.com/releases/ecosystem-4.x/redhat >> /etc/yum.repos.d/mapr.online.repo
echo enabled=1 >> /etc/yum.repos.d/mapr.online.repo
echo gpgcheck=0 >> /etc/yum.repos.d/mapr.online.repo
echo protect=1 >> /etc/yum.repos.d/mapr.online.repo

##sed -i 's/file:\/\/\/var\/www\/html\/mapr\/ecosystem-4.x/http:\/\/package.mapr.com\/releases\/ecosystem-4.x\/redhat/' /etc/yum.repos.d/mapr.repo
##sed -i 's/file:\/\/\/var\/www\/html\/mapr\/v4.1.0/http:\/\/package.mapr.com\/releases\/ecosystem-4.x\/redhat/' /etc/yum.repos.d/mapr.repo

yum install mapr-spark.noarch -y
/home/mapr/sbin/deploy-mapr-data-services.sh hiveserver
/home/mapr/sbin/deploy-mapr-data-services.sh drill

## Open up ssh to allow direct login
sed -i 's/ChallengeResponseAuthentication .*no$/ChallengeResponseAuthenticationyes/' /etc/ssh/sshd_config
service sshd restart

## If all went well, signal success (must be done by ALL nodes)
/opt/aws/bin/cfn-signal -e 0 -r 'MapR Installation complete' "$CLUSTER_COMPLETE_HANDLE"

## Wait for all nodes to issue the signal
resourceStatus=$($AWS cloudformation describe-stack-resources --region $REGION --stack-name $STACK --logical-resource-id ClusterCompleteCondition --query StackResources[].ResourceStatus)
while [ "$resourceStatus" != "CREATE_COMPLETE" ]; do
    sleep 10
    resourceStatus=$($AWS cloudformation describe-stack-resources --region $REGION --stack-name $STACK --logical-resource-id ClusterCompleteCondition --query StackResources[].ResourceStatus )
done

## Signal back information for outputs (now that all nodes are up)
/home/mapr/sbin/post-mcs-info.sh "MCS_WAIT_HANDLE"

/home/mapr/sbin/post-drill-info.sh "$DRILL_WAIT_HANDLE"
