#!/bin/sh

yarn run hardhat deploy --network ethereum &&\
yarn run hardhat deploy --network bsc &&\
yarn run hardhat deploy --network avalanche &&\
yarn run hardhat deploy --network polygon &&\
yarn run hardhat deploy --network arbitrum &&\
yarn run hardhat deploy --network optimism &&\
yarn run hardhat deploy --network fantom