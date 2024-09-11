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
import {EOA} from "./EOA.sol";

contract DonationTest is Test, Deployers //, ISwap 
{
    using CurrencyLibrary for Currency;

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
        vm.startPrank(payee);

        bool enabled = donationHook.donationEnabled();
        address recipient = donationHook.donationRecipient();

        println();
        header("Before enabling donation");
        payee = donationHook.donationPayee();
        console.log("msg.sender: %s", msg.sender);
        console.log("payee: %s", payee);
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);
        // console.log("testValue: %s", donationHook.testValue());
        println();
        
        assert(!enabled);
        assert(recipient == address(0));

        uint enabledPercent = 10;
        // (bool success, bytes memory data) = address(donationHook).delegatecall(
        //     abi.encodeWithSignature("enableDonation(address, uint)", RECIPIENT, enabledPercent)
        // );
        donationHook.enableDonation(RECIPIENT, enabledPercent);

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
        // disableDonation(RECIPIENT, 20);
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

    function enableDonation(EOA account, address _recipient, uint _percent) internal {
        address payee = msg.sender;
        bool enabled = account.donationEnabled();
        address recipient = account.donationRecipient();
        address msgSender = account.donationPayee();
        header("Before enabling donation");
        console.log("msg.sender: %s", msgSender);
        console.log("payee: %s", payee);
        console.log("enabled: %s", enabled);
        println();
        
        assert(!enabled);
        assert(recipient == address(0));

        uint enabledPercent = _percent;
        account.enableDonation(_recipient, enabledPercent);

        recipient = account.donationRecipient();
        enabled = account.donationEnabled();
        uint fetchedPercent = account.donationPercent();

        println();
        header("After enabling donation");
        console.log("msg.sender: %s", msg.sender);
        console.log("payee: %s", payee);
        console.log("enabled: %s", enabled);
        console.log("recipient: %s", recipient);

        assert(enabled);
        assert(recipient == _recipient);
        assert(fetchedPercent == enabledPercent);
    }

    function mint(address account, uint amount1, uint amount2) internal {
        MockERC20 t0 = MockERC20(Currency.unwrap(token0));
        MockERC20 t1 = MockERC20(Currency.unwrap(token1));
        t0.mint(account, amount1 * 1 ether);
        t1.mint(account, amount2 * 1 ether);
    }

    function approve(EOA _account, MockERC20 _token, address _spender, uint _amount) internal returns (uint approvedAmount) {
        _account.approveSpending(address(_token), _spender, _amount);
        approvedAmount = _token.allowance(address(_account), _spender);
    }

    function approveAndShowAllowance(address _token, address _spender, address _owner, uint amount) internal {
        vm.startPrank(_owner);
        MockERC20 myToken = MockERC20(_token);
        myToken.approve(_spender, amount);
        uint approvedAllowance = myToken.allowance(tx.origin, _spender);
        console.log("Approved allowance owner: %s spender: %s, amount: %s", tx.origin, _spender, approvedAllowance);
        vm.stopPrank();
    }

    function approveAddressSpendingOnBehalfOf(address spender, address _owner) internal {
        console.log("504 approveAddressSpendingOnBehalfOf, before startPrank: msg.sender: %s", msg.sender);
        console.log("506 Spender: %s, Owner: %s", spender, _owner);

        MockERC20 t0 = MockERC20(Currency.unwrap(token0));
        MockERC20 t1 = MockERC20(Currency.unwrap(token1));
        approveAndShowAllowance(address(t0), spender, _owner, type(uint).max);
        approveAndShowAllowance(address(t1), spender, _owner, type(uint).max);
        
        console.log("approveAddressSpendingOnBehalfOf, after stopPrank: msg.sender: %s", msg.sender);
    }
    function approveManagerSpendingOnBehalfOf(address _owner) internal {
        console.log("approveManagerSpendingOnBehalfOf, before startPrank: msg.sender: %s", msg.sender);
        approveAddressSpendingOnBehalfOf(address(manager), _owner);
        console.log("approveManagerSpendingOnBehalfOf, after stopPrank: msg.sender: %s", msg.sender);
    }

    function test_Swap2() public {
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

        PoolKey memory pool = globalKey;
        bool zeroForOne = true;
        int256 amountToSwap = 1 ether;
        bytes memory data = abi.encode(msg.sender);
        console.log("Calling swap...");
        console.log("546 swapRouter address: %s", address(swapRouter));
        swap(pool, zeroForOne, amountToSwap, data);
        console.log("Back from swap...");
        uint afterSwapBalance = t0.balanceOf(RECIPIENT);
    }

}
