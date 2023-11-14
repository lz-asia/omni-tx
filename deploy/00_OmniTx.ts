import { composer, sgeth } from "@lz-asia/lz-constants/constants/stargate.json"
import { constants } from "ethers"

module.exports = async ({ getNamedAccounts, deployments, network }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    let networkName = network.name
    if (networkName.endsWith("-fork")) {
        networkName = networkName.substring(0, networkName.length - 5)
    }
    await deploy("OmniTx", {
        from: deployer,
        args: [composer[networkName], sgeth[networkName] || constants.AddressZero, deployer],
        deterministicDeployment: true,
        log: true,
    })
}
