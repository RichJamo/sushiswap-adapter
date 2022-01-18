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
    let bentoboxAddress = "0x0319000133d3AdA02600f0875d2cf03D442C3367";
    const bentoBoxInstance = await hre.ethers.getContractAt("IBentoBoxV1", bentoboxAddress);

    // Sushiswap receipt token decimals
    // const decimals = await kashiLendingPairInstance.decimals();

    // Sushiswap's underlying token instance
    const underlyingTokenInstance = await hre.ethers.getContractAt("IERC20", pool.wantToken);
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

    // // 1.3 assert whether the amount in token is as expected or not after depositing
    // const actualAmountInTokenAfterDeposit = await this.sushiswapAdapter.getAllAmountInToken(
    //   this.testDeFiAdapter.address,
    //   pool.wantToken,
    //   pool.vault,
    // );
    // console.log("actualAmountInTokenAfterDeposit");
    // console.log(hre.ethers.utils.formatEther(actualAmountInTokenAfterDeposit));

    // //to do - fix this line below - need to do
    // let totalAsset = await kashiLendingPairInstance.totalAsset();
    // let totalBorrow = await kashiLendingPairInstance.totalBorrow();
    // let totalAssetElastic = totalAsset[0];
    // let totalBorrowElastic = totalBorrow[0];
    //   console.log(hre.ethers.utils.formatUnits(totalAssetElastic));
    //   console.log(hre.ethers.utils.formatUnits(totalBorrowElastic));
    //   console.log(hre.ethers.utils.formatUnits(expectedLPTokenBalanceAfterDeposit));
    //   console.log(hre.ethers.utils.formatUnits(await kashiLendingPairInstance.totalSupply()))
    //   console.log(hre.ethers.utils.formatUnits(await bentoBoxInstance.toAmount(pool.wantToken, totalAssetElastic, false)))

    // const pricePerFraction = (
    //   (await bentoBoxInstance.toAmount(pool.wantToken, totalAssetElastic, false))
    //   .add(totalBorrowElastic)
    //   )
    // .mul(10**12)
    // .div(await kashiLendingPairInstance.totalSupply())
    // .div(10**12);

    // //await kashiLendingPairInstance.getPricePerFullShare();
    // console.log("pricePerFraction");
    // console.log(pricePerFraction);

    // const expectedAmountInTokenAfterDeposit = BigNumber.from(expectedLPTokenBalanceAfterDeposit)
    //   .mul(pricePerFraction)
    // console.log("expectedAmountInTokenAfterDeposit");
    // console.log(hre.ethers.utils.formatEther(expectedAmountInTokenAfterDeposit));

    // expect(actualAmountInTokenAfterDeposit).to.be.eq(expectedAmountInTokenAfterDeposit);

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
