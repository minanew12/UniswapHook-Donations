// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolDonateTest} from "v4-core/test/PoolDonateTest.sol";
import {PoolTakeTest} from "v4-core/test/PoolTakeTest.sol";
import {PoolClaimsTest} from "v4-core/test/PoolClaimsTest.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "lib/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {console} from "lib/v4-periphery/lib/v4-core/lib/forge-std/src/console.sol";


contract V4Deployer is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    AfterSwapDonationHook public donationHook;

    function run() public {
        vm.startBroadcast();

        PoolManager manager = new PoolManager();
        PoolSwapTest swapRouter = new PoolSwapTest(manager);

        // Anything else you need to do like minting mock ERC20s or initializing a pool
        // you need to do directly here as well without using Deployers
        // Define tokens and pool parameters
        address tokenA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH
        address tokenB = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0; // USDT
        uint24 fee = 3000; // Fee in basis points, ie, 0.30%

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        uint256 tempValue = 0;
        uint256 seed = tempValue;
        address hookAddress = address(0);
        bytes32 salt;
        while (hookAddress == address(0)) {
            (hookAddress, salt) = HookMiner.find(
                CREATE2_DEPLOYER, flags, seed, type(AfterSwapDonationHook).creationCode, abi.encode(address(manager))
            );
            if (hookAddress == address(0)) {
              seed = uint256(salt)+1;
            }
        }
        console.log("Hook Address: %s", hookAddress);
        donationHook = new AfterSwapDonationHook{salt: salt}(IPoolManager(address(manager)));

        // Create PoolKey
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(tokenA),
            currency1: Currency.wrap(tokenB),
            fee: fee,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });



        vm.stopBroadcast();
    }
}