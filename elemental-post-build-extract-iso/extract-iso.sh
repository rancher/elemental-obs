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

# Only consider images with 'iso' as part of the name
[ -f "${img}" ] || exit 0
echo "${img}" | grep -q iso || exit 0

echo "Extracting ISO from container image"

buildah from --name "${container}"  "docker-archive:${img}"

mnt=$(buildah mount "${container}")

ls "${mnt}"

iso=$(ls "${mnt}"/elemental-iso/*.iso) || true

[ -f "${iso}" ] || cleanup_and_exit

mkdir -p "${TOPDIR}/OTHER"

cp "${iso}" "${TOPDIR}/OTHER"
cp "${iso}.sha256" "${TOPDIR}/OTHER"

cleanup_and_exit

