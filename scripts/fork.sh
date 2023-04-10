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

echo "⌛️️ ethereum"
rm -rf deployments/ethereum-fork && ($HARDHAT deploy --network ethereum-fork || true)
echo "⌛️️ bsc"
rm -rf deployments/bsc-fork && ($HARDHAT deploy --network bsc-fork || true)
echo "⌛️️ avalanche"
rm -rf deployments/avalanche-fork && ($HARDHAT deploy --network avalanche-fork || true)
echo "⌛️️ polygon"
rm -rf deployments/polygon-fork && ($HARDHAT deploy --network polygon-fork || true)
echo "⌛️️ arbitrum"
rm -rf deployments/arbitrum-fork && ($HARDHAT deploy --network arbitrum-fork || true)
echo "⌛️️ optimism"
rm -rf deployments/optimism-fork && ($HARDHAT deploy --network optimism-fork || true)
echo "⌛️️ fantom"
rm -rf deployments/fantom-fork && ($HARDHAT deploy --network fantom-fork || true)

echo "⌛️️ ethereum"
$HARDHAT run scripts/setup.ts --network ethereum-fork &&\
echo "⌛️️ bsc"
$HARDHAT run scripts/setup.ts --network bsc-fork &&\
echo "⌛️️ avalanche"
$HARDHAT run scripts/setup.ts --network avalanche-fork &&\
echo "⌛️️ polygon"
$HARDHAT run scripts/setup.ts --network polygon-fork &&\
echo "⌛️️ arbitrum"
$HARDHAT run scripts/setup.ts --network arbitrum-fork &&\
echo "⌛️️ optimism"
$HARDHAT run scripts/setup.ts --network optimism-fork &&\
echo "⌛️️ fantom"
$HARDHAT run scripts/setup.ts --network fantom-fork

clear() {
  ps ax | grep "$HARDHAT" | grep -v "grep" | awk '{print $1}' | xargs kill -9
}
trap clear EXIT
wait