#!/bin/sh

yarn run hardhat run scripts/verify.ts --network ethereum &&\
yarn run hardhat run scripts/verify.ts --network bsc &&\
yarn run hardhat run scripts/verify.ts --network avalanche &&\
yarn run hardhat run scripts/verify.ts --network polygon &&\
yarn run hardhat run scripts/verify.ts --network arbitrum &&\
yarn run hardhat run scripts/verify.ts --network optimism &&\
yarn run hardhat run scripts/verify.ts --network fantom
