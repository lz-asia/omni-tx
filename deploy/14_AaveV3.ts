import { addressesProvider } from "../constants/aavev3.json"

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy, get } = deployments
    const { deployer } = await getNamedAccounts()

    let networkName = network.name
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5)
    }
    if (addressesProvider[networkName]) {
        const omniTx = await get("OmniTx")
        await deploy("AaveV3", {
            from: deployer,
            args: [omniTx.address, addressesProvider[networkName]],
            deterministicDeployment: true,
            log: true,
        })
    } else {
        console.log('skipped "AaveV3"')
    }
}
