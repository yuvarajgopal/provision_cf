#!/bin/bash

CFT_CORE_VERSION="1.8.1"

RETRIES=10
DELAY=30
SHORT_DELAY=15

# mount extra disks if they exist on the instance
#    /dev/sde => /dev/xvdi  mount as /opt

TAG=$( basename $0 )[$$]
INFO="-p user.info"
NOTICE="-p user.info"
WARN="-p user.warn"
ERROR="-p user.err"

logger -s -t "$TAG" "starting"

FSTAB=/etc/fstab
fstype=ext4

# look to see if cloud config automounted any ephemerals
# if so, unmount them and remove the entries from fstab

sig="comment=cloudconfig"
ccams=$( awk '/'"$sig"'/ {print $1}' /etc/fstab )

for dev in $ccams; do
  umount $dev
done

sed -i "/$sig/d" /etc/fstab


# resize the root volume in case it needs to be expanded

ROOTDEV=$( df -Pk / | grep /dev/[sx] | awk '{print $1}')
[ -d "$ROOTDEV" ] && resize2fs $ROOTDEV

# now, look for additional volumes that were attached
# this section needs awscli installed

# find my instance id

METADATA=http://169.254.169.254/latest/meta-data
I_ID=$( wget -q -O - $METADATA/instance-id )

# get the list of volumes on this instance sorted by their device name
volumes=$( aws --output text ec2 describe-volumes --query \
    'Volumes[*].Attachments[?InstanceId==`'$I_ID'`][Device,VolumeId]' | \
    sort | awk '{print $2}' )


logger -s -t "$TAG" "attachments: $volumes"

for v in $volumes; do
    # find the device name

    device=$( aws --output text ec2 describe-volumes --volume-ids $v \
        --query 'Volumes[0].Attachments[0].Device'
    )

    # find its mount point, from its name tag -> host:/mount

    name=$( aws --output text ec2 describe-volumes --volume-ids $v \
        --query 'Volumes[0].Tags[?Key==`Name`].Value'
    )

    mountpoint=$( echo $name | sed 's/^[^:]*://' )

    logger -s -t "$TAG" "volume $v $device $mountpoint"

    # handle the dev name change /dev/sdX -> /dev/xvdX
    # NOTE: this only works with newer virtualzations
    #       that map drives to the same drive letter

    xdevice="$device"
    if [[ "$device" = /dev/sd* ]]; then
        device=`echo $device | sed 's,/dev/sd,/dev/xvd',`
        logger -s -t "$TAG" "mapping $xdevice to $device"
    fi

    # make sure its okay to do the format and mount
    if [[ "$mountpoint" != /* ]]; then
        logger $WARN -s -t "$TAG" \
            "skipping $device, $mountpoint does not look like a directory"
        continue
    elif mountpoint -q "$mountpoint" ; then
        logger $WARN -s -t "$TAG" \
            "skipping $device, $mountpoint is already mounted"
        continue
    elif blkid $device ; then
        logger $WARN -s -t "$TAG" \
            "skipping $device, it looks like it is already formatted"
        continue
    fi

    # make sure device exists
    index=0
    while [ $index -lt $RETRIES -a ! -b $device ]; do
        (( index += 1 ))
        logger $WARN -s -t "$TAG" "waiting for $device to be attached"
        sleep $DELAY
    done
    if [ ! -b $dev ]; then
        logger $ERROR -s -t "$TAG" "device $device never attached"
        continue
    fi

    sleep $SHORT_DELAY

    logger -s -t "$TAG" "formatting $device as $fstype"
    mkfs.$fstype $device

    rc=$?
    if [ $rc != 0 ]; then
        logger $ERROR -s -t "$TAG" "mkfs failed for device $dev"
        continue
    fi

    logger -s -t "$TAG" "mounting $device on $mountpoint"
    mkdir -p $mountpoint > /dev/null 2>&1
    if grep -q >/dev/null 2>&1 $device /etc/fstab; then
        :
    else
        echo >> $FSTAB "$device  $mountpoint $fstype defaults,nofail 1 2"
    fi
    mount $mountpoint

    # now, set some permissions for special, well-known directories
    case "$mountpoint" in
	/tmp) chmod 1777 "$mountpoint" ;;
    esac

done

logger -s -t "$TAG" "finished"
