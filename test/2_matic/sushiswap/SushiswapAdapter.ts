import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { SushiswapAdapter } from "../../../typechain/SushiswapAdapter";
import { TestDeFiAdapter } from "../../../typechain/TestDeFiAdapter";

import { LiquidityPool, Signers } from "../types";
import { shouldBehaveLikeSushiswapAdapter } from "./SushiswapAdapter.behavior";
import { default as SushiswapLendingPairs } from "./sushiswap_kashi_pairs.json";
import { IUniswapV2Router02 } from "../../../typechain";
import { getOverrideOptions } from "../../utils";

const { deployContract } = hre.waffle;

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await hre.ethers.getSigners();

    this.signers.admin = signers[0];
    this.signers.deployer = signers[2];

    // get the UniswapV2Router contract instance
    this.swapRouter = <IUniswapV2Router02>(
      await hre.ethers.getContractAt("IUniswapV2Router02", "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff") //Quickswap router 0xa5...
    );
    // deploy Sushiswap Adapter
    const sushiswapAdapterArtifact: Artifact = await hre.artifacts.readArtifact("SushiswapAdapter");
    this.sushiswapAdapter = <SushiswapAdapter>(
      await deployContract(
        this.signers.deployer,
        sushiswapAdapterArtifact,
        ["0x99fa011e33a8c6196869dec7bc407e896ba67fe3"],
        getOverrideOptions(),
      )
    );

    // deploy TestDeFiAdapter Contract
    const testDeFiAdapterArtifact: Artifact = await hre.artifacts.readArtifact("TestDeFiAdapter");
    this.testDeFiAdapter = <TestDeFiAdapter>(
      await deployContract(this.signers.deployer, testDeFiAdapterArtifact, [], getOverrideOptions())
    );

    // approve KashiMasterContract to spend TestDefiAdaptor's tokens
    this.testDeFiAdapter.approveKashiMasterContract(); //NB this would need to be done for the actual adaptor later on!!
  });

  describe("SushiswapAdapter", function () {
    Object.keys(SushiswapLendingPairs).map((token: string) => {
      shouldBehaveLikeSushiswapAdapter(token, (SushiswapLendingPairs as LiquidityPool)[token]);
    });
  });
});
