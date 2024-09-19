#!/bin/bash -x

: ${TOPDIR:=/usr/src/packages}

container="buildcont"

function cleanup_and_exit {
  buildah umount "${container}"
  buildah rm "${container}"
  
  exit 0
}

set -e

img=$(ls ${TOPDIR}/DOCKER/*.tar) || true

# Only consider images with 'iso' or 'disk' as part of the name
[ -f "${img}" ] || exit 0
echo "${img}" | grep -q "iso\|disk" || exit 0

echo "Extracting image from container"

buildah from --name "${container}"  "docker-archive:${img}"

mnt=$(buildah mount "${container}")

iso=$(ls "${mnt}"/elemental-iso/*.iso) || true
disk=$(ls "${mnt}"/elemental-disk/*.raw) || true

mkdir -p "${TOPDIR}/OTHER"

if [ -f "${iso}" ]; then
  cp "${iso}" "${TOPDIR}/OTHER"
  cp "${iso}.sha256" "${TOPDIR}/OTHER"
elif [ -f "${disk}" ]; then
  cp "${disk}" "${TOPDIR}/OTHER"
fi

cleanup_and_exit

