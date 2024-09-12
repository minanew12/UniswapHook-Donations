// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";

import {Deployers} from "lib/v4-core/test/utils/Deployers.sol";
import {DonationTest} from "../test/HookDonation.t.sol";

contract CounterScript is Script, Deployers {
    AfterSwapDonationHook public donationHook;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        

        vm.stopBroadcast();
    }
}
