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

[ -n "${giturl}" ] || _abort "first argument with git URL required"
[ -n "${gitbranch}" ] || _abort "second argument with git branch required"

declare gitpath
declare rpmpath
declare scminfo
declare changes
declare version
declare pkgname
declare chart
declare image

rm -rf "${BUILDER_WORKDIR}"
trap cleanup EXIT

# Checkout code, compute version and compute changes
gitpath=$(checkout "${giturl}" "${gitbranch}")
scminfo=$(create_scminfo "${gitpath}" "${versionoffset}" "${parseversion}")
changes=$(create_changes_entry "${gitpath}" "${scminfo}" tests .github README.md)
version=$(OCIversion "${scminfo}")


#########################################
#             Prepare RPMs              #
#########################################
if [ -d "${gitpath}/.obs/specfile" ]; then
  while IFS= read -r -d '' pkgname; do
    pkgname=$(basename "${pkgname}")
    echo -n "Preparing ${pkgname} RPM sources at ${rpmpath} ..."

    rpmpath="${BUILDER_OUTPUT}/${pkgname}"
    mkdir -p "${rpmpath}"

    # Exclude tools and .git subfolders in generated tarball
    create_tarball_renameroot "${gitpath}" "${pkgname}" "${pkgname}" \
      "${pkgname}/tools" "${pkgname}/.git" "${pkgname}/tests" "${pkgname}/build"

    # Copy the specfile and contents, follows symlinks
    cp -L "${gitpath}/.obs/specfile/${pkgname}/"* "${rpmpath}"

    # Adding scminfo file, we add it in sources to keep it for reference
    cp "${scminfo}" "${rpmpath}"
    cp "${changes}" "${rpmpath}/${pkgname}.changes"

    # Update spec from SCM_INFO
    update_spec "${rpmpath}/${pkgname}.spec" "${scminfo}"

    echo "Done"
  done < <(find "${gitpath}/.obs/specfile" -mindepth 1 -maxdepth 1 -type d -print0)
fi


#########################################
#           Prepare charts              #
#########################################
if [ -d "${gitpath}/.obs/chartfile" ]; then
  while IFS= read -r -d '' chart; do
    chart=$(basename "${chart}")
    echo -n "Preparing ${chart} chart sources at ${BUILDER_OUTPUT}/${chart} ..."
    mkdir -p "${BUILDER_OUTPUT}/${chart}"

    # Create templates tarball
    create_tarball "${gitpath}/.obs/chartfile/${chart}/templates" "${chart}"

    # Copy chart contents without templates folder, follows symlinks
    rm -rf "${gitpath}/.obs/chartfile/${chart}/templates"
    cp -Lr "${gitpath}/.obs/chartfile/${chart}/"* "${BUILDER_OUTPUT}/${chart}"

    # Copy scminfo and changes entry files
    cp "${scminfo}" "${BUILDER_OUTPUT}/${chart}"
    cp "${changes}" "${BUILDER_OUTPUT}/${chart}/${chart}.changes"

    # Apply version
    sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${chart}/Chart.yaml"
    [ -f "${BUILDER_OUTPUT}/${chart}/values.yaml" ] && sed_substitution "%VERSION%" "${version}" "${BUILDER_OUTPUT}/${chart}/values.yaml" 

    echo "Done"
  done < <(find "${gitpath}/.obs/chartfile" -mindepth 1 -maxdepth 1 -type d -print0)
fi


#########################################
#           Prepare images              #
#########################################
if [ -d "${gitpath}/.obs/dockerfile" ]; then
  while IFS= read -r -d '' image; do
    image=$(basename "${image}")

    echo -n "Preparing ${image} sources at ${BUILDER_OUTPUT}/${image} ..."
    mkdir -p "${BUILDER_OUTPUT}/${image}"

    # Copy the Dockerfile and contents, follows symlinks
    cp -L "${gitpath}/.obs/dockerfile/${image}/"* "${BUILDER_OUTPUT}/${image}"

    # Copy scminfo and changes entry files
    cp "${scminfo}" "${BUILDER_OUTPUT}/${image}"
    cp "${changes}" "${BUILDER_OUTPUT}/${image}/${image}.changes"

    # Apply version, not mandatory for container images
    if [[ "${version}" != "null" ]]; then
      for dockerfile in "${BUILDER_OUTPUT}/${image}/Dockerfile"*; do 
        sed_substitution "%VERSION%" "${version}" "${dockerfile}"
      done
    fi

    echo "Done"
  done < <(find "${gitpath}/.obs/dockerfile" -mindepth 1 -maxdepth 1 -type d -print0)
fi
