pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/interfaces/IBentoBoxV1.sol";
import "../../utils/interfaces/IKashiPair.sol";

contract test {
    address public constant bentoBoxAddress = address(0x0319000133d3AdA02600f0875d2cf03D442C3367);

    address public constant kashiMasterContract = address(0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7);

    address public constant kashiLendingPair = address(0x99C0fbDf5b56bADA277FBD407211C8aDD58c25e0);

    function setMaster() external {
        IBentoBoxV1 bentoBox = IBentoBoxV1(bentoBoxAddress);

        bentoBox.setMasterContractApproval(
            address(this), //change to address(this)? or do this earlier in approval stage? who's tokens are being spent?
            kashiMasterContract,
            true,
            0,
            bytes32(0),
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
    }

    function testCook() external {
        //uint8[] calldata _firstArray, uint256[] calldata _secondArray, bytes[] calldata _thirdArray
        IKashiPair kashiPair = IKashiPair(kashiLendingPair);
        // cook(uint8[],uint256[],bytes[])
        uint8[] memory firstArray = new uint8[](1);
        firstArray[0] = 24;
        uint256[] memory secondArray = new uint256[](1);
        secondArray[0] = 0;
        bytes[] memory thirdArray = new bytes[](1);
        thirdArray[0] = abi.encode(kashiLendingPair, kashiMasterContract, true, 0, bytes32(0), bytes32(0));

        kashiPair.cook(firstArray, secondArray, thirdArray);
    }
}
