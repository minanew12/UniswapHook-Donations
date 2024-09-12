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

contract DonationTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    AfterSwapDonationHook donationHook;

    // The two currencies (tokens) from the pool
    Currency token0;
    Currency token1;
    PoolKey globalKey;
    address constant RECIPIENT = address(0x01);
    address constant RECIPIENT2 = address(0x02);

    event HookAddress(address indexed hookAddress);

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();
        (token0, token1) = (currency0, currency1);

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        address hookAddress = address(flags);
        deployCodeTo("HookDonation.sol", abi.encode(manager, ""), hookAddress);
        emit HookAddress(hookAddress);
        donationHook = AfterSwapDonationHook(hookAddress);

        IHooks ihook = IHooks(address(donationHook));

        // Initialize a pool with these two tokens
        uint24 fee = 3000;
        (key,) = initPoolAndAddLiquidity(token0, token1, ihook, fee, SQRT_PRICE_1_1, ZERO_BYTES);

        globalKey = key;
    }

    function test_enableDonation() public {
        address payee = tx.origin;
        vm.startPrank(payee); // Make all calls from here to vm.stopPrank() appear to have msg.sender value of payee

        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        payee = donationHook.donationPayee();

        // First, check that the donation is not enabled
        assert(!enabled);
        assert(recipient == address(0));

        // Now, enable the donation, specifying that 10%
        // always goes to the address specified in RECIPIENT
        uint256 enabledPercent = 10;
        donationHook.enableDonation(RECIPIENT, enabledPercent);

        // Now, verify that the recipent, the enabled status, percentage and recipient is correctly set
        recipient = donationHook.donationRecipient();
        enabled = donationHook.donationEnabled();
        uint256 setPercent = donationHook.donationPercent();

        assert(enabled);
        assert(recipient == RECIPIENT);
        assert(setPercent == enabledPercent);
        vm.stopPrank();
    }

    function test_disableDonation() public {
        vm.startPrank(tx.origin);

        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        uint256 percent = 20;
        if (!enabled) {
            donationHook.enableDonation(RECIPIENT, percent);

            enabled = donationHook.donationEnabled();
            recipient = donationHook.donationRecipient();
            uint256 setPercent = donationHook.donationPercent();
            assert(enabled);
            assert(recipient == RECIPIENT);
            assert(setPercent == percent);
        }

        donationHook.disableDonation();
        enabled = donationHook.donationEnabled();
        recipient = donationHook.donationRecipient();
        assert(!enabled);
        assert(recipient == address(0));

        vm.stopPrank();
    }

    /// @param account The account to mint to
    /// @param amount1 The number of units to mint to, for key.currency0
    /// @param amount2 The amount of units to mint to, for key.currency1
    function mint(address account, uint256 amount1, uint256 amount2) internal {
        MockERC20 t0 = MockERC20(Currency.unwrap(token0));
        MockERC20 t1 = MockERC20(Currency.unwrap(token1));
        t0.mint(account, amount1 * 1 ether);
        t1.mint(account, amount2 * 1 ether);
    }

    function test_Swap() public {
        vm.startPrank(tx.origin);

        MockERC20 t0 = MockERC20(Currency.unwrap(token0));

        mint(tx.origin, 1000, 1000);

        uint256 percent = 10;
        // Workflow: The user will need to call enableDonation on the AfterSwapDonationHook contract
        donationHook.enableDonation(RECIPIENT, percent);

        // Approve the donationHook contract to spend on behalf of tx.origin, which is the user / EOA
        // This is essential, otherwise, in afterSwap, token.transferFrom will fail
        // Workflow: The user will need to call approve for token0 on their own.
        t0.approve(address(donationHook), type(uint256).max); 

        vm.stopPrank();

        // Setup the swap and do it
        PoolKey memory pool = globalKey;
        bool zeroForOne = true;
        int256 amountToSwap = 1 ether;
        bytes memory data = abi.encode(msg.sender);
        swap(pool, zeroForOne, amountToSwap, data);
    }
}
