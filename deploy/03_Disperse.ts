module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, get } = deployments;
    const { deployer } = await getNamedAccounts();

    const omniTx = await get("OmniTx");
    await deploy("Disperse", {
        from: deployer,
        args: [omniTx.address],
        log: true,
    });
};
