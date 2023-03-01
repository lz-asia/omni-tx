import fs from "fs";
import { ethers, network } from "hardhat";
import chainIds from "../constants/chainIds.json";
import { mainnet, testnet } from "../constants/networks.json";
import { OmniDisperse } from "../typechain-types";

function getOmniDisperseAddress(network) {
    const { address } = JSON.parse(
        fs.readFileSync("deployments/" + network + "/OmniDisperse.json", { encoding: "utf-8" })
    );
    return address;
}

async function setup(networks) {
    const disperse = (await ethers.getContractAt("OmniDisperse", getOmniDisperseAddress(network.name))) as OmniDisperse;
    for (const networkName of networks) {
        if (networkName == network.name) continue;
        if (fs.existsSync("deployments/" + networkName)) {
            console.log("updating dst address for " + networkName);
            await disperse.updateDstAddress(chainIds[networkName], getOmniDisperseAddress(networkName));
        }
    }
}

async function main() {
    if (mainnet.includes(network.name)) {
        console.log("Setting up OmniDisperse for mainnets");
        await setup(mainnet);
    } else if (testnet.includes(network.name)) {
        console.log("Setting up OmniDisperse for testnets");
        await setup(testnet);
    }
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
