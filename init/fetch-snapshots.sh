#!/usr/bin/env bash
set -euo pipefail

# Prep reth datadir
if [ -n "${RETH_SNAPSHOT}" ] && [ ! -d "/reth/data/static_files/" ]; then
  __dont_rm=0
  mkdir -p /reth/data
  mkdir -p /reth/snapshot
  cd /reth/snapshot

  eval "__url=${RETH_SNAPSHOT}"
#shellcheck disable=SC2154
  aria2c -c -x6 -s6 --auto-file-renaming=false --conditional-get=true --allow-overwrite=true "${__url}"
  filename=$(echo "${__url}" | awk -F/ '{print $NF}')
  if [[ "${filename}" =~ \.tar\.zst$ ]]; then
    pzstd -c -d "${filename}" | tar xvf - -C /reth/data
  elif [[ "${filename}" =~ \.tar\.gz$ || "${filename}" =~ \.tgz$ ]]; then
    tar xzvf "${filename}" -C /reth/data
  elif [[ "${filename}" =~ \.tar$ ]]; then
    tar xvf "${filename}" -C /reth/data
  elif [[ "${filename}" =~ \.lz4$ ]]; then
    lz4 -d "${filename}" | tar xvf - -C /reth/data
  else
    __dont_rm=1
    echo "The reth snapshot file has a format that Botanix Docker can't handle."
    echo "Please come to CryptoManufaktur Discord to work through this."
  fi
  if [ "${__dont_rm}" -eq 0 ]; then
    rm -f "${filename}"
  fi

  # try to find the directory
  __search_dir="static_files"
  __base_dir="/reth/data/"
  __found_path=$(find "$__base_dir" -type d -path "*/$__search_dir" -print -quit)
  if [ -n "$__found_path" ]; then
    __reth_dir=$(dirname "$__found_path")
    __reth_dir=${__reth_dir%/static_files}
    if [ "${__found_path}" = "${__base_dir}static_files" ]; then
       echo "Snapshot extracted into ${__reth_dir}"
    else
      echo "Found a reth directory at ${__reth_dir}, moving it."
      mv "$__reth_dir"/* "$__base_dir"
      rm -rf "$__reth_dir"
    fi
  fi

  # Set owner correctly from reth dockerfile
  chown 10003:10003 -R /reth/data

  if [[ ! -d /reth/data/static_files ]]; then
    echo "Reth data isn't in the expected location."
    echo "This reth snapshot likely won't work until the fetch script has been adjusted for it."
  fi
fi

# Prep cometbft datadir
if [ -n "${COMETBFT_SNAPSHOT}" ] && [ ! -d "/cometbft/data/state.db" ]; then
  __dont_rm=0
  mkdir -p /cometbft/data
  mkdir -p /cometbft/snapshot
  cd /cometbft/snapshot

  eval "__url=${COMETBFT_SNAPSHOT}"
  aria2c -c -x6 -s6 --auto-file-renaming=false --conditional-get=true --allow-overwrite=true "${__url}"
  filename=$(echo "${__url}" | awk -F/ '{print $NF}')
  if [[ "${filename}" =~ \.tar\.zst$ ]]; then
    pzstd -c -d "${filename}" | tar xvf - -C /cometbft/data
  elif [[ "${filename}" =~ \.tar\.gz$ || "${filename}" =~ \.tgz$ ]]; then
    tar xzvf "${filename}" -C /cometbft/data
  elif [[ "${filename}" =~ \.tar$ ]]; then
    tar xvf "${filename}" -C /cometbft/data
  elif [[ "${filename}" =~ \.lz4$ ]]; then
    lz4 -d "${filename}" | tar xvf - -C /cometbft/data
  else
    __dont_rm=1
    echo "The cometbft snapshot file has a format that Botanix Docker can't handle."
    echo "Please come to CryptoManufaktur Discord to work through this."
  fi
  if [ "${__dont_rm}" -eq 0 ]; then
    rm -f "${filename}"
  fi

  # try to find the directory
  __search_dir="state.db"
  __base_dir="/cometbft/data/"
  __found_path=$(find "$__base_dir" -type d -path "*/$__search_dir" -print -quit)
  if [ -n "$__found_path" ]; then
    __cometbft_dir=$(dirname "$__found_path")
    __cometbft_dir=${__cometbft_dir%/db}
    if [ "${__found_path}" = "${__base_dir}state.db" ]; then
       echo "Snapshot extracted into ${__cometbft_dir}"
    else
      echo "Found a cometbft directory at ${__cometbft_dir}/state.db, moving it."
      mv "$__cometbft_dir"/* "$__base_dir"
      rm -rf "$__cometbft_dir"
    fi
  fi

  # Set owner correctly from cometbft dockerfile
  chown 10001:10001 -R /cometbft/data

  if [[ ! -d /cometbft/data/state.db ]]; then
    echo "Cometbft data isn't in the expected location."
    echo "This cometbft snapshot likely won't work until the fetch script has been adjusted for it."
  fi
fi