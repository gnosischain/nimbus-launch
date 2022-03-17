#!/usr/bin/env bash

set -e

cd /home/user/nimbus-eth2

make \
    -j$(nproc) \
    NIMFLAGS="-d:disableMarchNative" \
    PARTIAL_STATIC_LINKING=1 \
    QUICK_AND_DIRTY_COMPILER=1 \
    gnosis-chain-build
