#!/bin/bash

CFT_CORE_VERSION="1.5.1"

# expects two arguments
#  $1 is 0 or non-zero
#  $2 is "message"

# if missing, it will signal success

. /usr/local/etc/sncr-aws-env.sh

status="${1:-0}"
if [ "$status" = 0 ]; then
    STATUS=SUCCESS
else
    STATUS=FAILURE
fi

MESG="${2}"

DATA="${STATUS}($status) $MESG"


if [ -z "$MESG" ]; then
    if [ "$status" = 0 ]; then
	MESG="Success"
    else
	MESG="Failure $status"
    fi
fi


METADATA=http://169.254.169.254/latest/meta-data

I_ID=$( wget -q -O - $METADATA/instance-id )
I_IP=$( wget -q -O - $METADATA/local-ipv4 )

UNIQUEID="${NODENAME}${NODEINDEX}"

WAIT_DATAFILE=/tmp/wait-reply.json

cat <<EOF > $WAIT_DATAFILE
{
  "Status" : "$STATUS",
  "UniqueId" : "$UNIQUEID",
  "Data" : "$DATA",
  "Reason" : "$MESG"
}
EOF

logger -s -t signal-wait-handler.sh "sending $STATUS $UNIQUEID [$DATA] [$MESG]"

curl -T $WAIT_DATAFILE "$CF_WAIT_HANDLE"

# send an alert to the ops_alerts_topic too, if it exists

if [ -n "$OPS_ALERTS_TOPIC" ]; then
    aws sns publish --topic-arn "$OPS_ALERTS_TOPIC" \
	--subject "Provision Result $STATUS for $UNIQUEID [$I_ID] in ${DOMAIN}" \
	--message "Status: $STATUS
Uniqueid: ${UNIQUEID}.${DOMAIN}
Id: $I_ID
Data: $DATA
Reason: $MESG"
fi
