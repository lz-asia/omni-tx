import { router } from "../constants/stargate.json";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    let networkName = network.name;
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5);
    }
    await deploy("OmniTx", {
        from: deployer,
        args: [router[networkName]],
        log: true,
    });
};
