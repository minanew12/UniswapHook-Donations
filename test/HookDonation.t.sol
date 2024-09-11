// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.26;

import "lib/v4-periphery/lib/v4-core/lib/forge-std/src/Test.sol";
import {console} from "lib/v4-periphery/lib/v4-core/lib/forge-std/src/console.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "lib/v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import {Currency, CurrencyLibrary} from "lib/v4-core/src/types/Currency.sol";
import {MockERC20} from "lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol"; // ...
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {PoolSwapTest} from "lib/v4-core/src/test/PoolSwapTest.sol";
import {BaseHook} from "lib/v4-periphery/src/base/hooks/BaseHook.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";

contract DonationTest is Test, Deployers //, ISwap 
{
    using CurrencyLibrary for Currency;

    AfterSwapDonationHook donationHook;
    
    // Mock token
    // MockERC20 token;

    // The two currencies (tokens) from the pool
    Currency token0 = Currency.wrap(address(0));
    Currency token1;
    PoolKey globalKey;
    address constant RECIPIENT = address(0x01);
    address constant RECIPIENT2 = address(0x02);

    event HookAddress(address indexed hookAddress);

    function boolToStr(bool value) internal pure returns (string memory) {
        return value ? "true": "false";
    }

    function setUp() public {
        console.log("setUp tx.origin: %s, msg.sender: %s", tx.origin, msg.sender);
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();
        (token0, token1) = (currency0, currency1);

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
                Hooks.AFTER_SWAP_FLAG
        );

        address hookAddress = address(flags);
        deployCodeTo(
            "HookDonation.sol",
            abi.encode(manager, ""),
            hookAddress
        );
        emit HookAddress(hookAddress);
        donationHook = AfterSwapDonationHook(hookAddress);
        console.log("setUp Hook Address: ", hookAddress);
        console.log("donation Hook: ", address(donationHook));
        console.log("setUp sender: %s", msg.sender);

        IHooks ihook = IHooks(address(donationHook));

        // Initialize a pool with these two tokens
        uint24 fee = 3000;
        (key, ) = initPoolAndAddLiquidity(token0, token1, ihook, fee, SQRT_PRICE_1_1, ZERO_BYTES);
        
        globalKey = key;
        separator();
    }

    function separator() internal view {
        console.log("--------------------------------------------------------------------------------");
    }
    
    function println() internal view {
        console.log();
    }

    function header(string memory _header) internal view {
        console.log(_header);
        separator();
    }

    function test_enableDonation() public {
        address payee = tx.origin;
        vm.startPrank(payee); // Make all calls from here to vm.stopPrank() appear to have msg.sender value of payee

        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        println();
        header("Before enabling donation");
        payee = donationHook.donationPayee();
        console.log("msg.sender: %s", msg.sender);
        console.log("payee: %s", payee);
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);
        println();
        
        // First, check that the donation is not enabled
        assert(!enabled);
        assert(recipient == address(0));

        // Now, enable the donation, specifying that 10% 
        // always goes to the address specified in RECIPIENT
        uint enabledPercent = 10;
        donationHook.enableDonation(RECIPIENT, enabledPercent);

        // Now, verify that the recipent, the enabled status and percentage is correctly set
        recipient = donationHook.donationRecipient();
        enabled = donationHook.donationEnabled();
        uint fetchedPercent = donationHook.donationPercent();

        println();
        header("After enabling donation");
        payee = donationHook.donationPayee();
        console.log("msg.sender: %s", msg.sender);
        console.log("tx.origin: %s", tx.origin);
        console.log("payee: %s", payee);
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);

        assert(enabled);
        assert(recipient == RECIPIENT);
        assert(fetchedPercent == enabledPercent);
        vm.stopPrank();
    }

    function test_disableDonation() public {
        vm.startPrank(tx.origin);

        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        separator();
        println();
        console.log("test_disableDonation tx.origin %s", tx.origin);
        uint percent = 20;
        if (!enabled) {
            console.log("Donation not enabled!");
            console.log("Enabling donation");
            donationHook.enableDonation(RECIPIENT, percent);
        }

        enabled = donationHook.donationEnabled();
        recipient = donationHook.donationRecipient();
        assert(enabled);
        assert(recipient == RECIPIENT);

        donationHook.disableDonation();
        enabled = donationHook.donationEnabled();
        recipient = donationHook.donationRecipient();
        assert(!enabled);
        assert(recipient == address(0));
        console.log("224 Donation disabled successful!");

        vm.stopPrank();
    }

    function mint(address account, uint amount1, uint amount2) internal {
        MockERC20 t0 = MockERC20(Currency.unwrap(token0));
        MockERC20 t1 = MockERC20(Currency.unwrap(token1));
        t0.mint(account, amount1 * 1 ether);
        t1.mint(account, amount2 * 1 ether);
    }

    function test_Swap() public {
        // 
        vm.startPrank(tx.origin);

        MockERC20 t0 = MockERC20(Currency.unwrap(token0));
        MockERC20 t1 = MockERC20(Currency.unwrap(token1));

        mint(tx.origin, 1000, 1000);

        uint256 percent = 10;
        donationHook.enableDonation(RECIPIENT, percent);
        console.log("test_Swap2, 530 Donation enabled: %s", donationHook.donationEnabled(tx.origin));
        t0.approve(address(donationHook), t0.balanceOf(tx.origin));
        t1.approve(address(donationHook), t1.balanceOf(tx.origin));
        
        console.log("test_Swap2 537 approvals done");

        vm.stopPrank();

        // Setup the swap and do it
        PoolKey memory pool = globalKey;
        bool zeroForOne = true;
        int256 amountToSwap = 1 ether;
        bytes memory data = abi.encode(msg.sender);
        swap(pool, zeroForOne, amountToSwap, data);
    }

}
