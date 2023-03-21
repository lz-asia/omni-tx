module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy("Disperse", {
        from: deployer,
        args: [],
        log: true,
    });
};
