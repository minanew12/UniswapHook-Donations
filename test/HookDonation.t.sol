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
import {MockERC20} from "lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol"; // ...
// K:\Development\Ethereum\UniswapHook-Donations\lib\v4-core\lib\forge-std\src\mocks\MockERC20.sol
// import {MockERC20} from "lib/v4-core/lib/forge-std/src/mocks/MockERC20.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {PoolSwapTest} from "lib/v4-core/src/test/PoolSwapTest.sol";
import {BaseHook} from "lib/v4-periphery/src/base/hooks/BaseHook.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {EOA} from "./EOA.sol";

contract DonationTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    // mapping(address => AfterSwapDonationHook.DonationMapping) donationMap; 

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

    function boolToStr(bool value) internal pure returns (string memory) {
        return value ? "true": "false";
    }

    function beforeTestSetup(
        bytes4 // testSelector
    ) public view returns (bytes[] memory ) { // beforeTestCalldata
        // if (testSelector == this.testC.selector) {
        //     beforeTestCalldata = new bytes[](2);
        //     beforeTestCalldata[0] = abi.encodePacked(this.testA.selector);
        //     beforeTestCalldata[1] = abi.encodeWithSignature("setB(uint256)", 1);
        // }
        console.log("beforeTestSetup msg.sender: %s, tx.origin: %s, this: %s", msg.sender, tx.origin, address(this));
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
        // console.log("testValue: %s", donationHook.testValue);

        // // Approve our hook address to spend these tokens as well
        // MockERC20(Currency.unwrap(token0)).approve(
        //     address(donationHook),
        //     type(uint256).max
        // );
        // MockERC20(Currency.unwrap(token1)).approve(
        //     address(donationHook),
        //     type(uint256).max
        // );
        // uint256 allowance0 = MockERC20(Currency.unwrap(token0)).allowance(address(this), address(donationHook));
        // console.log("Allowance owner: %s, spender: %s, allowance: %s", address(this), address(donationHook), allowance0);

        // MockERC20 t0 = MockERC20(Currency.unwrap(token0));
        // MockERC20 t1 = MockERC20(Currency.unwrap(token1));
        console.log("setUp sender: %s", msg.sender);

        // address mint_to = address(this);
        // t0.mint(mint_to, 100 ether); // this is successful
        // uint balance = t0.balanceOf(mint_to);
        // // Balance Of: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 is 100000000000000000000
        // console.log("102 Balance Of: %s is %s", mint_to, balance);
        // t1.mint(mint_to, 100 ether);
        
        // address mint_to_origin = address(tx.origin);
        // t0.mint(mint_to_origin, 100 ether); // this is successful
        // balance = t0.balanceOf(mint_to_origin);
        // // Balance Of: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 is 100000000000000000000
        // console.log("109 t0 Balance Of: %s is %s", mint_to_origin, balance);
        // t1.mint(mint_to_origin, 100 ether);
        // balance = t1.balanceOf(mint_to_origin);
        // // Balance Of: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 is 100000000000000000000
        // console.log("113 t1 Balance Of: %s is %s", mint_to_origin, balance);

        // // approves spending by poolManager for token0 / token1, so that afterSwap can transfer
        // // afterSwap's msg.sender is the manager, so approve it to spend on behalf
        // t0.approve(address(manager), type(uint256).max);
        // t1.approve(address(manager), type(uint256).max);

        // uint allowance = t0.allowance(address(this), address(manager));
        // console.log("121 Allowance owner: %s, spender: %s, allowance: %s", address(this), address(manager), allowance);

        // // approves spending by poolManager for token0 / token1, so that afterSwap can transfer
        // (bool approved1, address spender1) = donationHook.approveSpending(address(Currency.unwrap(token0)));
        // uint allowance1 = t0.allowance(address(this), address(spender1));
        // console.log("Approved: %s", boolToStr(approved1));
        // console.log("127 Allowance owner: %s, spender: %s, allowance: %s", address(this), spender1, allowance1);

        // (bool approved2, address spender2) = donationHook.approveSpending(address(Currency.unwrap(token1)));
        // uint allowance2 = t0.allowance(msg.sender, spender2);
        // console.log("Approved: %s", boolToStr(approved2));
        // console.log("132 Allowance owner: %s, spender: %s, allowance: %s", address(this), spender2, allowance2);

        IHooks ihook = IHooks(address(donationHook));

        // Initialize a pool with these two tokens
        uint24 fee = 3000;
        (key, ) = initPoolAndAddLiquidity(token0, token1, ihook, fee, SQRT_PRICE_1_1, ZERO_BYTES);
        
        globalKey = key;
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

    // function test_enableDonation() public {
    //     address payee = msg.sender;
    //     bool enabled = donationHook.donationEnabled();
    //     address recipient = donationHook.donationRecipient();

    //     header("Before enabling donation");
    //     console.log("msg.sender: %s", msg.sender);
    //     console.log("payee: %s", payee);
    //     console.log("enabled: %s", enabled);
    //     console.log("recipient: %s", recipient);
    //     // console.log("testValue: %s", donationHook.testValue());
    //     println();
        
    //     assert(!enabled);
    //     assert(recipient == address(0));

    //     uint enabledPercent = 10;
    //     // (bool success, bytes memory data) = address(donationHook).delegatecall(
    //     //     abi.encodeWithSignature("enableDonation(address, uint)", RECIPIENT, enabledPercent)
    //     // );
    //     donationHook.enableDonation(RECIPIENT, enabledPercent);

    //     recipient = donationHook.donationRecipient();
    //     enabled = donationHook.donationEnabled();
    //     uint fetchedPercent = donationHook.donationPercent();

    //     println();
    //     header("After enabling donation");
    //     console.log("msg.sender: %s", msg.sender);
    //     console.log("tx.origin: %s", tx.origin);
    //     console.log("payee: %s", payee);
    //     console.log("enabled: %s", enabled);
    //     console.log("recipient: %s", recipient);

    //     assert(enabled);
    //     assert(recipient == RECIPIENT);
    //     assert(fetchedPercent == enabledPercent);
    // }

    // // function disableDonation(address addrRecipient, uint givenPercent) internal {
    // //     bool enabled = donationHook.donationEnabled(msg.sender);
    // //     address recipient = donationHook.donationRecipient(msg.sender);

    // //     uint percent = givenPercent;
    // //     if (!enabled) {
    // //         console.log("Donation not enabled!");
    // //         console.log("Enabling donation");
    // //         donationHook.enableDonation(addrRecipient, percent);
    // //     }

    // //     enabled = donationHook.donationEnabled(msg.sender);
    // //     recipient = donationHook.donationRecipient(msg.sender);
    // //     assert(enabled);
    // //     assert(recipient == addrRecipient);

    // //     donationHook.disableDonation(msg.sender);
    // //     enabled = donationHook.donationEnabled(msg.sender);
    // //     recipient = donationHook.donationRecipient(msg.sender);
    // //     assert(!enabled);
    // //     assert(recipient == address(0));
    // // }

    // function test_disableDonation() public {
    //     // disableDonation(RECIPIENT, 20);
    //     bool enabled = donationHook.donationEnabled();
    //     address recipient = donationHook.donationRecipient();

    //     console.log("test_disableDonation tx.origin %s", tx.origin);
    //     uint percent = 20;
    //     if (!enabled) {
    //         console.log("Donation not enabled!");
    //         console.log("Enabling donation");
    //         donationHook.enableDonation(RECIPIENT, percent);
    //     }

    //     enabled = donationHook.donationEnabled();
    //     recipient = donationHook.donationRecipient();
    //     assert(enabled);
    //     assert(recipient == RECIPIENT);

    //     donationHook.disableDonation();
    //     enabled = donationHook.donationEnabled();
    //     recipient = donationHook.donationRecipient();
    //     assert(!enabled);
    //     assert(recipient == address(0));
    // }

    // function test_changeDonationSettings() public {
    //     bool enabled = donationHook.donationEnabled();
    //     address recipient = donationHook.donationRecipient();

    //     // header("Before enabling donation");
    //     // console.log("payee: %s", payee);
    //     // console.log("enabled: %s", enabled);
    //     // console.log("recipient: %s", recipient);
    //     // console.log("testValue: %s", donationHook.testValue());
    //     // console.log();
        
    //     assert(!enabled);
    //     assert(recipient == address(0));

    //     uint enabledPercent = 10;
    //     donationHook.enableDonation(RECIPIENT, enabledPercent);

    //     recipient = donationHook.donationRecipient(); 
    //     enabled = donationHook.donationEnabled(); 
    //     uint fetchedPercent = donationHook.donationPercent();

    //     // println();
    //     // header("After enabling donation");
    //     // console.log("payee: %s", payee);
    //     // console.log("enabled: %s", enabled);
    //     // console.log("recipient: %s", recipient);
    //     // console.log("testValue: %s", donationHook.testValue());

    //     assert(enabled);
    //     assert(recipient == RECIPIENT);
    //     assert(fetchedPercent == enabledPercent);

    //     enabledPercent = 30;
    //     donationHook.enableDonation(RECIPIENT2, enabledPercent);

    //     recipient = donationHook.donationRecipient();
    //     enabled = donationHook.donationEnabled();
    //     fetchedPercent = donationHook.donationPercent();

    //     assert(enabled);
    //     assert(recipient == RECIPIENT2);
    //     assert(fetchedPercent == enabledPercent);
    // }

    // function test_transferFrom() public {
    // }

    function test_Donation() public {
        // bool zeroForOne = true;
        // PoolKey memory pool = PoolKey(
        //     token0, token1, 3000, 60, IHooks(address(donationHook))
        // );
        // PoolKey memory pool = globalKey;
        // bytes memory data = abi.encode(msg.sender);

        address recipient = address(0x01);

        console.log("test_Donation caller / msg.sender: %s", msg.sender);

        donationHook.enableDonation(RECIPIENT, 10); // recipient = 0x01, 10 percent
        header("beforeSwap");
        console.log("Address: %s, Balance token0: %s", msg.sender, token0.balanceOf(msg.sender));
        console.log("Address: %s, Balance token1: %s", msg.sender, token1.balanceOf(msg.sender));
        println();
        console.log("Address: %s, Balance token0: %s", recipient, token0.balanceOf(recipient));
        console.log("Address: %s, Balance token1: %s", recipient, token1.balanceOf(recipient));

        // console.log("swapRouter address: %s", address(swapRouter));
        // console.log("swapRouterNoChecks address: %s", address(swapRouterNoChecks));
        // console.log("modifyLiquidityRouter address: %s", address(modifyLiquidityRouter));
        // console.log("modifyLiquidityNoChecks address: %s", address(modifyLiquidityNoChecks));
        // console.log("donateRouter address: %s", address(donateRouter));
        // console.log("takeRouter address: %s", address(takeRouter));
        // console.log("claimsRouter address: %s", address(claimsRouter));
        // console.log("nestedActionRouter address: %s", address(nestedActionRouter));
        // console.log("feeController address: %s", address(feeController));
        // console.log("revertingFeeController address: %s", address(revertingFeeController));
        // console.log("outOfBoundsFeeController address: %s", address(outOfBoundsFeeController));
        // console.log("overflowFeeController address: %s", address(overflowFeeController));
        // console.log("invalidReturnSizeFeeController address: %s", address(invalidReturnSizeFeeController));
        // console.log("actionsRouter address: %s", address(actionsRouter));
        console.log("manager address: %s", address(manager));

        // swap method 1
        // int256 amountToSwap = 10;
        // PoolSwapTest.TestSettings memory testSettings =
        //     PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        // IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
        //     zeroForOne: true,
        //     amountSpecified: -int256(amountToSwap),
        //     sqrtPriceLimitX96: SQRT_PRICE_1_2
        // });
        // swapRouter.swap(pool, SWAP_PARAMS, testSettings, ZERO_BYTES);

        // donationHook.approveSpending(Currency.unwrap(token0));
        // donationHook.approveSpending(Currency.unwrap(token1));
        // swap Method 2
        PoolKey memory pool = globalKey;
        bool zeroForOne = true;
        int256 amountToSwap = 1 ether;
        bytes memory data = abi.encode(msg.sender);
        console.log("Calling swap...");
        console.log("swapRouter address: %s", address(swapRouter));
        swap(pool, zeroForOne, amountToSwap, data);
        console.log("Back from swap...");

        println();
        header(" afterSwap");
        console.log("Address: %s, Balance token0: %s", msg.sender, token0.balanceOf(msg.sender));
        console.log("Address: %s, Balance token1: %s", msg.sender, token1.balanceOf(msg.sender));
        println();
        console.log("Address: %s, Balance token0: %s", recipient, token0.balanceOf(recipient));
        console.log("Address: %s, Balance token1: %s", recipient, token1.balanceOf(recipient));
    }

    // function test_EnableDonation2() public {
    //     // IPoolManager _manager, SwapRouterNoChecks _swapRouter, Deployers _deployers, PoolKey memory _pool
    //     PoolKey memory pool = globalKey;
    //     EOA account1 = new EOA(manager, swapRouterNoChecks, this, pool, donationHook);

    //     address payee = account1.donationPayee();
    //     address recipient = account1.donationRecipient();
    //     bool enabled = account1.donationEnabled();
    //     header("Before enabling donation");
    //     console.log("payee: %s", payee);
    //     console.log("enabled: %s", enabled);
    //     console.log("recipient: %s", recipient);
    //     println();

    //     uint percent = 10;       
    //     account1.enableDonation(RECIPIENT, percent);
    //     header(" After enabling donation");
    //     payee = account1.donationPayee();
    //     recipient = account1.donationRecipient();
    //     enabled = account1.donationEnabled();
    //     uint fetchedPercent = account1.donationPercent();
    //     console.log("payee: %s", payee);
    //     console.log("enabled: %s", enabled);
    //     console.log("recipient: %s", recipient);
    //     console.log("percent: %s", fetchedPercent);
    //     println();
    // }

    function disableDonation(EOA account) public {
        bool enabled = account.donationEnabled();
        address recipient = account.donationRecipient();
        address payee = account.donationPayee();

        console.log("test_disableDonation msg.sender %s", payee);
        uint percent = 20;
        if (!enabled) {
            console.log("Donation not enabled!");
            console.log("Enabling donation");
            account.enableDonation(RECIPIENT, percent);
        }

        enabled = account.donationEnabled();
        recipient = account.donationRecipient();
        assert(enabled);
        assert(recipient == RECIPIENT);

        account.disableDonation();
        enabled = account.donationEnabled();
        recipient = account.donationRecipient();
        assert(!enabled);
        assert(recipient == address(0));
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
        console.log("recipient: %s", recipient);
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

    function test_DisableDonation() public {
        PoolKey memory pool = globalKey;
        EOA account1 = new EOA(manager, swapRouterNoChecks, this, pool, donationHook);
        EOA account2 = new EOA(manager, swapRouterNoChecks, this, pool, donationHook);

        disableDonation(account1);
        disableDonation(account2);
    }

    function test_enableDonation() public {
        PoolKey memory pool = globalKey;
        EOA account1 = new EOA(manager, swapRouterNoChecks, this, pool, donationHook);
        EOA account2 = new EOA(manager, swapRouterNoChecks, this, pool, donationHook);

        uint percent = 10;
        enableDonation(account1, RECIPIENT, percent);
        
        percent = 20;
        enableDonation(account2, RECIPIENT2, percent);
    }
}
