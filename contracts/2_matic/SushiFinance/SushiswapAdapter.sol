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

//  interfaces
//todo: check these first two - do I need Sushi equivalents?
import { ISushiswapDeposit } from "@optyfi/defi-legos/polygon/sushiswap/contracts/ISushiswapDeposit.sol";
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

    // uint8[] firstArray;
    // firstArray[0] = uint8(24);
    // uint256[] memory secondArray;
    // secondArray[0] = 0;
    // bytes[] memory thirdArray;
    // thirdArray[0] = abi.encode(address(this), kashiMasterContract, true, 0, bytes32(0), bytes32(0));

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
        console.log("made it into getDepositAllCodes");
        uint256 _amount = IERC20(_underlyingToken).balanceOf(_vault);
        console.log(_amount);
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
        _underlyingTokens[0] = ISushiswapDeposit(_liquidityPool).asset();
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
            _depositAmount.mul(10**ISushiswapDeposit(_liquidityPool).decimals()).div(
                ISushiswapDeposit(_liquidityPool).getPricePerFullShare()
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
        console.log("made it into getDepositSomeCodes");
        console.log(msg.sender);

        uint8[] memory firstArray = new uint8[](1);
        firstArray[0] = 24;
        uint256[] memory secondArray = new uint256[](1);
        secondArray[0] = 0;
        bytes[] memory thirdArray = new bytes[](1);
        thirdArray[0] = abi.encode(msg.sender, kashiMasterContract, true, 0, bytes32(0), bytes32(0));

        if (_amount > 0) {
            console.log("made it into the conditional");
            _codes = new bytes[](5);
            console.log(_amount);
            //"deposit(IERC20 token_,address from,address to,uint256 amount,uint256 share)"
            _codes[0] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, uint256(0))
            );
            _codes[1] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amount)
            );
            _codes[2] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", bentoBox, uint256(0))
            );
            _codes[3] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", bentoBox, _amount)
            );
            _codes[4] = abi.encode(
                bentoBox,
                abi.encodeWithSignature(
                    "setMasterContractApproval(address, address, bool, uint8, bytes32, bytes32)",
                    msg.sender, //msg.sender gives us the address of TestDefiAdapter, which is the thing that actually executes the code
                    kashiMasterContract,
                    true,
                    0,
                    bytes32(0),
                    bytes32(0)
                )
            );
            // _codes[4] = abi.encode(_liquidityPool,abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])",
            //     firstArray,
            //     secondArray,
            //     thirdArray
            //     )
            // );

            // _codes[4] = abi.encode(_liquidityPool,abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])",
            //     [24], //BENTO_SET_APPROVAL
            //     [0],
            //     [abi.encode(address(msg.sender), address(kashiMasterContract), bool(true), uint8(0), bytes32(0), bytes32(0))]
            //     )
            // );

            // _codes[5] = abi.encode(_liquidityPool,abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])",
            //     [20],
            //     [0],
            //     [abi.encode(address(_underlyingToken),address(msg.sender),int256(_amount),int256(0))]
            //     )
            // );
            // _codes[4] = abi.encode(
            //     bentoBox,
            //     abi.encodeWithSignature(
            //         "deposit(address,address,address,uint256,uint256)",
            //         address(_underlyingToken),
            //         msg.sender,
            //         msg.sender,
            //         _amount,
            //         0
            //     )
            // );
            // IERC20 output = abi.decode(abi.encode(IERC20(_underlyingToken)), (IERC20));
            // console.log(address(output));
            // (IERC20 output1, address output2, int256 output3, int256 output4) = abi.decode(abi.encode(IERC20(_underlyingToken),address(msg.sender),int256(_amount),int256(0)), (IERC20,address,int256,int256));
            // console.log(address(output));
            // console.log("output1",address(output1));
            // console.log(output2);
            // console.log(uint256(output3));
            // console.log(uint256(output4));

            // _codes[2] = abi.encode(_liquidityPool, abi.encodeWithSignature("cook(uint8[],uint256[],bytes[])",
            //     [20,1],
            //     [0,0],
            //     [abi.encode(_underlyingToken, msg.sender, msg.sender, _amount, 0),
            //     abi.encode(_liquidityPool, false, 1)] //should skim be true or false? should address be msg.sender or liquidityPool?
            //     //amount should be in shares!
            //     )
            // );
            // _codes[3] = abi.encode(_liquidityPool, abi.encodeWithSignature("addAsset(address,bool,uint256)",
            //     _liquidityPool, true, _amount) //amount must be in shares?
            // );
            console.log("made it past the cook");
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawSomeCodes(
        address payable,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _shares
    ) public view override returns (bytes[] memory _codes) {
        if (_shares > 0) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(
                getLiquidityPoolToken(_underlyingToken, _liquidityPool),
                abi.encodeWithSignature("withdraw(uint256)", _shares)
            );
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getPoolValue(address _liquidityPool, address) public view override returns (uint256) {
        return ISushiswapDeposit(_liquidityPool).totalSupply();
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
        address,
        address _liquidityPool,
        uint256 _liquidityPoolTokenAmount
    ) public view override returns (uint256) {
        if (_liquidityPoolTokenAmount > 0) {
            _liquidityPoolTokenAmount = _liquidityPoolTokenAmount
                .mul(ISushiswapDeposit(_liquidityPool).getPricePerFullShare())
                .div(10**ISushiswapDeposit(_liquidityPool).decimals());
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
