#!/bin/sh

set -e

usage() {
	echo "usage: apply-patches.sh version component"
	exit 1
}

[ -z "$2" ] && usage

patchroot="/usr/src/patches/$1/$2"
patchseries="${patchroot}/series"

[ -f "${patchseries}" ] || { echo "no patches to apply for component $2 (version $1)"; exit 0; }

while read -r patch; do
	echo "Applying $patch ..."
	patch -p1 < "${patchroot}/${patch}"
done < ${patchseries}

