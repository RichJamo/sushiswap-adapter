// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IAdapterFull } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterFull.sol";
import "../utils/interfaces/IBentoBoxV1.sol";

import { MultiCall } from "../utils/MultiCall.sol";
import "hardhat/console.sol";

///////////////////////////////////////
/// THIS CONTRACT MOCKS AS A VAULT ///
///////////////////////////////////////

////////////////////////////////
/// DO NOT USE IN PRODUCTION ///
////////////////////////////////

contract TestDeFiAdapter is MultiCall {
    address public constant bentoBoxAddress = address(0x0319000133d3AdA02600f0875d2cf03D442C3367);

    address public constant kashiMasterContract = address(0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7);

    function approveKashiMasterContract() external {
        IBentoBoxV1 bentoBox = IBentoBoxV1(bentoBoxAddress);

        bentoBox.setMasterContractApproval(
            address(this),
            kashiMasterContract,
            true,
            0,
            bytes32(0),
            bytes32(0) //0x0000000000000000000000000000000000000000000000000000000000000000
        );
    }

    function testGetDepositAllCodes(
        address _underlyingToken,
        address _liquidityPool,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getDepositAllCodes(payable(address(this)), _underlyingToken, _liquidityPool),
            "depositAll"
        );
    }

    function testGetDepositSomeCodes(
        address _underlyingToken,
        address _liquidityPool,
        address _adapter,
        uint256 _amount
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getDepositSomeCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool,
                _amount
            ),
            "depositSome"
        );
    }

    function testGetBorrowAllCodes(
        address _liquidityPool,
        address _underlyingToken,
        address _outputToken,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getBorrowAllCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool,
                _outputToken
            ),
            "borrowAll"
        );
    }

    function testGetStakeAllCodes(
        address _liquidityPool,
        address _underlyingToken,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getStakeAllCodes(payable(address(this)), _underlyingToken, _liquidityPool),
            "stakeAll!"
        );
    }

    function testGetStakeSomeCodes(
        address _liquidityPool,
        uint256 _stakeAmount,
        address _adapter
    ) external {
        executeCodes(IAdapterFull(_adapter).getStakeSomeCodes(_liquidityPool, _stakeAmount), "stakeSome!");
    }

    function testClaimRewardTokenCode(address _liquidityPool, address _adapter) external {
        executeCodes(
            IAdapterFull(_adapter).getClaimRewardTokenCode(payable(address(this)), _liquidityPool),
            "claimReward"
        );
    }

    function testGetHarvestAllCodes(
        address _liquidityPool,
        address _underlyingToken,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getHarvestAllCodes(payable(address(this)), _underlyingToken, _liquidityPool),
            "harvestAll"
        );
    }

    function testGetHarvestSomeCodes(
        address _liquidityPool,
        address _underlyingToken,
        address _adapter,
        uint256 _rewardTokenAmount
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getHarvestSomeCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool,
                _rewardTokenAmount
            ),
            "harvestSome"
        );
    }

    function testGetUnstakeAllCodes(address _liquidityPool, address _adapter) external {
        executeCodes(IAdapterFull(_adapter).getUnstakeAllCodes(payable(address(this)), _liquidityPool), "unstakeAll");
    }

    function testGetUnstakeSomeCodes(
        address _liquidityPool,
        uint256 _stakeAmount,
        address _adapter
    ) external {
        executeCodes(IAdapterFull(_adapter).getUnstakeSomeCodes(_liquidityPool, _stakeAmount), "unstakeAll");
    }

    function testGetWithdrawAllCodes(
        address _underlyingToken,
        address _liquidityPool,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getWithdrawAllCodes(payable(address(this)), _underlyingToken, _liquidityPool),
            "withdrawAll"
        );
    }

    function testGetWithdrawSomeCodes(
        address _underlyingToken,
        address _liquidityPool,
        address _adapter,
        uint256 _amount
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getWithdrawSomeCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool,
                _amount
            ),
            "withdrawSome"
        );
    }

    function testGetRepayAndWithdrawAllCodes(
        address _liquidityPool,
        address _underlyingToken,
        address _outputToken,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getRepayAndWithdrawAllCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool,
                _outputToken
            ),
            "repayAndWithdrawAll"
        );
    }

    function testGetUnstakeAndWithdrawAllCodes(
        address _liquidityPool,
        address _underlyingToken,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getUnstakeAndWithdrawAllCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool
            ),
            "unstakeAndWithdrawAll"
        );
    }

    function testGetUnstakeAndWithdrawSomeCodes(
        address _liquidityPool,
        address _underlyingToken,
        uint256 _redeemAmount,
        address _adapter
    ) external {
        executeCodes(
            IAdapterFull(_adapter).getUnstakeAndWithdrawSomeCodes(
                payable(address(this)),
                _underlyingToken,
                _liquidityPool,
                _redeemAmount
            ),
            "unstakeAndWithdrawSome"
        );
    }

    function getERC20TokenBalance(address _token, address _account) external view returns (uint256) {
        return ERC20(_token).balanceOf(_account);
    }
}
