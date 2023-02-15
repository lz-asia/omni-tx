import boostrapTestEnv, { CHAIN_ID, POOL_USDC } from "./bootstrapTestEnv";
import { ethers } from "hardhat";
import { expect } from "chai";

const ONE = ethers.constants.WeiPerEther;

describe("OmniDisperse", async function () {
    it("should transfer() to one address", async function () {
        const { aliceA, bobB, disperseA, estimateGasA, usdc } = await boostrapTestEnv(
            await ethers.getSigners(),
            CHAIN_ID
        );

        await usdc.mint(aliceA.address, ONE.mul(100));
        expect(await usdc.balanceOf(aliceA.address)).to.equal(ONE.mul(100));
        expect(await usdc.balanceOf(bobB.address)).to.equal(0);

        const recipients = [bobB.address];
        const amounts = [ONE];

        const gas = await estimateGasA(0, usdc, recipients, amounts, aliceA);
        const fee = await disperseA.estimateFee(CHAIN_ID, recipients, amounts, gas, aliceA.address);

        await usdc.connect(aliceA).approve(disperseA.address, ONE);
        await disperseA
            .connect(aliceA)
            .transfer(CHAIN_ID, POOL_USDC, ONE, recipients, amounts, gas, { value: fee.mul(2) });
        expect(await usdc.balanceOf(aliceA.address)).to.equal(ONE.mul(99));
        expect(await usdc.balanceOf(bobB.address)).to.equal(ONE);
    });

    it("should transfer() to multiple addresses", async function () {
        const { aliceA, aliceB, bobB, carolB, disperseA, estimateGasA, usdc } = await boostrapTestEnv(
            await ethers.getSigners(),
            CHAIN_ID
        );

        await usdc.mint(aliceA.address, ONE.mul(100));
        expect(await usdc.balanceOf(aliceA.address)).to.equal(ONE.mul(100));
        expect(await usdc.balanceOf(aliceB.address)).to.equal(0);
        expect(await usdc.balanceOf(bobB.address)).to.equal(0);
        expect(await usdc.balanceOf(carolB.address)).to.equal(0);

        const recipients = [aliceB.address, bobB.address, carolB.address];
        const amounts = [ONE, ONE.mul(2), ONE.mul(3)];

        const gas = (await estimateGasA(0, usdc, recipients, amounts, aliceA)).mul(3);
        const fee = await disperseA.estimateFee(CHAIN_ID, recipients, amounts, gas, aliceA.address);

        await usdc.connect(aliceA).approve(disperseA.address, ONE.mul(6));
        await disperseA
            .connect(aliceA)
            .transfer(CHAIN_ID, POOL_USDC, ONE.mul(6), recipients, amounts, gas, { value: fee.mul(2) });
        expect(await usdc.balanceOf(aliceA.address)).to.equal(ONE.mul(94));
        expect(await usdc.balanceOf(aliceB.address)).to.equal(ONE);
        expect(await usdc.balanceOf(bobB.address)).to.equal(ONE.mul(2));
        expect(await usdc.balanceOf(carolB.address)).to.equal(ONE.mul(3));
    });
});
