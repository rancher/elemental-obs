#!/bin/bash

set -e

declare SCRIPT_PATH

SCRIPT_PATH="$(dirname "$(realpath -s "${0}")")"

# shellcheck disable=SC1091
type create_scminfo > /dev/null 2>&1 || . "${SCRIPT_PATH}/common.sh"

declare giturl=$1
declare gitbranch=$2
declare parseversion=${3:-patch}
declare versionoffset=${4:-no}
declare pkgname="elemental"
declare baremetalimg="SL-Micro-baremetal-container"
declare kvmimg="SL-Micro-kvm-container"
declare baseimg="SL-Micro-base-container"
declare rtimg="SL-Micro-rt-container"
declare baremetaliso="build-baremetal-iso-image"
declare kvmiso="build-kvm-iso-image"
declare baseiso="build-base-iso-image"
declare rtiso="build-rt-iso-image"

[ -n "${giturl}" ] || _abort "first argument with git URL required"
[ -n "${gitbranch}" ] || _abort "second argument with git branch required"

declare gitpath
declare rpmpath
declare scminfo
declare changes
declare version

rm -rf "${BUILDER_WORKDIR}"
trap cleanup EXIT

# Checkout code, compute version and compute changes
gitpath=$(checkout "${giturl}" "${gitbranch}")
scminfo=$(create_scminfo "${gitpath}" "${versionoffset}" "${parseversion}")
changes=$(create_changes_entry "${gitpath}" "${scminfo}")

# Set obs packages paths
rpmpath="${BUILDER_OUTPUT}/${pkgname}"
version=$(OCIversion "${scminfo}")


#########################################
#           Elemental RPM               #
#########################################
echo -n "Preparing ${pkgname} RPM sources at ${rpmpath} ..."
mkdir -p "${rpmpath}"

# Exclude tests, scripts and .git subfolders in generated tarball
create_tarball "${gitpath}" "${pkgname}" "${pkgname}/tests" "${pkgname}/.git" "${pkgname}/scripts"

# Adding new spec file
cp "${gitpath}/.obs/specfile/${pkgname}.spec" "${rpmpath}"
cp "${gitpath}/.obs/specfile/elemental-rpmlintrc" "${rpmpath}"

# Adding scminfo file, we add it in sources to keep it for reference
cp "${scminfo}" "${rpmpath}"
cp "${changes}" "${rpmpath}/${pkgname}.changes"

# Update spec from SCM_INFO
update_spec "${rpmpath}/${pkgname}.spec" "${scminfo}"

echo "Done"

