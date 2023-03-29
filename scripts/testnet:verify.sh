#!/bin/sh

yarn run hardhat run scripts/verify.ts --network goerli &&\
yarn run hardhat run scripts/verify.ts --network bsc-testnet &&\
yarn run hardhat run scripts/verify.ts --network fuji &&\
yarn run hardhat run scripts/verify.ts --network mumbai &&\
yarn run hardhat run scripts/verify.ts --network arbitrum-goerli &&\
yarn run hardhat run scripts/verify.ts --network optimism-goerli &&\
yarn run hardhat run scripts/verify.ts --network fantom-testnet
