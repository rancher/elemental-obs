#!/bin/bash

set -e

declare SCRIPT_PATH

SCRIPT_PATH="$(dirname "$(realpath -s "${0}")")"

# shellcheck disable=SC1091
type create_scminfo > /dev/null 2>&1 || . "${SCRIPT_PATH}/common.sh"

declare pkgname
declare pkgoutput

pushd "${ROOT_PATH:?}/.." > /dev/null || _abort "update-sources: pushd failed"

  check_work_tree "$(pwd)" || _abort "not in a git work tree"

  [ -d "${BUILDER_OUTPUT}" ] || _abort "'${BUILDER_OUTPUT}' directory not found"

  for pkgoutput in "${BUILDER_OUTPUT}"/*; do
    pkgname="$(basename "${pkgoutput}")"
  
    [ -d "${pkgname}" ] || continue
    [ -f "${pkgname}/${pkgname}.changes" ] || _abort "${pkgname}.changes file not found"
    [ -f "${pkgoutput}/${pkgname}.changes" ] || _abort "${pkgoutput}/${pkgname}.changes file not found"

    update_changes "${pkgoutput}/${pkgname}.changes" "${pkgname}/${pkgname}.changes"

    rm -rf "${pkgname:?}"/*
    cp -v "${pkgoutput}"/* "${pkgname}"

    echo "'${pkgname}' updated"
  done
popd > /dev/null || _abort "update-sources: pushd failed"
