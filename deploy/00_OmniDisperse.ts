import { router } from "../constants/stargate.json";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy("OmniDisperse", {
        from: deployer,
        args: [router[network.name]],
        log: true,
    });
};
