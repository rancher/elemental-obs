#!/bin/bash

declare BUILDER
declare ROOT_PATH
declare BUILDER_OUTPUT
declare BUILDER_WORKDIR

BUILDER="$(realpath -s "${0}")"
ROOT_PATH="$(dirname "${BUILDER}")"
BUILDER_OUTPUT="${ROOT_PATH}/build"
BUILDER_WORKDIR="${ROOT_PATH}/workdir"

: "${SCM_INFO:=_scminfo}"
: "${CHANGES_ENTRY:=newentry.changes}"

declare re_major="^([0-9]+)(-[0-9a-z]+)?"
declare re_minor="^([0-9]+(\.[0-9]+){0,1})(-[0-9a-z]+)?"
declare re_patch="^([0-9]+(\.[0-9]+){0,2})(-[0-9a-z]+)?"
declare re_all="(.*)"


#########################################
#           Functions library           #
#########################################

function _abort {
  echo "$@" && exit 1
}


# check_work_tree checks the given path is a git repository work tree
function check_work_tree {
  local path=$1
  local check
  local error_msg="error checking work tree:"

  pushd "${path}" > /dev/null || _abort "${error_msg} pushd failed"
    check=$(git rev-parse --is-inside-work-tree || true)
  popd > /dev/null || _abort "${error_msg} popd failed"
  [[ "${check}" == "true" ]] || _abort "${error_msg} not in a git work tree"
}


# Checkout the given git repository URL to the basename of the url
# Second argument is the branch to checkout, defaults to main if missing.
function checkout {
  local url=$1
  local branch=${2:-main}
  local basepath
  local error_msg="error checking out code:"

  basepath="$(basename "${url}")"

  mkdir -p "${BUILDER_WORKDIR}"
  
  pushd "${BUILDER_WORKDIR}" > /dev/null || _abort "${error_msg} pushd failed"
    git clone "${url}" -b "${branch}" --single-branch "${basepath}"
  popd > /dev/null || _abort "${error_msg} popd failed"

  if [ -d "${BUILDER_WORKDIR}/${basepath}" ]; then
    echo "${BUILDER_WORKDIR}/${basepath}"
  else
    _abort "${error_msg} checked out sources '${BUILDER_WORKDIR}/${basepath}' not found"
  fi
}


# create_scminfo creates a _scminfo file to store commit hash, commit date and computed
# version based on partent tag for the given git checkout. Parent tag is required to follow
# MAJOR.MINOR.PATCH-PRERELEASE scheme.
#
# First argument is the checkout path, second argument is to include or not a git commit
# offset to the computed version and third argument is to parse the version to a certain
# level (MAJOR, MINOR or PATCH) ignoring the rest.
#
function create_scminfo {
  local tag
  local cdate
  local chash
  local version
  local versionRPM
  local versionOCI
  local regex
  local path=$1
  local offset=${2:-no}
  local parseversion=${3:-none}
  local error_msg="error creating ${SCM_INFO}:"

  [ -n "${path}" ] || _abort "${error_msg} at least first argument is required"

  case ${parseversion} in
    major)
      regex="${re_major}"
      ;;
    minor)
      regex="${re_minor}"
      ;;
    patch)
      regex="${re_patch}"
      ;;
    none)
      regex=none
      ;;
    *)
      regex="${re_all}"
      ;;
  esac

  check_work_tree "${path}"
  pushd "${path}" > /dev/null || _abort "${error_msg} pushd failed"

    tag=$(git describe --abbrev=0 --tags)
    pretag=$(git describe --abbrev=0 --tags "${tag}^" || true)
    chash=$(git rev-parse HEAD)
    cdate=$(git show --no-patch --format=%cd --date=format:'%s')
    ccount=$(git rev-list "${tag}..HEAD" --count)

    version=${tag##v}

    if [[ "${regex}" == "none" ]]; then
      version="null"
    elif [[ "${version}" =~ ${regex} ]]; then
      version="${BASH_REMATCH[0]}"
    else
      _abort "Invalid version string: '${version}'"
    fi

    if [[ "${offset}" == "yes" ]]; then
      version="${version}+git$(date -d @"${cdate}" +%Y%m%d).${chash:0:7}"
    fi

    versionRPM=${version/-/\~}
    versionOCI=${version/+/_}

    mkdir -p "${BUILDER_OUTPUT}"

    {
      echo "tag: ${tag}"
      echo "mtime: ${cdate}"
      echo "commit: ${chash}"
      echo "versionRPM: ${versionRPM}"
      echo "versionOCI: ${versionOCI}"
    } > "${BUILDER_OUTPUT}/${SCM_INFO}"

  popd > /dev/null || _abort "${error_msg} popd failed"
  echo "${BUILDER_OUTPUT}/${SCM_INFO}" 
}


# create_changes_entry creates an OBS changelog entry
# from the git history. It takes as arguments the git checkout
# path, the scminfo file (which contains some information such
# the most recent tag, HEAD date, etc.) and a list of
# paths relative the git root to exclude from logs.
# TODO: would be nice to also have a way to provide includes
# instead of excludes. Probaby we need a toggle for that.
function create_changes_entry {
  local path=$1
  local scminfo=$2
  local excludes=()
  local tag
  local pretag
  local ccount
  local header
  local dashes
  local scope
  local starter
  local datef="%a %b %e %H:%M:%S %Z %Y"
  local error_msg="error creating new changes entry:"

  # Setting the OBS entry format
  dashes="$( printf -- "-%.0s" {1..67} )"
  header="${dashes}%n%cd - %an <%ae>"

  [ -d "${path}" ] || _abort "${error_msg} path '${path}' is not a directory"
  [ -f "${scminfo}" ] || _abort "${error_msg} ${scminfo} file not found"

  shift; shift
  for exclude in "$@"; do
    excludes+=(":^${exclude}")
  done

  tag="$(grep "tag:" < "${scminfo}" | cut -d" " -f 2)"

  check_work_tree "${path}"
  pushd "${path}" > /dev/null || _abort "${error_msg} pushd failed"

    pretag=$(git describe --abbrev=0 --tags "${tag}^" || true)
    ccount=$(git rev-list "${tag}..HEAD" --count)

    if [ "${ccount}" -eq 0 ]; then
      scope="${pretag}..${tag}"
      starter="Update to ${tag}:"
    else
      starter="Changes on top of ${tag}:"
      scope="${tag}..HEAD"
    fi

    {
      git show --format="${header}%n%n- ${starter}" \
        --date="format-local:${datef}" -s "HEAD"
      git log --no-patch --no-merges --cherry-pick --format="%w(77,2,12)* %h %s" \
	"${scope}" -- . "${excludes[@]}"
      # Add empty line
      echo ""
    } > "${BUILDER_OUTPUT}/${CHANGES_ENTRY}" 

  popd > /dev/null || _abort "${error_msg} popd failed"
  echo "${BUILDER_OUTPUT}/${CHANGES_ENTRY}" 
}


# create_tarball creates an xz compressed tarball of the given folder.
# First argument is the source folder to make a tarball of and the
# second argument is the destination folder of the tarball (relative
# to BUILDER_OUTPUT).
#
# Further arguments are excluded subpaths under the given folder.
#
# Usage:
#   create_tarball SRC_FOLDER DST_FOLDER [exclude_paths...]
#
function create_tarball {
  local src=$1
  local dst=$2
  local excludes=()
  local basepath
  local error_msg="error creating tarball:"

  basepath="$(basename "${src}")"

  [ "$#" -lt 2 ] && _abort "${error_msg} two arguments required"
  [ -d "${src}" ] || _abort "${error_msg} '${src}' is not a directory"

  shift; shift
  for exclude in "$@"; do
    excludes+=("--exclude=${exclude}")
  done

  pushd "$(dirname "${src}")" > /dev/null || _abort "${error_msg} popd failed"
    tar --sort=name --mtime="@0" --owner=0 --group=0 \
      --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
      -caf "${basepath}.tar.xz" "${excludes[@]}" "${basepath}" 
  
    mkdir -p "${BUILDER_OUTPUT}/${dst}"
    mv "${basepath}.tar.xz" "${BUILDER_OUTPUT}/${dst}"
  popd > /dev/null || _abort "${error_msg} popd failed"
}


# update_spec updates the given specfile with the version, commit hash and
# commit date taken from the given scminfo file
function update_spec {
  local spec=$1
  local scminfo=$2
  local version
  local cdate
  local chash
  local mtime
  local error_msg="error updating spec file:"

  [ -f "${spec}" ] || _abort "${error_msg} '${spec}' specfile not found"
  [ -f "${scminfo}" ] || _abort "${error_msg} '${scminfo}' scminfo file not found"

  version="$(grep "versionRPM:" < "${scminfo}" | cut -d" " -f 2)"
  mtime="$(grep "mtime:" < "${scminfo}" | cut -d" " -f 2)"
  chash="$(grep "commit:" < "${scminfo}" | cut -d" " -f 2)"
  cdate="$(date -d @"${mtime}" +%Y%m%d)"

  sed_substitution "^\(%define commit\) _replaceme_" "\1 ${chash}" "${spec}"
  sed_substitution "^\(%define c_date\) _replaceme_" "\1 ${cdate}" "${spec}"
  sed_substitution "^\(Version: *\)0$" "\1${version}" "${spec}"
}


# sed_substitution runs a substitution on the given file using needle and replace expressions
# if the substitution fails to run a match sed fails with error code 100
function sed_substitution {
  local needle=$1
  local replace=$2
  local file
  local changes="changes.log"
  local error_msg="error sed_substitution:"

  [ "$#" -lt 3 ] && _abort "${error_msg} at least 3 arguments are required"
  
  shift; shift
  for file in "$@"; do
    [ -f "${file}" ] || _abort "${error_msg} '${file}' not found"

    sed  -i "s|${needle}|${replace}|w ${BUILDER_WORKDIR}/${changes}" "${file}"
    if [ ! -s "${BUILDER_WORKDIR}/${changes}" ]; then
      _abort "${error_msg} no changes were applied"
    fi
    rm -f "${BUILDER_WORKDIR}/${changes}"
  done
}


# OCIversion returns the OCI version from the scminfo file
function OCIversion {
  local scminfo=$1
  local version
  local error_msg="error getting OCIversion:"

  [ -f "${scminfo}" ] || _abort "${error_msg} '${scminfo}' file not found"

  version="$(grep "versionOCI:" < "${scminfo}" | cut -d" " -f 2)"
  echo "${version}"
}


# RPMversion returns the OCI version from the scminfo file
function RPMversion {
  local scminfo=$1
  local version
  local error_msg="error getting RPMversion:"

  [ -f "${scminfo}" ] || _abort "${error_msg} '${scminfo}' file not found"

  version="$(grep "versionRPM:" < "${scminfo}" | cut -d" " -f 2)"
  echo "${version}"
}


# cleanup removes working directory, scminfo and changes file
function cleanup {
  rm -rf "${BUILDER_WORKDIR}" "${BUILDER_OUTPUT:?}/${SCM_INFO}" "${BUILDER_OUTPUT:?}/${CHANGES_ENTRY}"
}


# update_changes takes a changes files and adds a new given entry. If the last entry
# in file was a tag it is pre-appended or substituted otherwise.
#
# TODO: some logic to detect retagging is missing (e.g. 1.2.3-rc2 is
# retagged to 1.2.3). I guess scminfo is required for that
function update_changes {
  local newchanges=$1
  local changeslog=$2
  local error_msg="error updating changes:"
  local linenum

  [ "$#" -eq 2 ] || _abort "${error_msg} two arguments are required"
  [ -f "${newchanges}" ] || _abort "${error_msg} new changes file '${newchanges}' not found"
  [ -f "${changeslog}" ] || _abort "${error_msg} previous changes file '${changeslog}' not found"

  # Compare the start of the last entry with the current one to prevent duplicates
  if [[ "$(head -n 4 "${changeslog}")" == "$(head -n 4 "${newchanges}")" ]]; then
    # Do not update changelog
    cat "${changeslog}" > "${newchanges}"
    return
  fi


  # Check if last entry was on a tag or not, if no tag replace it
  if head -n 4 "${changeslog}" | grep -q "Changes on top of"; then
    linenum="$(awk '/^--------+$/{ c++; if (c >=2) {print NR-1; exit} }' "${changeslog}")"
    sed "1,${linenum} d" "${changeslog}" >> "${newchanges}"
    return
  fi

  cat "${changeslog}" >> "${newchanges}"
}


# new_changes creates an initial changelog entry. It basically drops all generated changes from git
# to a static 'Initial commit' style message. The given changes file must already exist and it is modified
# by this method.
#
# Used if this is expected to be the first
# changelog entry in changes file.
function new_changes {
  local changes=$1
  local tmpchanges

  [ "$#" -eq 1 ] || _abort "${error_msg} one argument is required"
  [ -f "${changes}" ] || _abort "${error_msg} given changes file '${changes}' not found"

  tmpchanges="${changes}.tmp"

  head -n 3 "${changes}" > "${tmpchanges}"
  echo "- Initial commit" >> "${tmpchanges}"
  mv "${tmpchanges}" "${changes}"
}
