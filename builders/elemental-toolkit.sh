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
declare pkgname="elemental-toolkit"

[ -n "${giturl}" ] || _abort "first argument with git URL required"
[ -n "${gitbranch}" ] || _abort "second argument with git branch required"

declare gitpath
declare rpmpath
declare scminfo
declare changes

# Checkout code, compute version and compute changes
gitpath=$(checkout "${giturl}" "${gitbranch}")
scminfo=$(create_scminfo "${gitpath}" "${versionoffset}" "${parseversion}")
changes=$(create_changes_entry "${gitpath}" "${scminfo}")

# Set obs packages paths
rpmpath="${BUILDER_OUTPUT}/${pkgname}"


#########################################
#        Elemental Toolkit RPM         #
#########################################
echo -n "Preparing ${pkgname} RPM sources at ${BUILDER_OUTPUT}/${pkgname} ..."
mkdir -p "${BUILDER_OUTPUT}/${pkgname}"

# Exclude tools and .git subfilders in generated tarball
create_tarball "${gitpath}" "${pkgname}" "${pkgname}/build" "${pkgname}/.git" "${pkgname}/tests"

# Adding new spec file
cp "${gitpath}/.obs/specfile/${pkgname}.spec" "${rpmpath}"

# Adding scminfo file, we add it in sources to keep it for reference
cp "${scminfo}" "${rpmpath}"
cp "${changes}" "${rpmpath}/${pkgname}.changes"

# Update spec from SCM_INFO
update_spec "${rpmpath}/${pkgname}.spec" "${scminfo}"

echo "Done"
