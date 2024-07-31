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
changes=$(create_changes_entry "${gitpath}" "${scminfo}" tests README.md .github)

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


#########################################
#         SL Micro base image           #
#########################################
echo -n "Preparing ${baseimg} sources at ${BUILDER_OUTPUT}/${baseimg} ..."
mkdir -p "${BUILDER_OUTPUT}/${baseimg}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-base-os/"* "${BUILDER_OUTPUT}/${baseimg}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${baseimg}"
cp "${changes}" "${BUILDER_OUTPUT}/${baseimg}/${baseimg}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${baseimg}/Dockerfile"

echo "Done"


#########################################
#         SL Micro base ISO             #
#########################################
echo -n "Preparing ${baseiso} sources at ${BUILDER_OUTPUT}/${baseiso} ..."
mkdir -p "${BUILDER_OUTPUT}/${baseiso}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-base-iso/"* "${BUILDER_OUTPUT}/${baseiso}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${baseiso}"
cp "${changes}" "${BUILDER_OUTPUT}/${baseiso}/${baseiso}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${baseiso}/Dockerfile"

echo "Done"


#########################################
#      SL Micro baremetal image         #
#########################################
echo -n "Preparing ${baremetalimg} sources at ${BUILDER_OUTPUT}/${baremetalimg} ..."
mkdir -p "${BUILDER_OUTPUT}/${baremetalimg}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-baremetal-os/"* "${BUILDER_OUTPUT}/${baremetalimg}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${baremetalimg}"
cp "${changes}" "${BUILDER_OUTPUT}/${baremetalimg}/${baremetalimg}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${baremetalimg}/Dockerfile"

echo "Done"


#########################################
#      SL Micro baremetal ISO           #
#########################################
echo -n "Preparing ${baremetaliso} sources at ${BUILDER_OUTPUT}/${baremetaliso} ..."
mkdir -p "${BUILDER_OUTPUT}/${baremetaliso}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-baremetal-iso/"* "${BUILDER_OUTPUT}/${baremetaliso}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${baremetaliso}"
cp "${changes}" "${BUILDER_OUTPUT}/${baremetaliso}/${baremetaliso}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${baremetaliso}/Dockerfile"

echo "Done"


#########################################
#         SL Micro kvm image            #
#########################################
echo -n "Preparing ${kvmimg} sources at ${BUILDER_OUTPUT}/${kvmimg} ..."
mkdir -p "${BUILDER_OUTPUT}/${kvmimg}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-kvm-os/"* "${BUILDER_OUTPUT}/${kvmimg}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${kvmimg}"
cp "${changes}" "${BUILDER_OUTPUT}/${kvmimg}/${kvmimg}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${kvmimg}/Dockerfile"

echo "Done"


#########################################
#         SL Micro kvm ISO              #
#########################################
echo -n "Preparing ${kvmiso} sources at ${BUILDER_OUTPUT}/${kvmiso} ..."
mkdir -p "${BUILDER_OUTPUT}/${kvmiso}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-kvm-iso/"* "${BUILDER_OUTPUT}/${kvmiso}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${kvmiso}"
cp "${changes}" "${BUILDER_OUTPUT}/${kvmiso}/${kvmiso}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${kvmiso}/Dockerfile"

echo "Done"


#########################################
#         SL Micro rt image             #
#########################################
echo -n "Preparing ${rtimg} sources at ${BUILDER_OUTPUT}/${rtimg} ..."
mkdir -p "${BUILDER_OUTPUT}/${rtimg}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-rt-os/"* "${BUILDER_OUTPUT}/${rtimg}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${rtimg}"
cp "${changes}" "${BUILDER_OUTPUT}/${rtimg}/${rtimg}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${rtimg}/Dockerfile"

echo "Done"


#########################################
#         SL Micro rt ISO             #
#########################################
echo -n "Preparing ${rtiso} sources at ${BUILDER_OUTPUT}/${rtiso} ..."
mkdir -p "${BUILDER_OUTPUT}/${rtiso}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/micro-rt-iso/"* "${BUILDER_OUTPUT}/${rtiso}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${rtiso}"
cp "${changes}" "${BUILDER_OUTPUT}/${rtiso}/${rtiso}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${rtiso}/Dockerfile"

echo "Done"
