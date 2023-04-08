#!/bin/bash

if [[ "$(pwd)" != *omni-tx ]]; then
    cd "$(yarn bin)"/../omni-tx/
fi

HARDHAT="$(pwd)"/node_modules/hardhat/internal/cli/bootstrap.js

echo "forking mainnets..."

$HARDHAT node --config hardhat-fork/ethereum.config.ts --port 8001 1>/dev/null&
$HARDHAT node --config hardhat-fork/bsc.config.ts --port 8056 1>/dev/null&
$HARDHAT node --config hardhat-fork/polygon.config.ts --port 8137 1>/dev/null&
$HARDHAT node --config hardhat-fork/avalanche.config.ts --port 51114 1>/dev/null&
$HARDHAT node --config hardhat-fork/optimism.config.ts --port 8010 1>/dev/null&
$HARDHAT node --config hardhat-fork/arbitrum.config.ts --port 50161 1>/dev/null&
$HARDHAT node --config hardhat-fork/fantom.config.ts --port 8250 1>/dev/null&

sleep 5
echo "✅ successfully forked mainnets"

rm -rf deployments/ethereum-fork && ($HARDHAT deploy --network ethereum-fork || true)
rm -rf deployments/bsc-fork && ($HARDHAT deploy --network bsc-fork || true)
rm -rf deployments/avalanche-fork && ($HARDHAT deploy --network avalanche-fork || true)
rm -rf deployments/polygon-fork && ($HARDHAT deploy --network polygon-fork || true)
rm -rf deployments/arbitrum-fork && ($HARDHAT deploy --network arbitrum-fork || true)
rm -rf deployments/optimism-fork && ($HARDHAT deploy --network optimism-fork || true)
rm -rf deployments/fantom-fork && ($HARDHAT deploy --network fantom-fork || true)

$HARDHAT run scripts/setup.ts --network ethereum-fork &&\
$HARDHAT run scripts/setup.ts --network bsc-fork &&\
$HARDHAT run scripts/setup.ts --network avalanche-fork &&\
$HARDHAT run scripts/setup.ts --network polygon-fork &&\
$HARDHAT run scripts/setup.ts --network arbitrum-fork &&\
$HARDHAT run scripts/setup.ts --network optimism-fork &&\
$HARDHAT run scripts/setup.ts --network fantom-fork

clear() {
  kill -9 "$(ps ax | grep 'hardhat-fork node' | awk '{print $1}')"
}
trap clear EXIT
wait