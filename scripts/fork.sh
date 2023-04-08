#!/bin/sh

echo "forking mainnets..."
yarn run hardhat node --config hardhat-fork/ethereum.config.ts --port 8001 1>/dev/null&
yarn run hardhat node --config hardhat-fork/bsc.config.ts --port 8056 1>/dev/null&
yarn run hardhat node --config hardhat-fork/polygon.config.ts --port 8137 1>/dev/null&
yarn run hardhat node --config hardhat-fork/avalanche.config.ts --port 51114 1>/dev/null&
yarn run hardhat node --config hardhat-fork/optimism.config.ts --port 8010 1>/dev/null&
yarn run hardhat node --config hardhat-fork/arbitrum.config.ts --port 50161 1>/dev/null&
yarn run hardhat node --config hardhat-fork/fantom.config.ts --port 8250 1>/dev/null&

sleep 5
echo "✅ successfully forked mainnets"

rm -rf deployments/ethereum-fork && (yarn run hardhat deploy --network ethereum-fork || true)
rm -rf deployments/bsc-fork && (yarn run hardhat deploy --network bsc-fork || true)
rm -rf deployments/avalanche-fork && (yarn run hardhat deploy --network avalanche-fork || true)
rm -rf deployments/polygon-fork && (yarn run hardhat deploy --network polygon-fork || true)
rm -rf deployments/arbitrum-fork && (yarn run hardhat deploy --network arbitrum-fork || true)
rm -rf deployments/optimism-fork && (yarn run hardhat deploy --network optimism-fork || true)
rm -rf deployments/fantom-fork && (yarn run hardhat deploy --network fantom-fork || true)

yarn run hardhat run scripts/setup.ts --network ethereum-fork &&\
yarn run hardhat run scripts/setup.ts --network bsc-fork &&\
yarn run hardhat run scripts/setup.ts --network avalanche-fork &&\
yarn run hardhat run scripts/setup.ts --network polygon-fork &&\
yarn run hardhat run scripts/setup.ts --network arbitrum-fork &&\
yarn run hardhat run scripts/setup.ts --network optimism-fork &&\
yarn run hardhat run scripts/setup.ts --network fantom-fork

clear() {
  kill -9 "$(ps ax | grep 'hardhat-fork node' | awk '{print $1}')"
}
trap clear EXIT
wait