import { protocolDataProvider } from "../constants/aavev2.json"

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy, get } = deployments
    const { deployer } = await getNamedAccounts()

    let networkName = network.name
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5)
    }
    if (protocolDataProvider[networkName]) {
        const omniTx = await get("OmniTx")
        await deploy("AaveV2", {
            from: deployer,
            args: [omniTx.address, protocolDataProvider[networkName]],
            log: true,
        })
    } else {
        console.log('skipped "AaveV2"')
    }
}
