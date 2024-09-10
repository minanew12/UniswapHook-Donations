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
import {HookMiner} from "./utils/HookMiner.sol";

contract DonationTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    mapping(address => AfterSwapDonationHook.DonationMapping) donationMap; 

    // address constant USDT_MOCK_ADDRESS = address(0xEce6af52f8eDF69dd2C216b9C3f184e5b31750e9); // mock address
    // address constant USDC_MOCK_ADDRESS = address(0x63ba29cAF4c40DaDA8a61D10AB5D2728c806b61f); // mock address

    AfterSwapDonationHook donationHook;
    
    // Mock token
    MockERC20 token;

    // The two currencies (tokens) from the pool
    Currency token0 = Currency.wrap(address(0));
    Currency token1;
    PoolKey globalKey;
    address constant RECIPIENT = address(0x01);
    address constant RECIPIENT2 = address(0x02);

    event HookAddress(address indexed hookAddress);

    // function setUp() public {
    //     deployFreshManagerAndRouters();
    //     (currency0, currency1) = deployMintAndApprove2Currencies();
    //     // (token0, token1) = (currency0, currency1);
    //     token1 = deployMintAndApproveCurrency();

    //     token = new MockERC20("Test Token", "TEST", 18);
    //     // Mint a bunch of TOKEN to ourselves and to address(1)
    //     token.mint(address(this), 1000 ether);
    //     token.mint(address(1), 1000 ether);

    //     token MockERC20(address(token0))

    //     // Deploy the hook to an address with the correct flags
    //     uint160 flags = uint160(
    //             Hooks.AFTER_SWAP_FLAG
    //     );

    //     address hookAddress = address(flags);
    //     deployCodeTo(
    //         "HookDonation.sol",
    //         abi.encode(manager, ""),
    //         hookAddress
    //     );
    //     emit HookAddress(hookAddress);
    //     donationHook = AfterSwapDonationHook(hookAddress);
    //     console.log("setUp Hook Address: ", hookAddress);
    //     console.log("donation Hook: ", address(donationHook));

    //     // Approve our hook address to spend these tokens as well
    //     MockERC20(Currency.unwrap(token0)).approve(
    //         address(donationHook),
    //         type(uint256).max
    //     );
    //     MockERC20(Currency.unwrap(token1)).approve(
    //         address(donationHook),
    //         type(uint256).max
    //     );

    //     // Initialize a pool with these two tokens
    //     (key, ) = initPool(token0, token1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1, ZERO_BYTES);
    //     globalKey = key;
    // }

    function setUp() public {
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
        // console.log("testValue: %s", donationHook.testValue);

        // Approve our hook address to spend these tokens as well
        MockERC20(Currency.unwrap(token0)).approve(
            address(donationHook),
            type(uint256).max
        );
        MockERC20(Currency.unwrap(token1)).approve(
            address(donationHook),
            type(uint256).max
        );
        MockERC20 m0 = MockERC20(Currency.unwrap(token0));
        MockERC20 m1 = MockERC20(Currency.unwrap(token1));
        console.log("setUp sender: %s", msg.sender);
        m0.mint(msg.sender, 100);
        m1.mint(msg.sender, 100);

        // Initialize a pool with these two tokens
        uint24 fee = 3000;
        (key, ) = initPool(token0, token1, IHooks(hookAddress), fee, SQRT_PRICE_1_1, ZERO_BYTES);
        globalKey = key;
    }

    function donationEnabled(address payee) public view returns (bool) {
        return (donationMap[payee].recipient != payable(0x0));
    }

    function donationRecipient(address payee) public view returns (address) {
        return (donationMap[payee].recipient);
    }

    function enableDonation(address recipient, uint256 percent) public {
        donationMap[msg.sender] = AfterSwapDonationHook.DonationMapping(payable(recipient), percent);
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
        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        // header("Before enabling donation");
        // console.log("payee: %s", payee);
        // console.log("enabled: %s", enabled);
        // console.log("recipient: %s", recipient);
        // console.log("testValue: %s", donationHook.testValue());
        // console.log();
        
        assert(!enabled);
        assert(recipient == address(0));

        uint enabledPercent = 10;
        donationHook.enableDonation(RECIPIENT, enabledPercent);

        recipient = donationHook.donationRecipient();
        enabled = donationHook.donationEnabled();
        uint fetchedPercent = donationHook.donationPercent();

        // println();
        // header("After enabling donation");
        // console.log("payee: %s", payee);
        // console.log("enabled: %s", enabled);
        // console.log("recipient: %s", recipient);
        // console.log("testValue: %s", donationHook.testValue());

        assert(enabled);
        assert(recipient == RECIPIENT);
        assert(fetchedPercent == enabledPercent);
    }

    function test_disableDonation() public {
        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        uint percent = 20;
        if (!enabled) {
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
    }

    function test_changeDonationSettings() public {
        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        // header("Before enabling donation");
        // console.log("payee: %s", payee);
        // console.log("enabled: %s", enabled);
        // console.log("recipient: %s", recipient);
        // console.log("testValue: %s", donationHook.testValue());
        // console.log();
        
        assert(!enabled);
        assert(recipient == address(0));

        uint enabledPercent = 10;
        donationHook.enableDonation(RECIPIENT, enabledPercent);

        recipient = donationHook.donationRecipient(); 
        enabled = donationHook.donationEnabled(); 
        uint fetchedPercent = donationHook.donationPercent();

        // println();
        // header("After enabling donation");
        // console.log("payee: %s", payee);
        // console.log("enabled: %s", enabled);
        // console.log("recipient: %s", recipient);
        // console.log("testValue: %s", donationHook.testValue());

        assert(enabled);
        assert(recipient == RECIPIENT);
        assert(fetchedPercent == enabledPercent);

        enabledPercent = 30;
        donationHook.enableDonation(RECIPIENT2, enabledPercent);

        recipient = donationHook.donationRecipient();
        enabled = donationHook.donationEnabled();
        fetchedPercent = donationHook.donationPercent();

        assert(enabled);
        assert(recipient == RECIPIENT2);
        assert(fetchedPercent == enabledPercent);
    }

    // function test_Donation() public {
    //     bool zeroForOne = true;
    //     // PoolKey memory pool = PoolKey(
    //     //     token0, token1, 3000, 60, IHooks(address(donationHook))
    //     // );
    //     PoolKey memory pool = globalKey;
    //     bytes memory data = abi.encode(msg.sender);
    //     address recipient = address(0x01);
    //     console.log("Donation not enabled");
    //     console.log("Donation enabled for %s: %s", msg.sender, donationHook.donationEnabled(msg.sender));
    //     console.log("Donation recipient for %s: %s", msg.sender, donationHook.donationRecipient(msg.sender));

    //     donationHook.enableDonation(RECIPIENT, 10); // recipient = 0x01, 10 percent
    //     console.log("Donation enabled: 10%%");
    //     console.log("Test Donation sender: ", msg.sender);

    //     console.log("Donation enabled for %s: %s", msg.sender, donationHook.donationEnabled(msg.sender));
    //     console.log("Donation recipient for %s: %s", msg.sender, donationHook.donationRecipient(msg.sender));

    //     console.log("beforeSwap Balance token0: ", token0.balanceOf(msg.sender));
    //     console.log("beforeSwap Balance token1: ", token1.balanceOf(msg.sender));
    //     console.log();
    //     console.log("beforeSwap Balance token0: ", token0.balanceOf(recipient));
    //     console.log("beforeSwap Balance token1: ", token1.balanceOf(recipient));

    //     int256 amountSpecified = 10;
    //     swap(pool, zeroForOne, amountSpecified, data);

    //     console.log(" afterSwap Balance token0: ", token0.balanceOf(msg.sender));
    //     console.log(" afterSwap Balance token1: ", token1.balanceOf(msg.sender));
    //     console.log(" afterSwap Balance token0: ", token0.balanceOf(recipient));
    //     console.log(" afterSwap Balance token1: ", token1.balanceOf(recipient));
    // }

}
