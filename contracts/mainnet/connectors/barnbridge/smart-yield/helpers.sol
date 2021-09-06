pragma solidity ^0.7.0;

import { DSMath } from "../../../common/math.sol";
import { Basic } from "../../../common/basic.sol";

import { BarnBridgeSmartYieldInterface } from "./interface.sol";

abstract contract Helpers is DSMath, Basic {
    /**
     * @dev BarnBridge Smart Yield Mapping
     */
    BarnBridgeSmartYieldInterface internal constant bbMapping =
        BarnBridgeSmartYieldInterface(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
}
