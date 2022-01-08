pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// solhint-disable avoid-low-level-calls
// solhint-disable not-rely-on-time
// solhint-disable no-inline-assembly

import "../../utils/interfaces/IERC20_.sol";

// File contracts/interfaces/IWETH.sol
// License-Identifier: MIT

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256) external;
}
