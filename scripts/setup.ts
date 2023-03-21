import fs from "fs";
import { ethers, network } from "hardhat";
import chainIds from "../constants/chainIds.json";
import { mainnet, testnet } from "../constants/networks.json";
import { StargateProxy } from "../typechain-types";

function getStargateProxyAddress(network) {
    const { address } = JSON.parse(
        fs.readFileSync("deployments/" + network + "/StargateProxy.json", { encoding: "utf-8" })
    );
    return address;
}

async function setup(networks) {
    const proxy = (await ethers.getContractAt("StargateProxy", getStargateProxyAddress(network.name))) as StargateProxy;
    for (const networkName of networks) {
        if (networkName == network.name) continue;
        if (fs.existsSync("deployments/" + networkName)) {
            console.log("updating dst address for " + networkName);
            await proxy.updateDstAddress(chainIds[networkName], getStargateProxyAddress(networkName));
        }
    }
}

async function main() {
    if (mainnet.includes(network.name)) {
        console.log("Setting up StargateProxy for mainnets");
        await setup(mainnet);
    } else if (testnet.includes(network.name)) {
        console.log("Setting up StargateProxy for testnets");
        await setup(testnet);
    }
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
