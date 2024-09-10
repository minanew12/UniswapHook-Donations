// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";

contract CounterScript is Script {
    AfterSwapDonationHook public donationHook;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // donationHook = new AfterSwapDonationHook();

        vm.stopBroadcast();
    }
}
