import { run, network, deployments } from "hardhat";
import { router } from "../constants/stargate.json";

async function main() {
    const { get } = deployments;

    const stargateProxy = await get("StargateProxy");
    await run("verify:verify", {
        address: stargateProxy.address,
        constructorArguments: [router[network.name]],
    });

    const disperse = await get("Disperse");
    await run("verify:verify", {
        address: disperse.address,
        constructorArguments: [stargateProxy.address],
    });
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
