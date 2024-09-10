// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.26;

// forge-std/=lib/v4-periphery/lib/v4-core/lib/forge-std/src/
import "lib/v4-periphery/lib/v4-core/lib/forge-std/src/Test.sol";
import "lib/v4-periphery/lib/v4-core/lib/forge-std/src/console.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "lib/v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import {Currency, CurrencyLibrary} from "lib/v4-core/src/types/Currency.sol";
// solmate/=lib/v4-core/lib/solmate/
import {MockERC20} from "lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";

contract DonationTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    struct DonationMapping {
        bool enabled;
        address payable recipient;
        uint256 percent; // how much to donate
    }
    mapping(address => DonationMapping) donationMap; 

    // address constant USDT_MOCK_ADDRESS = address(0xEce6af52f8eDF69dd2C216b9C3f184e5b31750e9); // mock address
    // address constant USDC_MOCK_ADDRESS = address(0x63ba29cAF4c40DaDA8a61D10AB5D2728c806b61f); // mock address

    AfterSwapDonationHook donationHook;
    // The two currencies (tokens) from the pool
    Currency token0;
    Currency token1;
    PoolKey globalKey;
    address constant RECIPIENT = address(0x01);

    event HookAddress(address indexed hookAddress);

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        (currency0, currency1) = Deployers.deployMintAndApprove2Currencies();
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

        // Approve our hook address to spend these tokens as well
        MockERC20(Currency.unwrap(token0)).approve(
            address(donationHook),
            type(uint256).max
        );
        MockERC20(Currency.unwrap(token1)).approve(
            address(donationHook),
            type(uint256).max
        );
        // Approve swapRouter to spend these tokens as well
        MockERC20(Currency.unwrap(token0)).approve(
            address(swapRouter),
            type(uint256).max
        );
        MockERC20(Currency.unwrap(token1)).approve(
            address(swapRouter),
            type(uint256).max
        );

        // Initialize a pool with these two tokens
        (key, ) = initPool(token0, token1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1, ZERO_BYTES);
        globalKey = key;
    }

    function donationEnabled(address payee) public view returns (bool) {
        return (donationMap[payee].recipient != payable(0x0));
    }

    function donationRecipient(address payee) public view returns (address) {
        return (donationMap[payee].recipient);
    }

    function enableDonation(address recipient, uint256 percent) public {
        DonationMapping memory local;
        local.recipient = payable(recipient);
        local.percent   = percent;

        donationMap[msg.sender] = local;
    }

    function test_internalEnableDonation() public {
        address payee = msg.sender;
        bool enabled = donationEnabled(payee);
        address recipient = donationRecipient(payee);
        console.log("Before enabling donation");
        console.log("--------------------------------------------------------------------------------");
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);
        console.log();
        assert(!enabled);

        enableDonation(RECIPIENT, 10); // recipient = 0x01, 10 percent
        console.log("After enabling donation");
        console.log("--------------------------------------------------------------------------------");
        enabled = donationEnabled(payee);
        recipient = donationRecipient(payee);
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);
        assert(enabled);

    }

    function test_enableDonation() public {
        address payee = msg.sender;
        bool enabled = donationHook.donationEnabled(payee);
        address recipient = donationHook.donationRecipient(payee);
        console.log("Before enabling donation");
        console.log("--------------------------------------------------------------------------------");
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);
        console.log();
        assert(!enabled);

        donationHook.enableDonation(RECIPIENT, 10); // recipient = 0x01, 10 percent
        console.log("After enabling donation");
        console.log("--------------------------------------------------------------------------------");
        enabled = donationHook.donationEnabled(payee);
        recipient = donationHook.donationRecipient(payee);
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);
        assert(enabled);
    }

    function test_Donation() public {
        bool zeroForOne = true;
        // PoolKey memory pool = PoolKey(
        //     token0, token1, 3000, 60, IHooks(address(donationHook))
        // );
        PoolKey memory pool = globalKey;
        bytes memory data = abi.encode(msg.sender);
        address recipient = address(0x01);
        console.log("Donation not enabled");
        console.log("Donation enabled for %s: %s", msg.sender, donationHook.donationEnabled(msg.sender));
        console.log("Donation recipient for %s: %s", msg.sender, donationHook.donationRecipient(msg.sender));

        console.log("Donation enabled: 10%%");
        donationHook.enableDonation(RECIPIENT, 10); // recipient = 0x01, 10 percent
        console.log("Test Donation sender: ", msg.sender);

        console.log("Donation enabled for %s: %s", msg.sender, donationHook.donationEnabled(msg.sender));
        console.log("Donation recipient for %s: %s", msg.sender, donationHook.donationRecipient(msg.sender));

        console.log("beforeSwap Balance token0: ", token0.balanceOf(msg.sender));
        console.log("beforeSwap Balance token1: ", token1.balanceOf(msg.sender));
        console.log();
        console.log("beforeSwap Balance token0: ", token0.balanceOf(recipient));
        console.log("beforeSwap Balance token1: ", token1.balanceOf(recipient));


        int256 amountSpecified = 10;
        Deployers.swap(pool, zeroForOne, amountSpecified, data);

        console.log(" afterSwap Balance token0: ", token0.balanceOf(msg.sender));
        console.log(" afterSwap Balance token1: ", token1.balanceOf(msg.sender));
        console.log(" afterSwap Balance token0: ", token0.balanceOf(recipient));
        console.log(" afterSwap Balance token1: ", token1.balanceOf(recipient));
    }

}
