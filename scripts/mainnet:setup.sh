#!/bin/sh

yarn run hardhat run scripts/setup.ts --network mainnet &&\
yarn run hardhat run scripts/setup.ts --network bsc &&\
yarn run hardhat run scripts/setup.ts --network avalanche &&\
yarn run hardhat run scripts/setup.ts --network polygon &&\
yarn run hardhat run scripts/setup.ts --network arbitrum &&\
yarn run hardhat run scripts/setup.ts --network optimism &&\
yarn run hardhat run scripts/setup.ts --network fantom
