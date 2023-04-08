import { router, weth } from "../constants/uniswapv3.json";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy, get } = deployments;
    const { deployer } = await getNamedAccounts();

    let networkName = network.name;
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5);
    }
    if (router[networkName] && weth[networkName]) {
        const omniTx = await get("OmniTx");
        await deploy("UniswapV3", {
            from: deployer,
            args: [omniTx.address, router[networkName], weth[networkName]],
            log: true,
        });
    } else {
        console.log('skipped "UniswapV3"');
    }
};
