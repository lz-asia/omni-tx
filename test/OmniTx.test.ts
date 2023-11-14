import "@lz-kit/cli"
import { getChain, waitForMessageRelayed } from "hardhat"
import { constants, utils } from "ethers"
import { Context, deduct, setup } from "./utils"
import { poolId } from "@lz-asia/lz-constants/constants/stargate.json"
import { expect } from "chai"

describe("OmniTx", async function () {
    beforeEach(async function (this: Context) {
        this.opt = await setup(await getChain("optimism-fork"))
        this.eth = await setup(await getChain("ethereum-fork"))
    })

    afterEach(async function (this: Context) {
        await this.eth.snapshot.restore()
        await this.opt.snapshot.restore()
    })

    it("should transferNative()", async function (this: Context) {
        const amount = utils.parseEther("1")
        const adapters = []
        const data = []
        const params = {
            poolId: poolId.optimism.sgeth,
            dstChainId: this.eth.lzChainId,
            dstPoolId: poolId.ethereum.sgeth,
            dstMinAmount: deduct(amount, 100),
            dstAdapters: [],
            dstData: [],
            dstGasForCall: 500_000,
            dstNativeAmount: 0,
        }
        const fee = await this.opt.omniTx.estimateFee(
            params.dstChainId,
            params.dstAdapters,
            params.dstData,
            params.dstGasForCall,
            params.dstNativeAmount,
            this.opt.deployer.address
        )
        await this.opt.omniTx
            .connect(this.opt.alice)
            .transferNative(amount, adapters, data, params, { value: amount.add(fee.mul(120).div(100)) })
        const event = await waitForMessageRelayed(
            {
                contract: this.eth.omniTx,
                event: "SGReceive",
            },
            {
                contract: this.eth.router,
                event: "CachedSwapSaved",
            }
        )
        expect(event.event).to.eq("SGReceive")
        expect(event.args.srcFrom, this.opt.alice.address)
        expect(event.args.tokenOut, constants.AddressZero)
    })

    it("should transfer()", async function (this: Context) {
        const amount = utils.parseUnits("1", 6)
        const adapters = []
        const data = []
        const params = {
            poolId: poolId.optimism.usdc,
            dstChainId: this.eth.lzChainId,
            dstPoolId: poolId.ethereum.usdc,
            dstMinAmount: deduct(amount, 100),
            dstAdapters: [],
            dstData: [],
            dstGasForCall: 200_000,
            dstNativeAmount: 0,
        }
        const fee = await this.opt.omniTx.estimateFee(
            params.dstChainId,
            params.dstAdapters,
            params.dstData,
            params.dstGasForCall,
            params.dstNativeAmount,
            this.opt.deployer.address
        )
        await this.opt.usdc.connect(this.opt.alice).approve(this.opt.omniTx.address, amount)
        await this.opt.omniTx.connect(this.opt.alice).transfer(this.opt.usdc.address, amount, adapters, data, params, {
            value: amount.add(fee.mul(120).div(100)),
        })
        const event = await waitForMessageRelayed(
            {
                contract: this.eth.omniTx,
                event: "SGReceive",
            },
            {
                contract: this.eth.router,
                event: "CachedSwapSaved",
            }
        )
        expect(event.event).to.eq("SGReceive")
        expect(event.args.srcFrom, this.opt.alice.address)
        expect(event.args.tokenOut, this.eth.usdc.address)
    })
})
