import fs from "fs";
import { ethers, network } from "hardhat";
import chainIds from "../constants/chainIds.json";
import { mainnet, testnet } from "../constants/networks.json";
import { OmniTx } from "../typechain-types";
import { utils } from "ethers";

function getOmniTxAddress(network) {
    const { address } = JSON.parse(fs.readFileSync("deployments/" + network + "/OmniTx.json", { encoding: "utf-8" }));
    return address;
}

async function setup(networks) {
    const omniTx = (await ethers.getContractAt("OmniTx", getOmniTxAddress(network.name))) as OmniTx;
    for (const networkName of networks) {
        if (networkName == network.name) continue;
        if (fs.existsSync("deployments/" + networkName)) {
            const addr = utils.getAddress(await omniTx.dstAddress(chainIds[networkName]));
            const dst = utils.getAddress(getOmniTxAddress(networkName));
            if (addr == dst) {
                console.log("reusing dst address for " + networkName);
            } else {
                console.log("updating dst address for " + networkName);
                await omniTx.updateDstAddress(chainIds[networkName], dst);
            }
        }
    }
}

async function main() {
    let networkName = network.name;
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5);
    }
    if (mainnet.includes(networkName)) {
        console.log("Setting up OmniTx for mainnets");
        await setup(mainnet);
    } else if (testnet.includes(networkName)) {
        console.log("Setting up OmniTx for testnets");
        await setup(testnet);
    }
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
