// solhint-disable no-unused-vars
// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

/////////////////////////////////////////////////////
/// PLEASE DO NOT USE THIS CONTRACT IN PRODUCTION ///
/////////////////////////////////////////////////////

//  libraries
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";
import { IERC20_ } from "../../utils/interfaces/IERC20_.sol";

//  interfaces
//todo: check these first two - do I need Sushi equivalents?
import { IKashiLendingPair } from "@optyfi/defi-legos/polygon/sushiswap/contracts/IKashiLendingPair.sol";
import { IBentoBoxV1 } from "../../utils/interfaces/IBentoBoxV1.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAdapter } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapter.sol";
import { IAdapterInvestLimit } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterInvestLimit.sol";
import { IAdapterHarvestReward } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterHarvestReward.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title Adapter for Sushiswap protocol
 * @author Opty.fi
 * @dev Abstraction layer to harvest finance's pools
 */

// enum MaxExposure { Number, Pct }

contract SushiswapAdapter is IAdapter, IAdapterHarvestReward, IAdapterInvestLimit {
    using SafeMath for uint256;

    /**
     * @notice Uniswap V2 router contract address
     */
    address public constant uniswapV2Router02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    /**
     * @notice Bentobox Master contract address
     */
    address public constant bentoBox = address(0x0319000133d3AdA02600f0875d2cf03D442C3367);

    address public constant kashiMasterContract = address(0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7);

    /** @notice Sushiswap's reward token address */
    address public constant rewardToken = address(0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64);

    // uint8[] actionsArray;
    // actionsArray[0] = uint8(24);
    // uint256[] memory valuesArray;
    // valuesArray[0] = 0;
    // bytes[] memory datasArray;
    // datasArray[0] = abi.encode(address(this), kashiMasterContract, true, 0, bytes32(0), bytes32(0));

    // /** @notice Named Constants for defining max exposure state */
    // enum MaxExposure { Number, Pct }

    constructor() public {}

    /**
     * @inheritdoc IAdapter
     */
    function getDepositAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _amount = IERC20(_underlyingToken).balanceOf(_vault);
        return getDepositSomeCodes(_vault, _underlyingToken, _liquidityPool, _amount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _redeemAmount = getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPool);
        return getWithdrawSomeCodes(_vault, _underlyingToken, _liquidityPool, _redeemAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getUnderlyingTokens(address _liquidityPool, address)
        public
        view
        override
        returns (address[] memory _underlyingTokens)
    {
        _underlyingTokens = new address[](1);
        _underlyingTokens[0] = IKashiLendingPair(_liquidityPool).asset();
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateAmountInLPToken(
        address,
        address _liquidityPool,
        uint256 _depositAmount
    ) public view override returns (uint256) {
        return
            _depositAmount.mul(10**IKashiLendingPair(_liquidityPool).decimals()).div(
                IKashiLendingPair(_liquidityPool).getPricePerFullShare()
            );
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateRedeemableLPTokenAmount(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (uint256 _amount) {
        uint256 _liquidityPoolTokenBalance = getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPool);
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _liquidityPool);
        // can have unintentional rounding errors
        _amount = (_liquidityPoolTokenBalance.mul(_redeemAmount)).div(_balanceInToken).add(1);
    }

    /**
     * @inheritdoc IAdapter
     */
    function isRedeemableAmountSufficient(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (bool) {
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _liquidityPool);
        return _balanceInToken >= _redeemAmount;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getClaimRewardTokenCode(address payable, address _liquidityPool)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        address _stakingVault = address(0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64); //todo - change this!
        _codes = new bytes[](1);
        _codes[0] = abi.encode(_stakingVault, abi.encodeWithSignature("getReward()"));
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _rewardTokenAmount = IERC20(getRewardToken(_liquidityPool)).balanceOf(_vault);
        return getHarvestSomeCodes(_vault, _underlyingToken, _liquidityPool, _rewardTokenAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function canStake(address) public view override returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IAdapter
     */
    // function getDepositSomeCodes(
    //     address payable,
    //     address _underlyingToken,
    //     address _liquidityPool,
    //     uint256 _amount
    // ) public view override returns (bytes[] memory _codes) {
    //     if (_amount > 0) {
    //         _codes = new bytes[](1);
    //         _codes[0] = abi.encode(_liquidityPool, abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])",));

    //         _codes[1] = abi.encode(_liquidityPool, abi.encodeWithSignature("addAsset(address,bool,uint256)",address(this), true, 999));

    //     }
    // }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositSomeCodes(
        address payable,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _amount
    ) public view override returns (bytes[] memory _codes) {
        uint8[] memory actionsArray = new uint8[](2);
        actionsArray[0] = 20; //BENTO_DEPOSIT
        actionsArray[1] = 1; //ADD ASSET

        uint256[] memory valuesArray = new uint256[](2);
        valuesArray[0] = 0;
        valuesArray[1] = 0;

        bytes[] memory datasArray = new bytes[](2);
        datasArray[0] = abi.encode(address(_underlyingToken), address(msg.sender), int256(_amount), int256(0));
        datasArray[1] = abi.encode(int256(-2), address(msg.sender), false); //skim is false - tokens come from bentobox

        if (_amount > 0) {
            _codes = new bytes[](3);
            _codes[0] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", bentoBox, uint256(0))
            );
            _codes[1] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", bentoBox, _amount)
            );
            _codes[2] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])", actionsArray, valuesArray, datasArray)
            );
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawSomeCodes(
        address payable,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _shares //is really fraction in this case - still comes from balanceOf
    ) public view override returns (bytes[] memory _codes) {
        uint8[] memory actionsArray = new uint8[](1);
        actionsArray[0] = 3; //ACTION_REMOVE_ASSET
        // actionsArray[1] = 21; //ACTION_BENTO_WITHDRAW

        uint256[] memory valuesArray = new uint256[](1);
        valuesArray[0] = 0;
        // valuesArray[1] = 0;

        bytes[] memory datasArray = new bytes[](1);
        console.log(_shares.sub(10000));
        datasArray[0] = abi.encode(int256(_shares.sub(10000)), address(msg.sender)); //fraction, to; int256, address; returns share
        //token, to, amount, share; IERC20, address, int256, int256
        // datasArray[1] = abi.encode(IERC20(_underlyingToken),address(msg.sender),0, int256(-1));

        if (_shares > 0) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])", actionsArray, valuesArray, datasArray)
            );
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getPoolValue(address _liquidityPool, address) public view override returns (uint256) {
        return IKashiLendingPair(_liquidityPool).totalSupply();
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolToken(address, address _liquidityPool) public view override returns (address) {
        return _liquidityPool;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getAllAmountInToken(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (uint256) {
        return
            getSomeAmountInToken(
                _underlyingToken,
                _liquidityPool,
                getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPool)
            );
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolTokenBalance(
        address payable _vault,
        address,
        address _liquidityPool
    ) public view override returns (uint256) {
        return IERC20(_liquidityPool).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getSomeAmountInToken(
        address _underlyingToken,
        address _liquidityPool,
        uint256 _liquidityPoolTokenAmount
    ) public view override returns (uint256) {
        (uint128 totalAssetElastic, ) = IKashiLendingPair(_liquidityPool).totalAsset();
        (uint128 totalBorrowElastic, ) = IKashiLendingPair(_liquidityPool).totalBorrow();
        // console.log(totalAssetElastic);
        // console.log(totalBorrowElastic);
        // console.log(_liquidityPoolTokenAmount);
        // console.log(IKashiLendingPair(_liquidityPool).totalSupply());

        if (_liquidityPoolTokenAmount > 0) {
            _liquidityPoolTokenAmount = _liquidityPoolTokenAmount
                .mul(
                    IBentoBoxV1(bentoBox).toAmount(IERC20_(_underlyingToken), totalAssetElastic, false).add(
                        totalBorrowElastic
                    )
                )
                .div(IKashiLendingPair(_liquidityPool).totalSupply());
            //.mul(10**18) //.mul(10**IKashiLendingPair(_liquidityPool).decimals())
            //.div(10**18) //div(10**IKashiLendingPair(_liquidityPool).decimals())
        }
        return _liquidityPoolTokenAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getRewardToken(address) public view override returns (address) {
        return rewardToken;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getUnclaimedRewardTokenAmount(
        address payable _vault,
        address _liquidityPool,
        address
    ) public view override returns (uint256) {
        // return IHarvestFarm(liquidityPoolToStakingVault[_liquidityPool]).earned(_vault);
        return 999;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _rewardTokenAmount
    ) public view override returns (bytes[] memory _codes) {
        return _getHarvestCodes(_vault, getRewardToken(_liquidityPool), _underlyingToken, _rewardTokenAmount);
    }

    /* solhint-disable no-empty-blocks */

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getAddLiquidityCodes(address payable, address) public view override returns (bytes[] memory) {}

    /**
     * @notice Sets the absolute max deposit value in underlying for the given liquidity pool
     * @param _liquidityPool liquidity pool address for which to set max deposit value (in absolute value)
     * @param _underlyingToken address of underlying token
     * @param _maxDepositAmount absolute max deposit amount in underlying to be set for given liquidity pool
     */
    function setMaxDepositAmount(
        address _liquidityPool,
        address _underlyingToken,
        uint256 _maxDepositAmount
    ) external override {}

    /**
     * @notice Sets the percentage of max deposit value for the given liquidity pool
     * @param _liquidityPool liquidity pool address
     * @param _maxDepositPoolPct liquidity pool's max deposit percentage (in basis points, For eg: 50% means 5000)
     */
    function setMaxDepositPoolPct(address _liquidityPool, uint256 _maxDepositPoolPct) external override {}

    /**
     * @notice Sets the percentage of max deposit protocol value
     * @param _maxDepositProtocolPct protocol's max deposit percentage (in basis points, For eg: 50% means 5000)
     */
    function setMaxDepositProtocolPct(uint256 _maxDepositProtocolPct) external override {}

    /**
     * @notice Sets the type of investment limit
     *                  1. Percentage of pool value
     *                  2. Amount in underlying token
     * @dev Types (can be number or percentage) supported for the maxDeposit value
     * @param _mode Mode of maxDeposit to be set (can be absolute value or percentage)
     */
    function setMaxDepositProtocolMode(MaxExposure _mode) external override {}

    /* solhint-enable no-empty-blocks */

    /**
     * @dev Get the codes for harvesting the tokens using uniswap router
     * @param _vault Vault contract address
     * @param _rewardToken Reward token address
     * @param _underlyingToken Token address acting as underlying Asset for the vault contract
     * @param _rewardTokenAmount reward token amount to harvest
     * @return _codes List of harvest codes for harvesting reward tokens
     */
    function _getHarvestCodes(
        address payable _vault,
        address _rewardToken,
        address _underlyingToken,
        uint256 _rewardTokenAmount
    ) internal view returns (bytes[] memory _codes) {
        if (_rewardTokenAmount > 0) {
            uint256[] memory _amounts = IUniswapV2Router02(uniswapV2Router02).getAmountsOut(
                _rewardTokenAmount,
                _getPath(_rewardToken, _underlyingToken)
            );
            if (_amounts[_amounts.length - 1] > 0) {
                _codes = new bytes[](3);
                _codes[0] = abi.encode(
                    _rewardToken,
                    abi.encodeWithSignature("approve(address,uint256)", uniswapV2Router02, uint256(0))
                );
                _codes[1] = abi.encode(
                    _rewardToken,
                    abi.encodeWithSignature("approve(address,uint256)", uniswapV2Router02, _rewardTokenAmount)
                );
                _codes[2] = abi.encode(
                    uniswapV2Router02,
                    abi.encodeWithSignature(
                        "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                        _rewardTokenAmount,
                        uint256(0),
                        _getPath(_rewardToken, _underlyingToken),
                        _vault,
                        uint256(-1)
                    )
                );
            }
        }
    }

    /**
     * @dev Constructs the path for token swap on Uniswap
     * @param _initialToken The token to be swapped with
     * @param _finalToken The token to be swapped for
     * @return _path The array of tokens in the sequence to be swapped for
     */
    function _getPath(address _initialToken, address _finalToken) internal pure returns (address[] memory _path) {
        address _weth = IUniswapV2Router02(uniswapV2Router02).WETH();
        if (_finalToken == _weth) {
            _path = new address[](2);
            _path[0] = _initialToken;
            _path[1] = _weth;
        } else if (_initialToken == _weth) {
            _path = new address[](2);
            _path[0] = _weth;
            _path[1] = _finalToken;
        } else {
            _path = new address[](3);
            _path[0] = _initialToken;
            _path[1] = _weth;
            _path[2] = _finalToken;
        }
    }

    /**
     * @dev Get the underlying token amount equivalent to reward token amount
     * @param _rewardToken Reward token address
     * @param _underlyingToken Token address acting as underlying Asset for the vault contract
     * @param _amount reward token balance amount
     * @return equivalent reward token balance in Underlying token value
     */
    function _getRewardBalanceInUnderlyingTokens(
        address _rewardToken,
        address _underlyingToken,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256[] memory _amountsA = IUniswapV2Router02(uniswapV2Router02).getAmountsOut(
            _amount,
            _getPath(_rewardToken, _underlyingToken)
        );
        return _amountsA[_amountsA.length - 1];
    }
}
