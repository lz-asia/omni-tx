module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, get } = deployments;
    const { deployer } = await getNamedAccounts();

    const proxy = await get("StargateProxy");

    await deploy("Disperse", {
        from: deployer,
        args: [proxy.address],
        log: true,
    });
};
