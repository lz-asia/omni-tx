import "@lz-kit/cli"
import { utils } from "ethers"
import { getChain } from "hardhat"
import { IOmniTx } from "../typechain-types"

async function main() {
    const chain = await getChain(process.env.LZ_KIT_SRC)
    const dest = await getChain(process.env.LZ_KIT_DEST)
    const { address } = await dest.getContract<IOmniTx>("OmniTx")

    const contract = await chain.getContract<IOmniTx>("OmniTx", (await chain.getSigners())[0])
    const prevAddr = utils.getAddress(await contract.dstAddress(dest.lzChainId))
    const newAddr = utils.getAddress(address)
    if (prevAddr == newAddr) {
        console.log("👀 Reusing dstAddress for " + dest.name)
    } else {
        console.log("✅ Updating dstAddress for " + dest.name)
        await contract.updateDstAddress(dest.provider.network.chainId, newAddr)
    }
}

main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
