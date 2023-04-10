import { sgeth } from "../constants/stargate.json";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy, get, execute } = deployments;
    const { deployer } = await getNamedAccounts();

    let networkName = network.name;
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5);
    }
    const omniTx = await get("OmniTx");
    const { newlyDeployed } = await deploy("WrappedNative", {
        from: deployer,
        args: [omniTx.address],
        log: true,
    });
    if (newlyDeployed && sgeth[networkName]) {
        await execute(
            "WrappedNative",
            {
                from: deployer,
                log: true,
            },
            "updateWhitelisted",
            sgeth[networkName],
            true
        );
    }
};
