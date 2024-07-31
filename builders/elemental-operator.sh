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
declare pkgname="elemental-operator"
declare chart="elemental-operator-helm"
declare crdchart="elemental-operator-crds-helm"
declare operatorimg="operator-image"
declare seedimg="seedimage-builder"

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
changes=$(create_changes_entry "${gitpath}" "${scminfo}" tests .github)

# Set obs packages paths
rpmpath="${BUILDER_OUTPUT}/${pkgname}"
version=$(OCIversion "${scminfo}")


#########################################
#        Elemental Operator RPM         #
#########################################
echo -n "Preparing ${pkgname} RPM sources at ${rpmpath} ..."
mkdir -p "${rpmpath}"

# Exclude tools and .git subfolders in generated tarball
create_tarball "${gitpath}" "${pkgname}" "${pkgname}/tools" "${pkgname}/.git"

# Adding new spec file
cp "${gitpath}/.obs/specfile/${pkgname}.spec" "${rpmpath}"

# Adding scminfo file, we add it in sources to keep it for reference
cp "${scminfo}" "${rpmpath}"
cp "${changes}" "${rpmpath}/${pkgname}.changes"

# Update spec from SCM_INFO
update_spec "${rpmpath}/${pkgname}.spec" "${scminfo}"

echo "Done"


#########################################
#     Elemental Operator CRDS chart     #
#########################################
echo -n "Preparing ${crdchart} chart sources at ${BUILDER_OUTPUT}/${crdchart} ..."
mkdir -p "${BUILDER_OUTPUT}/${crdchart}"

# Create templates tarball
create_tarball "${gitpath}/.obs/chartfile/crds/templates" "${crdchart}"

# Copy chart contents without templates folder
rm -rf "${gitpath}/.obs/chartfile/crds/templates"
cp -r "${gitpath}/.obs/chartfile/crds/"* "${BUILDER_OUTPUT}/${crdchart}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${crdchart}"
cp "${changes}" "${BUILDER_OUTPUT}/${crdchart}/${crdchart}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${crdchart}/Chart.yaml"

echo "Done"


#########################################
#  Elemental Operator controller chart  #
#########################################
echo -n "Preparing ${chart} sources at ${BUILDER_OUTPUT}/${chart} ..."
mkdir -p "${BUILDER_OUTPUT}/${chart}"

# Create templates tarball
create_tarball "${gitpath}/.obs/chartfile/operator/templates" "${chart}"

# Copy chart contents without templates folder
rm -rf "${gitpath}/.obs/chartfile/operator/templates"
cp -r "${gitpath}/.obs/chartfile/operator/"* "${BUILDER_OUTPUT}/${chart}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${chart}"
cp "${changes}" "${BUILDER_OUTPUT}/${chart}/${chart}.changes"

# Apply version
sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${chart}/Chart.yaml" "${BUILDER_OUTPUT}/${chart}/values.yaml" "${BUILDER_OUTPUT}/${chart}/questions.yaml"

echo "Done"


#########################################
#       Elemental Operator image        #
#########################################
echo -n "Preparing ${operatorimg} sources at ${BUILDER_OUTPUT}/${operatorimg} ..."
mkdir -p "${BUILDER_OUTPUT}/${operatorimg}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/operator/"* "${BUILDER_OUTPUT}/${operatorimg}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${operatorimg}"
cp "${changes}" "${BUILDER_OUTPUT}/${operatorimg}/${operatorimg}.changes"

# Apply version
sed_substitution "%OPERATOR_VERSION%" "${version}" "${BUILDER_OUTPUT}/${operatorimg}/Dockerfile"

echo "Done"


#########################################
#    Elemental Operator seed image      #
#########################################
echo -n "Preparing ${seedimg} sources at ${BUILDER_OUTPUT}/${seedimg} ..."
mkdir -p "${BUILDER_OUTPUT}/${seedimg}"

# Copy the Dockerfile and contents
cp "${gitpath}/.obs/dockerfile/seedimage/"* "${BUILDER_OUTPUT}/${seedimg}"

# Copy scminfo and changes entry files
cp "${scminfo}" "${BUILDER_OUTPUT}/${seedimg}"
cp "${changes}" "${BUILDER_OUTPUT}/${seedimg}/${seedimg}.changes"

# Apply version
sed_substitution "%OPERATOR_VERSION%" "${version}" "${BUILDER_OUTPUT}/${seedimg}/Dockerfile"

echo "Done"
