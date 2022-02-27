#!/usr/bin/env bash

# Copyright (c) 2020-2021 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -e

cd /home/user/nimbus-eth2
git config --global core.abbrev 8

if [[ -z "${1}" ]]; then
  echo "Usage: $(basename ${0}) PLATFORM"
  exit 1
fi
PLATFORM="${1}"
BINARIES="nimbus_beacon_node_gnosis"

make clean
NIMFLAGS="-d:disableMarchNative --gcc.options.debug:'-g1' --clang.options.debug:'-gline-tables-only' "
NIMFLAGS+="-d:gnosisChainBinary -d:has_genesis_detection "
NIMFLAGS+="-d:SLOTS_PER_EPOCH=16 -d:SECONDS_PER_SLOT=5 -d:BASE_REWARD_FACTOR=25 -d:EPOCHS_PER_SYNC_COMMITTEE_PERIOD=512"
make -j$(nproc) \
    LOG_LEVEL="TRACE" \
    NIMFLAGS="${NIMFLAGS}" \
    PARTIAL_STATIC_LINKING=1 \
    QUICK_AND_DIRTY_COMPILER=1 \
    nimbus_beacon_node
cp build/nimbus_beacon_node build/nimbus_beacon_node_gnosis

# archive directory (we need the Nim compiler in here)
PREFIX="nimbus-eth2_${PLATFORM}_"
GIT_COMMIT="$(git rev-parse --short HEAD)"
VERSION="$(./env.sh nim --verbosity:0 --hints:off --warnings:off scripts/print_version.nims)"
DIR="${PREFIX}${VERSION}_${GIT_COMMIT}"
DIST_PATH="dist/${DIR}"
# delete old artefacts
rm -rf "dist/${PREFIX}"*.tar.gz
if [[ -d "${DIST_PATH}" ]]; then
  rm -rf "${DIST_PATH}"
fi

mkdir -p "${DIST_PATH}"
mkdir "${DIST_PATH}/scripts"
mkdir "${DIST_PATH}/build"

# copy and checksum binaries, copy scripts and docs
for BINARY in ${BINARIES}; do
  cp -a "./build/${BINARY}" "${DIST_PATH}/build/"
  if [[ "${PLATFORM}" =~ macOS ]]; then
    # debug info
    cp -a "./build/${BINARY}.dSYM" "${DIST_PATH}/build/"
  fi
  cd "${DIST_PATH}/build"
  sha512sum "${BINARY}" > "${BINARY}.sha512sum"
  if [[ "${PLATFORM}" == "Windows_amd64" ]]; then
    mv "${BINARY}" "${BINARY}.exe"
  fi
  cd - >/dev/null
done
sed -e "s/GIT_COMMIT/${GIT_COMMIT}/" docker/dist/README.md.tpl > "${DIST_PATH}/README.md"

if [[ "${PLATFORM}" == "Linux_amd64" ]]; then
  sed -i -e 's/^make dist$/make dist-amd64/' "${DIST_PATH}/README.md"
elif [[ "${PLATFORM}" == "Linux_arm32v7" ]]; then
  sed -i -e 's/^make dist$/make dist-arm/' "${DIST_PATH}/README.md"
elif [[ "${PLATFORM}" == "Linux_arm64v8" ]]; then
  sed -i -e 's/^make dist$/make dist-arm64/' "${DIST_PATH}/README.md"
elif [[ "${PLATFORM}" == "Windows_amd64" ]]; then
  sed -i -e 's/^make dist$/make dist-win64/' "${DIST_PATH}/README.md"
  cp -a docker/dist/README-Windows.md.tpl "${DIST_PATH}/README-Windows.md"
elif [[ "${PLATFORM}" == "macOS_amd64" ]]; then
  sed -i -e 's/^make dist$/make dist-macos/' "${DIST_PATH}/README.md"
elif [[ "${PLATFORM}" == "macOS_arm64" ]]; then
  sed -i -e 's/^make dist$/make dist-macos-arm64/' "${DIST_PATH}/README.md"
fi

# create the tarball
cd dist
tar czf "${DIR}.tar.gz" "${DIR}"
# don't leave the directory hanging around
rm -rf "${DIR}"
cd - >/dev/null
