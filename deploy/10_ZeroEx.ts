import { proxy } from "../constants/zeroex.json"

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy, get } = deployments
    const { deployer } = await getNamedAccounts()

    let networkName = network.name
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5)
    }
    if (proxy[networkName]) {
        const omniTx = await get("OmniTx")
        await deploy("ZeroEx", {
            from: deployer,
            args: [omniTx.address, proxy[networkName]],
            deterministicDeployment: true,
            log: true,
        })
    } else {
        console.log('skipped "ZeroEx"')
    }
}
