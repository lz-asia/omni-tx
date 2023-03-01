#!/bin/sh

yarn run hardhat deploy --network mainnet #&&\
#yarn run hardhat deploy --network bsc &&\
#yarn run hardhat deploy --network avalanche &&\
yarn run hardhat deploy --network polygon &&\
yarn run hardhat deploy --network arbitrum &&\
yarn run hardhat deploy --network optimism #&&\
#yarn run hardhat deploy --network fantom #&&\
yarn run hardhat deploy --network goerli &&\
yarn run hardhat deploy --network bsc-testnet &&\
yarn run hardhat deploy --network fuji &&\
yarn run hardhat deploy --network mumbai &&\
yarn run hardhat deploy --network arbitrum-goerli &&\
yarn run hardhat deploy --network optimism-goerli &&\
yarn run hardhat deploy --network fantom-testnet