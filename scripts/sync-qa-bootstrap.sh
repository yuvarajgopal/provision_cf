#!/bin/sh

# TODO: parameterize this

AWS_PROFILE="sncr-bda"
PUBLIC_BUCKET="public.qa.sncrbda.sncr"
PRIVATE_BUCKET="private.qa.sncrbda.sncr"

BOOTSTRAP_DIR=bootstrap
PRIVATE_DIR=private

if [ ! -d $BOOTSTRAP_DIR ]; then
    echo "$0:error: no bootstrap dir named $BOOTSTRAP_DIR"
    exit 1
fi

if [ ! -d $PROVATE_DIR ]; then
    echo "$0:error: no bootstrap dir named $PRIVATE_DIR"
    exit 1
fi

# remove any tmp files

rm -f $BOOTSTRAP_DIR/*~ $PRIVATE_DIR/*~

aws --profile $AWS_PROFILE s3 sync $BOOTSTRAP_DIR s3://$PUBLIC_BUCKET/public/

aws --profile $AWS_PROFILE s3 sync $PRIVATE_DIR s3://$PRIVATE_BUCKET/
