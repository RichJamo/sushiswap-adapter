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
    console.log("this.testDeFiAdapter.address");
    console.log(this.testDeFiAdapter.address);

    // Sushiswap's deposit vault instance
    const sushiswapDepositInstance = await hre.ethers.getContractAt("ISushiswapDeposit", pool.vault);

    // Sushiswap receipt token decimals
    const decimals = await sushiswapDepositInstance.decimals();

    // Sushiswap's underlying token instance
    const underlyingTokenInstance = await hre.ethers.getContractAt("IERC20", pool.wantToken);

    // 1. deposit all underlying tokens
    await this.testDeFiAdapter.testGetDepositAllCodes(
      pool.wantToken,
      pool.vault,
      this.sushiswapAdapter.address,
      getOverrideOptions(),
    );
    console.log("1");
    // 1.1 assert whether receipt ?? token balance is as expected or not after deposit (test the getLiquidityPoolTokenBalance function)
    const actualLPTokenBalanceAfterDeposit = await this.sushiswapAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.vault,
    );
    const expectedLPTokenBalanceAfterDeposit = await sushiswapDepositInstance.balanceOf(this.testDeFiAdapter.address);
    console.log("expectedLPTokenBalanceAfterDeposit");
    console.log(expectedLPTokenBalanceAfterDeposit);
    const tokenBalanceInTestAdapter = await underlyingTokenInstance.balanceOf(this.testDeFiAdapter.address);
    console.log("tokenBalanceInTestAdapter");
    console.log(tokenBalanceInTestAdapter);

    expect(actualLPTokenBalanceAfterDeposit).to.be.eq(expectedLPTokenBalanceAfterDeposit);
    console.log("2");
    // 1.2 assert whether underlying token balance is as expected or not after deposit (test the getUnderlyingTokens function)
    const actualUnderlyingTokenBalanceAfterDeposit = await this.testDeFiAdapter.getERC20TokenBalance(
      (
        await this.sushiswapAdapter.getUnderlyingTokens(pool.vault, pool.vault)
      )[0],
      this.testDeFiAdapter.address,
    );
    const expectedUnderlyingTokenBalanceAfterDeposit = await underlyingTokenInstance.balanceOf(
      this.testDeFiAdapter.address,
    );
    expect(actualUnderlyingTokenBalanceAfterDeposit).to.be.eq(expectedUnderlyingTokenBalanceAfterDeposit);
    console.log("3");

    // 1.3 assert whether the amount in token is as expected or not after depositing
    const actualAmountInTokenAfterDeposit = await this.sushiswapAdapter.getAllAmountInToken(
      this.testDeFiAdapter.address,
      pool.wantToken,
      pool.vault,
    );
    console.log("3.1");

    const pricePerFullShareAfterDeposit = 1; //await sushiswapDepositInstance.getPricePerFullShare();
    console.log("3.2");

    const expectedAmountInTokenAfterDeposit = BigNumber.from(expectedLPTokenBalanceAfterDeposit)
      .mul(BigNumber.from(pricePerFullShareAfterDeposit))
      .div(BigNumber.from("10").pow(BigNumber.from(decimals)));
    console.log("3.3");

    expect(actualAmountInTokenAfterDeposit).to.be.eq(expectedAmountInTokenAfterDeposit);
    console.log("4");

    // 2. Withdraw all token balance
    await this.testDeFiAdapter.testGetWithdrawAllCodes(
      pool.wantToken,
      pool.vault,
      this.sushiswapAdapter.address,
      getOverrideOptions(),
    );
    console.log("5");

    // 2.1 assert whether token balance is as expected or not
    const actualLPTokenBalanceAfterWithdraw = await this.sushiswapAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.vault,
    );
    const expectedLPTokenBalanceAfterWithdraw = await sushiswapDepositInstance.balanceOf(this.testDeFiAdapter.address);
    expect(actualLPTokenBalanceAfterWithdraw).to.be.eq(expectedLPTokenBalanceAfterWithdraw);
    console.log("6");

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
    expect(actualUnderlyingTokenBalanceAfterWithdraw).to.be.eq(expectedUnderlyingTokenBalanceAfterWithdraw);
  }).timeout(100000);
}
