#!/bin/sh

SHORT_OPTS="c:km:np:r:uw:vh"

AWS_PROFILE="$PROVISION_AWS_PROFILE"

CONFIG_FILE="must-specify.conf"
LOG_FILE="aws.log"
MAKEFILE="Makefile"

VERSION="0.1.0"

usage() {
cat <<EOF
usage:

$0 options env

options
  -c file      specify conf file [$CONFIG_FILE]
  -m Makefile
  -n           no run
  -p  profile  specify profile for awscli [$AWS_PROFILE]
  -h           display this help
  -v           verbose

EOF
}

log () {
   echo $(date "+%Y-%m-%dT%H:%M:%S - ") $@ | tee -a $LOG_FILE
}

logerror() {
   echo $(date "+%Y-%m-%dT%H:%M:%S - ") "ERROR: " $@ | tee -a $LOG_FILE
}

prog=`basename $0`

while getopts ":$SHORT_OPTS" opt; do
    case $opt in
	c) CONFIG_FILE="$OPTARG" ;;
	m) MAKEFILE="$OPTARG" ;;
	n) NORUN=1 ;;
	p) AWS_PROFILE="$OPTARG" ;;
	h) usage; exit 0 ;;
	v) VERBOSE=1 ;;
	:) echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
	\?) echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -ne 1 ]; then
    logerror "error:$prog:0 must specify an environment!"
    exit 1
fi

ENVIRONMENT="$1"
ENVIRONMENT_UC=$( echo $1 | tr a-z A-Z )
ENVIRONMENT_LC=$( echo $1 | tr A-Z a-z )


if [ ! -r $CONFIG_FILE ]; then
    logerror "error:$prog:0 config file $CONFIG_FILE missing or unreadable"
    exit 1
fi


if [ -n "$MAKEFILE" ]; then
    if [ -r "$MAKEFILE" ]; then
        make -f "$MAKEFILE"
        if [ $? != 0 ]; then
            logerror "make failed, exiting.."
            exit 9
        fi
    else
        logerror  "makefile $MAKEFILE missing or unreadable"
        exit 9
    fi
fi

extract_conf_variables() { # $1 = config file $2 = section
    local config_file="$1"
    local section="$2"

    sed \
        -e 's/[;#].*$//' \
        -e 's/[[:space:]]*$//' \
        -e 's/^[[:space:]]*//' \
        -e '/^$/d' \
        -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
        -e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" \
        < $config_file | \
        sed -n -e "/^\s*\[${section}\]/,/^\s*\[/p" | \
        sed -e '/^\[/d'
}


# read the default and then ENV specific sections from the config file
# this first read is just to get the AWS_PROFILE if present

if [ -z "$AWS_PROFILE" ]; then # if unset, look for AWS_PROFILE in the .conf
    eval $( extract_conf_variables $CONFIG_FILE default | \
        grep '\bAWS_PROFILE\b' )
    eval $( extract_conf_variables $CONFIG_FILE $ENVIRONMENT_UC | \
        grep '\bAWS_PROFILE\b' )
fi

# by now, AWS_PROFILE needs to have been defined

if [ -z "$AWS_PROFILE" ]; then
    logerror "AWS_PROFILE missing or empty"
    exit 2
fi

# read the default and then ENV specific sections from the config file
# don't read the AWS_PROFILE setting again

eval $( extract_conf_variables $CONFIG_FILE default | \
    grep -v '\bAWS_PROFILE\b' )
eval $( extract_conf_variables $CONFIG_FILE $ENVIRONMENT_UC | \
    grep -v '\bAWS_PROFILE\b' | tee /tmp/vars.out )

if [ -z "$CF_PROJECT" ]; then
    logerror "CF_PROJECT name missing or empty"
    exit 2
fi

AWS="aws --profile $AWS_PROFILE"
if [ -n "$AWS_REGION" ]; then
    AWS="$AWS --region $AWS_REGION"
fi

if [ "$PRIVATE_BUCKET" != "$PrivateBucketName" ]; then
    logerror "bucket name mismatch: [$PRIVATE_BUCKET] != [$PrivateBucketName]"
    exit 2
fi

PUBLIC_BUCKET="$PublicBucketName"

for b in "$PRIVATE_BUCKET" "$PUBLIC_BUCKET"; do
    log "Creating Bucket $b"
    $AWS s3 mb "s3://$b"
    rc=$?
    if [ $rc != 0 ]; then
	logerror " failure ($rc) creating bucket $b"
    fi
done
