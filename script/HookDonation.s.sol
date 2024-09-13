// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {DonationTest} from "../test/HookDonation.t.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
// K:\Development\Ethereum\UniswapHook-Donations\lib\v4-periphery\lib\v4-core\src\interfaces\IHooks.sol
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Constants} from "lib/v4-core/test/utils/Constants.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
// K:\Development\Ethereum\UniswapHook-Donations\lib\v4-periphery\lib\v4-core\src\interfaces\IPoolManager.sol
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract AfterSwapDonationHookDeployScript is Script, Deployers {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    AfterSwapDonationHook public donationHook;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Define tokens and pool parameters
        address tokenA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // WETH
        address tokenB = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0; // USDT
        uint24 fee = 3000; // Fee in basis points, ie, 0.30%

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER, flags, type(AfterSwapDonationHook).creationCode, abi.encode(address(manager))
        );
        donationHook = new AfterSwapDonationHook{salt: salt}(IPoolManager(address(manager)));

        // Create PoolKey
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(tokenA),
            currency1: Currency.wrap(tokenB),
            fee: fee,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        // Initialize the pool
        manager.initialize(key, Constants.SQRT_PRICE_1_1, "");

        vm.stopBroadcast();
    }
}
