import hre from "hardhat";
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import { getAddress } from "ethers/lib/utils";
import { BigNumber, utils } from "ethers";
import { PoolItem } from "../types";
import { getOverrideOptions } from "../../utils";

chai.use(solidity);

export function shouldBehaveLikeSushiswapAdapter(token: string, pool: PoolItem): void {
  it(`should deposit ${token} and withdraw f${token} in ${token} lending pair of Kashi - Sushiswap`, async function () {
    // Sushiswap's deposit vault instance
    const kashiLendingPairInstance = await hre.ethers.getContractAt("IKashiLendingPair", pool.vault);

    //check whether the lending pair is empty
    const totalSupply = await kashiLendingPairInstance.totalSupply();
    if (totalSupply == 0) this.skip(); //skip vaults which are empty - it's not possible to get money out again fully (perhaps even skip small vaults?)
    console.log("totalSupply");
    console.log(utils.formatEther(totalSupply));

    let bentoboxAddress = "0x0319000133d3AdA02600f0875d2cf03D442C3367";
    const bentoBoxInstance = await hre.ethers.getContractAt("IBentoBoxV1", bentoboxAddress);

    // Sushiswap's underlying token instance
    const wantTokenAddress = pool.wantToken;
    const underlyingTokenInstance = await hre.ethers.getContractAt("IERC20", wantTokenAddress);

    // fund TestDeFiAdapter with initialWantTokenBalance
    // if wantToken is WMATIC, wrap MATIC into WMATIC
    let wmatic_address = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
    if (hre.ethers.utils.getAddress(wantTokenAddress) == hre.ethers.utils.getAddress(wmatic_address)) {
      console.log("want is wmatic");
      const wmatic_token = await hre.ethers.getContractAt("IWETH", wantTokenAddress);
      await wmatic_token.deposit({ value: hre.ethers.utils.parseEther("50") });
      console.log("swap into wmatic done");
    } else {
      //if wantToken is not WMATIC, swap from MATIC into wantToken
      console.log("want is not wmatic");
      try {
        await this.swapRouter.swapExactETHForTokens(
          0,
          [wmatic_address, wantTokenAddress],
          this.signers.admin.address,
          Date.now() + 900,
          { value: hre.ethers.utils.parseEther("50") },
        );
        console.log("Swap into single test asset done");
      } catch (err) {
        console.log("Swap into single test asset failed");
        console.log(err);
      }
    }

    //get balance of wantToken
    const initialWantTokenBalance = await underlyingTokenInstance.balanceOf(this.signers.admin.address);
    console.log("initialWantTokenBalance");
    console.log(hre.ethers.utils.formatEther(initialWantTokenBalance));

    //transfer want to testDeFiAdapter
    await underlyingTokenInstance.transfer(this.testDeFiAdapter.address, initialWantTokenBalance, getOverrideOptions());
    const testDefiAdapterWantBalance = await underlyingTokenInstance.balanceOf(this.testDeFiAdapter.address);
    console.log("testDefiAdapterWantBalance");
    console.log(hre.ethers.utils.formatEther(testDefiAdapterWantBalance));

    const tokenBalanceInTestAdapter = await underlyingTokenInstance.balanceOf(this.testDeFiAdapter.address);
    console.log("tokenBalanceInTestAdapter");
    console.log(hre.ethers.utils.formatEther(tokenBalanceInTestAdapter));

    // 1. deposit all underlying tokens
    await this.testDeFiAdapter.testGetDepositAllCodes(
      pool.wantToken,
      pool.vault,
      this.sushiswapAdapter.address,
      getOverrideOptions(),
    );
    // 1.1 assert whether receipt ?? token balance is as expected or not after deposit (test the getLiquidityPoolTokenBalance function)
    const actualLPTokenBalanceAfterDeposit = await this.sushiswapAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.vault,
    );
    const expectedLPTokenBalanceAfterDeposit = await kashiLendingPairInstance.balanceOf(this.testDeFiAdapter.address);
    console.log("expectedLPTokenBalanceAfterDeposit");
    console.log(hre.ethers.utils.formatEther(expectedLPTokenBalanceAfterDeposit));
    // const tokenBalanceInTestAdapter = await underlyingTokenInstance.balanceOf(this.testDeFiAdapter.address);

    expect(actualLPTokenBalanceAfterDeposit).to.be.eq(expectedLPTokenBalanceAfterDeposit);
    // 1.2 assert whether underlying token balance is as expected or not after deposit (test the getUnderlyingTokens function)
    const actualUnderlyingTokenBalanceAfterDeposit = await this.testDeFiAdapter.getERC20TokenBalance(
      (
        await this.sushiswapAdapter.getUnderlyingTokens(pool.vault, pool.vault)
      )[0], //gets the address of the underlying token
      this.testDeFiAdapter.address,
    );
    // console.log("actualUnderlyingTokenBalanceAfterDeposit");
    // console.log(hre.ethers.utils.formatEther(actualUnderlyingTokenBalanceAfterDeposit));

    const expectedUnderlyingTokenBalanceAfterDeposit = await underlyingTokenInstance.balanceOf(
      this.testDeFiAdapter.address,
    );
    console.log("expectedUnderlyingTokenBalanceAfterDeposit");
    console.log(hre.ethers.utils.formatEther(expectedUnderlyingTokenBalanceAfterDeposit));

    expect(actualUnderlyingTokenBalanceAfterDeposit).to.be.eq(expectedUnderlyingTokenBalanceAfterDeposit);

    // 1.3 assert whether the amount in token is as expected or not after depositing
    const actualAmountInTokenAfterDeposit = await this.sushiswapAdapter.getAllAmountInToken(
      this.testDeFiAdapter.address,
      pool.wantToken,
      pool.vault,
    );
    console.log("actualAmountInTokenAfterDeposit");
    console.log(hre.ethers.utils.formatEther(actualAmountInTokenAfterDeposit));

    //to do - fix this line below - need to do
    let totalAsset = await kashiLendingPairInstance.totalAsset();
    let totalAssetElastic = totalAsset[0];
    let totalAssetBase = totalAsset[1];

    const pricePerFraction = await bentoBoxInstance.toAmount(
      pool.wantToken,
      totalAssetElastic.div(totalAssetBase),
      false,
    );

    const expectedAmountInTokenAfterDeposit = await bentoBoxInstance.toAmount(
      pool.wantToken,
      expectedLPTokenBalanceAfterDeposit.mul(totalAssetElastic).div(totalAssetBase),
      false,
    );

    console.log("expectedAmountInTokenAfterDeposit");
    console.log(hre.ethers.utils.formatEther(expectedAmountInTokenAfterDeposit));

    expect(actualAmountInTokenAfterDeposit).to.be.eq(expectedAmountInTokenAfterDeposit);

    // 2. Withdraw all token balance
    console.log("withdraw amount");
    const actualLPTokenBalanceBeforeWithdraw = await this.sushiswapAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.vault,
    );
    console.log(hre.ethers.utils.formatEther(actualLPTokenBalanceBeforeWithdraw));

    await this.testDeFiAdapter.testGetWithdrawAllCodes(
      pool.wantToken,
      pool.vault,
      this.sushiswapAdapter.address,
      getOverrideOptions(),
    );

    // 2.1 assert whether token balance is as expected or not
    const actualLPTokenBalanceAfterWithdraw = await this.sushiswapAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.vault,
    );
    const expectedLPTokenBalanceAfterWithdraw = await kashiLendingPairInstance.balanceOf(this.testDeFiAdapter.address);
    console.log("expectedLPTokenBalanceAfterWithdraw");
    console.log(hre.ethers.utils.formatEther(expectedLPTokenBalanceAfterWithdraw));

    expect(actualLPTokenBalanceAfterWithdraw).to.be.eq(expectedLPTokenBalanceAfterWithdraw);

    // 2.2 assert whether underlying token balance is as expected or not after withdraw
    const actualUnderlyingTokenBalanceAfterWithdraw = await this.testDeFiAdapter.getERC20TokenBalance(
      (
        await this.sushiswapAdapter.getUnderlyingTokens(pool.vault, pool.vault)
      )[0],
      this.testDeFiAdapter.address,
    );
    const expectedUnderlyingTokenBalanceAfterWithdraw = await underlyingTokenInstance.balanceOf(
      this.testDeFiAdapter.address,
    );
    console.log("expectedUnderlyingTokenBalanceAfterWithdraw");
    console.log(hre.ethers.utils.formatEther(expectedUnderlyingTokenBalanceAfterWithdraw));

    expect(actualUnderlyingTokenBalanceAfterWithdraw).to.be.eq(expectedUnderlyingTokenBalanceAfterWithdraw);
  }).timeout(100000);
}
