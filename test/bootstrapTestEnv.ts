import { ethers } from "hardhat";
import { ERC20Mock, LZEndpointMock, OmniDisperse, StargateRouterMock } from "../typechain-types";

const abiCoder = ethers.utils.defaultAbiCoder;

export const CHAIN_ID = 31337; // hardhat
export const POOL_USDC = 1;
export const POOL_USDT = 2;
export const POOL_DAI = 3;

const boostrapNetwork = async (deployer, chainId, endpoint, usdc, usdt, dai) => {
    const Router = await ethers.getContractFactory("StargateRouterMock");
    const router = (await Router.connect(deployer).deploy(endpoint.address)) as StargateRouterMock;
    await router.connect(deployer).createPool(POOL_USDC, usdc.address);
    await router.connect(deployer).createPool(POOL_USDT, usdt.address);
    await router.connect(deployer).createPool(POOL_DAI, dai.address);
    for (const token of [usdc, usdt, dai]) {
        await token.mint(router.address, ethers.constants.WeiPerEther.mul(10000));
    }

    const Disperse = await ethers.getContractFactory("OmniDisperse");
    const disperse = (await Disperse.connect(deployer).deploy(router.address)) as OmniDisperse;
    await disperse.updateToken(POOL_USDC, usdc.address);
    await disperse.updateToken(POOL_USDT, usdt.address);
    await disperse.updateToken(POOL_DAI, dai.address);

    const estimateGas = async (nonce, token, recipients, amounts, from) =>
        await disperse.connect(ethers.provider).estimateGas.sgReceive(
            CHAIN_ID,
            ethers.utils.solidityPack(["address", "address"], [disperse.address, disperse.address]),
            nonce,
            token.address,
            amounts.reduce((a, b) => a.add(b), ethers.BigNumber.from(0)),
            abiCoder.encode(
                ["address", "bytes"],
                [from.address, abiCoder.encode(["address[]", "uint256[]"], [recipients, amounts])]
            ),
            { from: router.address }
        );

    return {
        endpoint,
        router,
        disperse,
        estimateGas,
    };
};

const boostrapTestEnv = async (signers, chainId) => {
    const deployer = signers[0];
    const aliceA = signers[1];
    const bobA = signers[2];
    const carolA = signers[3];
    const aliceB = signers[4];
    const bobB = signers[5];
    const carolB = signers[6];
    console.log("aliceA: ", aliceA.address);
    console.log("aliceB: ", aliceB.address);
    console.log("bobA: ", bobA.address);
    console.log("bobB: ", bobB.address);
    console.log("carolA: ", carolA.address);
    console.log("carolB: ", carolB.address);

    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    const usdc = (await ERC20.connect(deployer).deploy(
        "USD coin",
        "USDC",
        deployer.address,
        ethers.constants.WeiPerEther
    )) as ERC20Mock;
    const usdt = (await ERC20.connect(deployer).deploy(
        "USD Tether",
        "USDT",
        deployer.address,
        ethers.constants.WeiPerEther
    )) as ERC20Mock;
    const dai = (await ERC20.connect(deployer).deploy(
        "Dai Stablecoin",
        "DAI",
        deployer.address,
        ethers.constants.WeiPerEther
    )) as ERC20Mock;
    console.log("usdc: ", usdc.address);
    console.log("usdt: ", usdt.address);
    console.log("dai: ", dai.address);

    const Endpoint = await ethers.getContractFactory("LZEndpointMock");
    const endpoint = (await Endpoint.connect(deployer).deploy(chainId)) as LZEndpointMock;

    const networkA = await boostrapNetwork(deployer, chainId, endpoint, usdc, usdt, dai);
    const networkB = await boostrapNetwork(deployer, chainId, endpoint, usdc, usdt, dai);

    const routerA = networkA.router;
    const disperseA = networkA.disperse;
    const routerB = networkB.router;
    const disperseB = networkB.disperse;
    console.log("routerA: ", routerA.address);
    console.log("disperseA: ", disperseA.address);
    console.log("routerB: ", routerB.address);
    console.log("disperseB: ", disperseB.address);

    await endpoint.connect(deployer).setDestLzEndpoint(routerA.address, endpoint.address);
    await endpoint.connect(deployer).setDestLzEndpoint(routerB.address, endpoint.address);
    await endpoint.connect(deployer).setDestLzEndpoint(disperseA.address, endpoint.address);
    await endpoint.connect(deployer).setDestLzEndpoint(disperseB.address, endpoint.address);

    await routerA.setBridge(
        chainId,
        ethers.utils.solidityPack(["address", "address"], [routerB.address, routerA.address])
    );
    await routerB.setBridge(
        chainId,
        ethers.utils.solidityPack(["address", "address"], [routerA.address, routerB.address])
    );

    await disperseA.connect(deployer).updateDstAddress(chainId, disperseB.address);
    await disperseB.connect(deployer).updateDstAddress(chainId, disperseA.address);

    return {
        deployer,
        usdc,
        usdt,
        dai,
        aliceA,
        aliceB,
        bobA,
        bobB,
        carolA,
        carolB,
        endpoint,
        routerA,
        routerB,
        disperseA,
        disperseB,
        estimateGasA: networkA.estimateGas,
        estimateGasB: networkB.estimateGas,
    };
};

export default boostrapTestEnv;
