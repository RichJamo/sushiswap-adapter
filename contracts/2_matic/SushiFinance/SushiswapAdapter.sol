// solhint-disable no-unused-vars
// SPDX-License-Identifier: agpl-3.0

pragma solidity =0.8.11;

/////////////////////////////////////////////////////
/// PLEASE DO NOT USE THIS CONTRACT IN PRODUCTION ///
/////////////////////////////////////////////////////
//  libraries

// helpers
import { AdapterModifiersBase } from "../../utils/AdapterModifiersBase.sol";

//  libraries
import "hardhat/console.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

//  interfaces
import { IKashiLendingPair } from "contracts/utils/interfaces/IKashiLendingPair.sol";
import { IBentoBoxV1 } from "contracts/utils/interfaces/IBentoBoxV1.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAdapter } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapter.sol";
import "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterInvestLimit.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IWETH } from "@optyfi/defi-legos/interfaces/misc/contracts/IWETH.sol"; //import for sake of test file

/**
 * @title Adapter for Sushiswap protocol
 * @author Opty.fi
 * @dev Abstraction layer to harvest finance's pools
 */

// enum MaxExposure { Number, Pct }

contract SushiswapAdapter is IAdapter, IAdapterInvestLimit, AdapterModifiersBase {
    using Address for address;

    /** @notice max deposit value datatypes */
    MaxExposure public maxDepositProtocolMode;

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
    address public constant rewardToken = address(0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a); //SUSHI token

    /** @notice max deposit's default value in percentage */
    uint256 public maxDepositProtocolPct; // basis points

    /** @notice  Maps liquidityPool to max deposit value in percentage */
    mapping(address => uint256) public maxDepositPoolPct; // basis points

    /** @notice  Maps liquidityPool to max deposit value in absolute value for a specific token */
    mapping(address => mapping(address => uint256)) public maxDepositAmount;

    constructor(address _registry) AdapterModifiersBase(_registry) {
        maxDepositProtocolPct = uint256(10000); // 100% (basis points)
        maxDepositProtocolMode = MaxExposure.Pct;
    }

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
        address _underlyingToken,
        address _liquidityPool,
        uint256 _depositAmount
    ) public view override returns (uint256) {
        (uint128 totalAssetElastic, uint128 totalAssetBase) = IKashiLendingPair(_liquidityPool).totalAsset();
        return
            (IBentoBoxV1(bentoBox).toShare(IERC20(_underlyingToken), _depositAmount, false) * totalAssetBase) /
            totalAssetElastic;
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
        _amount = (_liquidityPoolTokenBalance * _redeemAmount) / _balanceInToken + 1;
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
     * @inheritdoc IAdapter
     */
    function canStake(address) public view override returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositSomeCodes(
        address payable,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _amount
    ) public view override returns (bytes[] memory _codes) {
        uint256 _depositAmount = _getDepositAmount(_liquidityPool, _underlyingToken, _amount); //todo check this?

        uint8[] memory actionsArray = new uint8[](2);
        actionsArray[0] = 20; //BENTO_DEPOSIT
        actionsArray[1] = 1; //ADD ASSET

        uint256[] memory valuesArray = new uint256[](2);
        valuesArray[0] = 0;
        valuesArray[1] = 0;

        bytes[] memory datasArray = new bytes[](2);
        datasArray[0] = abi.encode(address(_underlyingToken), address(msg.sender), int256(_depositAmount), int256(0));
        datasArray[1] = abi.encode(int256(-2), address(msg.sender), false); //skim is false - tokens come from bentobox

        if (_depositAmount > 0) {
            _codes = new bytes[](3);
            _codes[0] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", bentoBox, uint256(0))
            );
            _codes[1] = abi.encode(
                _underlyingToken,
                abi.encodeWithSignature("approve(address,uint256)", bentoBox, _depositAmount)
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
        uint8[] memory actionsArray = new uint8[](2);
        actionsArray[0] = 3; //ACTION_REMOVE_ASSET
        actionsArray[1] = 21; //ACTION_BENTO_WITHDRAW

        uint256[] memory valuesArray = new uint256[](2);
        valuesArray[0] = 0;
        valuesArray[1] = 0;

        bytes[] memory datasArray = new bytes[](2);
        //fraction, to; int256, address; returns share
        datasArray[0] = abi.encode(int256(_shares), address(msg.sender));
        //token, to, amount, share; IERC20, address, int256, int256
        datasArray[1] = abi.encode(IERC20(_underlyingToken), address(msg.sender), 0, int256(-1));

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
        (uint128 totalAssetElastic, uint128 totalAssetBase) = IKashiLendingPair(_liquidityPool).totalAsset();

        if (_liquidityPoolTokenAmount > 0) {
            _liquidityPoolTokenAmount = IBentoBoxV1(bentoBox).toAmount(
                IERC20(_underlyingToken),
                (_liquidityPoolTokenAmount * totalAssetElastic) / totalAssetBase, //these three lines could be a PricePerFraction function?
                false
            );
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
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositPoolPct(address _liquidityPool, uint256 _maxDepositPoolPct)
        external
        override
        onlyRiskOperator
    {
        require(_liquidityPool.isContract(), "!isContract");
        maxDepositPoolPct[_liquidityPool] = _maxDepositPoolPct;
        emit LogMaxDepositPoolPct(maxDepositPoolPct[_liquidityPool], msg.sender);
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositAmount(
        address _liquidityPool,
        address _underlyingToken,
        uint256 _maxDepositAmount
    ) external override onlyRiskOperator {
        require(_liquidityPool.isContract(), "!_liquidityPool.isContract()");
        require(_underlyingToken.isContract(), "!_underlyingToken.isContract()");
        maxDepositAmount[_liquidityPool][_underlyingToken] = _maxDepositAmount;
        emit LogMaxDepositAmount(maxDepositAmount[_liquidityPool][_underlyingToken], msg.sender);
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositProtocolMode(MaxExposure _mode) external override onlyRiskOperator {
        maxDepositProtocolMode = _mode;
        emit LogMaxDepositProtocolMode(maxDepositProtocolMode, msg.sender);
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositProtocolPct(uint256 _maxDepositProtocolPct) external override onlyRiskOperator {
        maxDepositProtocolPct = _maxDepositProtocolPct;
        emit LogMaxDepositProtocolPct(maxDepositProtocolPct, msg.sender);
    }

    /**
     * @dev Returns the maximum allowed deposit amount considering the percentage limit or the absolute limit
     * @param _liquidityPool Liquidity pool's contract address
     * @param _underlyingToken Token address acting as underlying Asset for the vault contract
     * @param _amount The amount of the underlying token to be deposited
     * @return Returns the maximum deposit allowed according to _amount and the limits set
     */
    function _getDepositAmount(
        address _liquidityPool,
        address _underlyingToken,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _limit = maxDepositProtocolMode == MaxExposure.Pct
            ? _getMaxDepositAmountByPct(_liquidityPool)
            : maxDepositAmount[_liquidityPool][_underlyingToken];
        return _amount > _limit ? _limit : _amount;
    }

    /**
     * @dev Returns the maximum allowed deposit amount when the adapter is in percentage mode
     * @param _liquidityPool Liquidity pool's contract address
     * @return Returns the maximum deposit allowed according to _amount and the limits set
     */
    function _getMaxDepositAmountByPct(address _liquidityPool) internal view returns (uint256) {
        uint256 _poolValue = getPoolValue(_liquidityPool, address(0));
        uint256 _poolPct = maxDepositPoolPct[_liquidityPool];
        uint256 _limit = _poolPct == 0
            ? (_poolValue * maxDepositProtocolPct) / (uint256(10000))
            : (_poolValue * _poolPct) / (uint256(10000));
        return _limit;
    }

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
                        9999999999
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
