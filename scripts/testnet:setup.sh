#!/bin/sh

yarn run hardhat run scripts/setup.ts --network goerli &&\
yarn run hardhat run scripts/setup.ts --network bsc-testnet &&\
yarn run hardhat run scripts/setup.ts --network fuji &&\
yarn run hardhat run scripts/setup.ts --network mumbai &&\
yarn run hardhat run scripts/setup.ts --network arbitrum-goerli &&\
yarn run hardhat run scripts/setup.ts --network optimism-goerli &&\
yarn run hardhat run scripts/setup.ts --network fantom-testnet
