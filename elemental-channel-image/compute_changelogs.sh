#!/bin/bash

function _abort {
  echo "$@" && exit 1
}

channelJson=$1
packagesTar=$2
updatesInfo=$3

changeLogsDir=/busybox/changelogs

afterDate=0

set -e

tar xaf "${packagesTar}"

mkdir -p "${changeLogsDir}"

for mos in $(jq -r '[.[] | select(.spec.type == "container")] | reverse | .[].metadata.name' < "${channelJson}"); do 
  [ -f "${mos}.packages" ] || _abort "Cloud not find ${mos}.packages file"

  beforeDate=$(jq -r ".[] | select(.metadata.name == \"${mos}\").spec.metadata.created" < "${channelJson}")

  updatesparser --json --packages "${mos}.packages" --afterDate "${afterDate}" --beforeDate "${beforeDate}" --output "${changeLogsDir}/${mos}.updates.log" "${updatesInfo}"

  rm "${mos}.packages"
  afterDate=${beforeDate}
done
