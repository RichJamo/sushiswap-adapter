// SPDX-License-Identifier: MIT
// File @sushiswap/bentobox-sdk/contracts/IBentoBoxV1.sol@v1.0.1

pragma solidity =0.8.11;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBentoBoxV1 {
    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function toAmount(
        IERC20 token,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    function toShare(
        IERC20 token,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);
}
