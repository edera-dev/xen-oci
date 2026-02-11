#!/bin/sh

set -e

usage() {
	echo "usage: apply-patches.sh patchdir version component"
	exit 1
}

[ -z "$3" ] && usage

patchroot="$1/$2/$3"
patchseries="${patchroot}/series"

[ -f "${patchseries}" ] || {
	echo "no patches to apply for component $3 (version $2)"
	exit 0
}

while read -r patch; do
	echo "Applying $patch ..."
	patch --forward -p1 <"${patchroot}/${patch}"
done <${patchseries}
