import { run, network, deployments } from "hardhat";
import { router } from "../constants/stargate.json";

async function main() {
    const { get } = deployments;

    const stargateProxy = await get("StargateProxy");
    try {
        await run("verify:verify", {
            address: stargateProxy.address,
            constructorArguments: [router[network.name]],
        });
    } catch (e) {
        console.error(e.message);
    }

    const disperse = await get("Disperse");
    try {
        await run("verify:verify", {
            address: disperse.address,
            constructorArguments: [stargateProxy.address],
        });
    } catch (e) {
        console.error(e.message);
    }
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
