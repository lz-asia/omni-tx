import { router } from "../constants/uniswapv2.json";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy, get } = deployments;
    const { deployer } = await getNamedAccounts();

    let networkName = network.name;
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5);
    }
    if (router[networkName]) {
        const omniTx = await get("OmniTx");
        await deploy("UniswapV2", {
            from: deployer,
            args: [omniTx.address, router[networkName]],
            log: true,
        });
    } else {
        console.log('skipped "UniswapV2"');
    }
};
