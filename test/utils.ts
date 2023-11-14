import { Chain, SignerWithAddress } from "@lz-kit/cli"
import {
    AaveV2,
    AaveV3,
    Disperse,
    IERC20,
    IOmniTx,
    IStargateRouter,
    IStargateRouterETH,
    IWETH,
    UniswapV2,
    UniswapV3,
    ZeroEx,
} from "../typechain-types"
import { BaseContract, BigNumber, Contract, utils } from "ethers"
import stargate from "@lz-asia/lz-constants/constants/stargate.json"
import tokens from "@lz-asia/lz-constants/constants/tokens.json"
import { getImpersonatedSigner } from "@nomiclabs/hardhat-ethers/internal/helpers"

export interface Context extends Mocha.Context {
    eth: Env
    opt: Env
}

export interface Env extends Chain {
    lzChainId: number
    deployer: SignerWithAddress
    alice: SignerWithAddress
    bob: SignerWithAddress
    carol: SignerWithAddress
    sgeth: IWETH
    usdc: IERC20
    dai?: IERC20
    router: IStargateRouter
    routerETH: IStargateRouterETH
    omniTx: IOmniTx
    adapters: {
        aaveV2?: AaveV2
        aaveV3?: AaveV3
        disperse: Disperse
        uniswapV2?: UniswapV2
        uniswapV3?: UniswapV3
        zeroEx: ZeroEx
    }
}

export const setup = async (chain: Chain) => {
    const { name, provider, getSigners, isDeployed, getContract, getContractAt, setBalance, getImpersonatedSigner } =
        chain
    const networkName = name.endsWith("-fork") ? name.slice(0, -5) : name
    const [deployer, alice, bob, carol] = await getSigners()
    for (const signer of [deployer, alice, bob, carol]) {
        await setBalance(signer.address, utils.parseEther("10000"))
    }
    const sgeth = await getContractAt<IWETH>("IWETH", tokens[networkName].sgeth, deployer)
    const usdc = await getContractAt<IERC20>("IERC20", tokens[networkName].usdc, deployer)
    const dai = tokens[networkName].dai
        ? await getContractAt<IERC20>("IERC20", tokens[networkName].dai, deployer)
        : undefined
    if (networkName != "ethereum") {
        const bridgedUSDC = new Contract(
            usdc.address,
            ["function bridgeMint(address,uint256)"],
            await getImpersonatedSigner("0x096760F208390250649E3e8763348E783AEF5562", utils.parseEther("10000"))
        )
        for (const signer of [deployer, alice, bob, carol]) {
            await bridgedUSDC.bridgeMint(signer.address, utils.parseEther("10000"))
        }
    }
    const router = await getContractAt<IStargateRouter>("IStargateRouter", stargate.router[networkName])
    const routerETH = await getContractAt<IStargateRouterETH>("IStargateRouterETH", stargate.routerETH[networkName])
    const omniTx = await getContract<IOmniTx>("OmniTx")
    const getContractIfDeployed = async <T extends BaseContract>(contract: string) => {
        if (await isDeployed(contract)) {
            return await getContract<T>(contract)
        }
    }
    const adapters = {
        aaveV2: await getContractIfDeployed<AaveV2>("AaveV2"),
        aaveV3: await getContractIfDeployed<AaveV3>("AaveV3"),
        disperse: await getContractIfDeployed<Disperse>("Disperse"),
        uniswapV2: await getContractIfDeployed<UniswapV2>("UniswapV2"),
        uniswapV3: await getContractIfDeployed<UniswapV3>("UniswapV3"),
        zeroEx: await getContractIfDeployed<ZeroEx>("ZeroEx"),
    }
    return {
        ...chain,
        provider,
        deployer,
        alice,
        bob,
        carol,
        sgeth,
        usdc,
        dai,
        router,
        routerETH,
        omniTx,
        adapters,
    } as Env
}

export function deduct(bn: BigNumber, bps: number) {
    return bn.sub(bn.mul(bps).div(10000))
}
