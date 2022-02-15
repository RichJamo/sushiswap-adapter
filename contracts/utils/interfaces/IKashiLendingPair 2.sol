// SPDX-License-Identifier: MIT

pragma solidity =0.8.11;
pragma experimental ABIEncoderV2;

interface IKashiLendingPair {
    function asset() external view returns (address); //replaces want()from Beefy and underlying() from Harvest

    function decimals() external view returns (uint256); //fine

    function totalSupply() external view returns (uint256);

    //replaces balance() from Beefy and underlyingBalanceWithInvestment() from Harvest

    function balanceOf(address account) external view returns (uint256); //fine

    function totalAsset() external view returns (uint128 elastic, uint128 base);

    function totalBorrow() external view returns (uint128 elastic, uint128 base);
}
