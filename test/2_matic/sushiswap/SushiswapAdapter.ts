import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddress } from "ethers/lib/utils";
import { SushiswapAdapter } from "../../../typechain/SushiswapAdapter";
import { TestDeFiAdapter } from "../../../typechain/TestDeFiAdapter";
import { BentoBoxV1 } from "../../../typechain/BentoBoxV1";

import { LiquidityPool, Signers } from "../types";
import { shouldBehaveLikeSushiswapAdapter } from "./SushiswapAdapter.behavior";
import { default as SushiswapLendingPairs } from "./test.json";
import { IUniswapV2Router02 } from "../../../typechain";
import { getOverrideOptions } from "../../utils";

const { deployContract } = hre.waffle;

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await hre.ethers.getSigners();

    this.signers.admin = signers[0];
    this.signers.owner = signers[1];
    this.signers.deployer = signers[2];
    this.signers.alice = signers[3];

    let wmatic_address = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
    // const weth_token = await hre.ethers.getContractAt("IERC20", wmatic_address);
    let masterContractAddress = "0xb527c5295c4bc348cbb3a2e96b2494fd292075a7"; //"0x99c0fbdf5b56bada277fbd407211c8add58c25e0";
    let bentoboxAddress = "0x0319000133d3AdA02600f0875d2cf03D442C3367";

    // hre.ethers.utils.defaultAbiCoder.encode(["address", "address", "int256", "int256"], [_underlyingToken, msg.sender, _amount, 0])

    // let stringExample = hre.ethers.utils.defaultAbiCoder.encode(["string"], ["AAAA"]);
    // console.log(stringExample);
    // get the UniswapV2Router contract instance
    this.swapRouter = <IUniswapV2Router02>(
      await hre.ethers.getContractAt("IUniswapV2Router02", "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff") //Quickswap router 0xa5...
    );
    // this.swapRouter = <IUniswapV2Router02>await hre.ethers.getContractAt("IUniswapV2Router02", swapRouterAddress); //changed this to polygon apeswap router

    // deploy Sushiswap Adapter
    const sushiswapAdapterArtifact: Artifact = await hre.artifacts.readArtifact("SushiswapAdapter");
    this.sushiswapAdapter = <SushiswapAdapter>(
      await deployContract(this.signers.deployer, sushiswapAdapterArtifact, [], getOverrideOptions())
    );

    // deploy TestDeFiAdapter Contract
    const testDeFiAdapterArtifact: Artifact = await hre.artifacts.readArtifact("TestDeFiAdapter");
    this.testDeFiAdapter = <TestDeFiAdapter>(
      await deployContract(this.signers.deployer, testDeFiAdapterArtifact, [], getOverrideOptions())
    );

    this.testDeFiAdapter.approveKashiMasterContract(); //NB this would need to be done for the actual adaptor later on!!

    // deploy Bentobox Contract
    // const bentoBoxArtifact: Artifact = await hre.artifacts.readArtifact("BentoBoxV1");
    // this.bentoBoxV1 = <BentoBoxV1>(
    //   await deployContract(this.signers.deployer, bentoBoxArtifact, [(wmatic_address)], getOverrideOptions()) //should this be just the address (wmatic_address) or should it be an ERC20?
    // );
    // console.log("deployed");
    // deploy Bentobox Contract
    this.bentobox = await hre.ethers.getContractAt("IBentoBoxV1", bentoboxAddress);
    //   console.log("got to here")
    // //todo: need to set master contract approval for bentobox here!! why is it working without this??? It's not, but it's not reverting...
    // await this.bentobox.connect(this.sushiswapAdapter).setMasterContractApproval( //.connect(this.testDeFiAdapter)
    //   this.sushiswapAdapter.address,
    //   masterContractAddress,
    //   true,
    //   0,
    //   "0x0000000000000000000000000000000000000000000000000000000000000000",
    //   "0x0000000000000000000000000000000000000000000000000000000000000000"); //hre.ethers.utils.formatBytes32String("0")
    // console.log("and then got to here")

    // fund TestDeFiAdapter with initialWantTokenBalance
    for (const pool of Object.values(SushiswapLendingPairs)) {
      const wantTokenAddress = pool.wantToken;
      console.log(wantTokenAddress);
      //if wantToken is WMATIC, wrap MATIC into WMATIC
      if (wantTokenAddress == hre.ethers.utils.getAddress(wmatic_address)) {
        console.log("want is wmatic");
        const wmatic_token = await hre.ethers.getContractAt("IWETH", wantTokenAddress);
        await wmatic_token.deposit({ value: hre.ethers.utils.parseEther("50") });
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
      const WANT_TOKEN_CONTRACT = await hre.ethers.getContractAt("IERC20", pool.wantToken);

      //get balance of wantToken
      const initialWantTokenBalance = await WANT_TOKEN_CONTRACT.balanceOf(this.signers.admin.address);
      console.log(initialWantTokenBalance);

      //transfer want to testDeFiAdapter
      await WANT_TOKEN_CONTRACT.transfer(this.testDeFiAdapter.address, initialWantTokenBalance, getOverrideOptions());
      const testDefiAdapterWantBalance = await WANT_TOKEN_CONTRACT.balanceOf(this.testDeFiAdapter.address);
      console.log(testDefiAdapterWantBalance);
    }
  });

  describe("SushiswapAdapter", function () {
    Object.keys(SushiswapLendingPairs).map((token: string) => {
      shouldBehaveLikeSushiswapAdapter(token, (SushiswapLendingPairs as LiquidityPool)[token]);
    });
  });
});
