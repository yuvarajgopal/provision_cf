#!/bin/bash

CURRENT_RELEASE=current.release

usage() {
    cat <<EOF
usage: $0 version file ...

where
  version is of the form x.y.z

note
  current.release file must exist in the current directory
                  and contain the current version a.b.c

** UNDER CONSTRUCTION **

EOF
}

source $(dirname $0)/versioning.shlib

prog=$( basename $0 )


current_version="0.0.0"

if [ -r $CURRENT_RELEASE ] ; then
  current_version=$( cat $CURRENT_RELEASE )
else
    echo >&2 "$prog:error:$CURRENT_RELEASE file missing or unreadable"
    exit 2
fi

if [ $# -lt 2 ]; then
    echo >&2 "$prog:error:must supply version and at least one file"
    usage
    exit 1
fi

new_version="$1"
shift


if version_ok "$new_version" ; then
    :
else
    echo >&2 "$prog:error:$new_version is not a valid version"
    usage
    exit 1
fi


if version_gt "$new_version" "$current_version"; then
    :
else
    echo >&2 "$prog:error:$new_version must be greater than $current_version"
    exit 2
fi


for f in $@; do
    if [ ! -r "$f" ]; then
	echo >&2 "$prog:error: file $f not found or not readable"
	continue
    fi
    old_version=$(
	sed -n 's/^\s*VERSION(\([0-9][0-9]*\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\)).*$/\1.\2.\3/p' $f )
    if [ -n "$old_version" ]; then
	echo "$f is at $old_version, changing to $new_version"
	sed -i '/^\s*VERSION(/s/VERSION([0-9.]*)/VERSION('"$new_version"')/' $f
    else
	echo "$f has no VERSION"
    fi
done
