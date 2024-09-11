// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseHook} from "lib/v4-periphery/src/base/hooks/BaseHook.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import {ERC20} from "lib/v4-core/lib/solmate/src/tokens/ERC20.sol";
import {IERC20Minimal} from "lib/v4-core/src/interfaces/external/IERC20Minimal.sol";

// For checking expected values
import "lib/v4-periphery/lib/v4-core/lib/forge-std/src/console.sol";

contract AfterSwapDonationHook is BaseHook {
    using CurrencyLibrary for Currency;

    struct DonationMapping {
        address payable recipient;
        uint256 percent; // how much to donate
    }

    address public owner;
    address public pool;
    mapping(address => DonationMapping) donationMap;

    function boolToStr(bool value) internal pure returns (string memory) {
        return value ? "true": "false";
    }
    
// -------------- begin donation associated functions ---------------
    function disableDonation() public {
        // Reset the value to the default value.
        console.log("function disableDonation()");
        console.log("disableDonation msg.sender: %s", msg.sender);
        delete donationMap[msg.sender];
    }

    function enableDonation(address recipient, uint256 percent) public {
        console.log("enableDonation tx.origin: %s", tx.origin);
        console.log("enableDonation msg.sender: %s", msg.sender);
        console.log("enableDonation recipient: %s", recipient);
        console.log("enableDonation percent: %s", percent);

        // DonationMapping memory local = DonationMapping(payable(recipient), percent);
        // local.recipient = payable(recipient);
        // local.percent   = percent;
        // donationMap[msg.sender] = local;

        // console.log("enableDonation function");
        // console.log("Enabling donation for msg.sender %s to recipient %s", msg.sender, recipient);
        // donationMap[msg.sender] = DonationMapping(payable(recipient), percent);
        console.log("enableDonation(address recipient, uint256 percent)");
        donationMap[tx.origin] = DonationMapping(payable(recipient), percent);

        // DonationMapping memory local = donationMap[msg.sender];
        // console.log("after enableDonation msg.sender: %s", msg.sender);
        // console.log("after enableDonation recipient: %s", local.recipient);
        // console.log("after enableDonation percent: %s", local.percent);

        // donationMap[msg.sender].recipient = payable(recipient);
        // donationMap[msg.sender].percent = percent;
    }

    // function enableDonation(address recipient, uint256 percent, address token0, address token1) public {
    //     enableDonation(recipient, percent);
    //     approveSpending(token0);
    //     approveSpending(token1);
    // }

    // the following should all have internal view, not public
    // but have been changed to public view for testing

    function donationEnabled(address addr) public view returns (bool) {
        bool result = donationMap[addr].recipient != payable(0x0);
        console.log("donation enabled: %s for %s", boolToStr(result), msg.sender);
        return result;
    }

    function donationEnabled() public view returns (bool) {
        bool result = donationEnabled(msg.sender);
        return result;
    }

    function donationPayee() public view returns (address) {
        return msg.sender;
    }

    function donationPercent(address addr) public view returns (uint256) {
        return donationMap[addr].percent;
    }
    function donationPercent() public view returns (uint256) {
        return donationPercent(msg.sender); // donationMap[msg.sender].percent;
    }

    function donationRecipient(address addr) public view returns (address) {
        return donationMap[addr].recipient;
    }
    function donationRecipient() public view returns (address) {
        return donationRecipient(msg.sender); // donationMap[msg.sender].recipient;
    }

// -------------- end donation associated functions ---------------

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        owner = msg.sender;
        console.log("Owner: %s", owner);
        console.log("Pool manager: %s", address(poolManager));
        // testValue = 1; // for testing
    }

    // Modifier to restrict access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /// @notice The hook called after a swap
    /// @param ...manager The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param swapParams The parameters for the swap
    /// @param delta The amount owed to the caller (positive) or owed to the pool (negative)
    /// @param userdata handed into the PoolManager by the swapper to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return int128 The hook's delta in unspecified currency. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata userdata
    ) external override returns (bytes4, int128) {
        // require(msg.sender == address(pool), "Unauthorized caller");
        // msg.sender is the manager's address

        console.log("afterSwap tx.origin %s", tx.origin);
        console.log("afterSwap parameter sender: %s", sender);
        console.log("afterSwap msg.sender: %s", msg.sender);
        console.log("afterSwap this: %s", address(this));

        // Check that donation is enabled for the sender
        if (!donationEnabled(tx.origin)) {
            console.log("147 Donation not enabled for %s!", tx.origin);
            return (this.afterSwap.selector, 0);
        } else {
            console.log("150 Donation enabled for %s", tx.origin);
        }

        uint256 spendAmount = swapParams.amountSpecified < 0
            ? uint256(-swapParams.amountSpecified)
            : uint256(int256(-delta.amount0()));
        uint256 percent = donationPercent(tx.origin);
        uint256 donationAmount = (spendAmount * percent) / 100;
        console.log("158 Donation percent: %s", percent);
        console.log("   spendAmount: %s", spendAmount);
        console.log("donationAmount: %s", donationAmount);
        address recipient = donationRecipient(tx.origin);
        console.log("recipient: %s", recipient);

        console.log("Transferring now");
        console.log("msg.sender: %s, tx.origin: %s", msg.sender, tx.origin);
        IERC20Minimal token = IERC20Minimal(Currency.unwrap(key.currency0));
        console.log("Balance Of %s is %s", tx.origin, token.balanceOf(tx.origin));
        uint allowance = token.allowance(tx.origin, msg.sender);
        // msg.sender here is manager
        console.log("167 Allowance owner: %s spender: %s, allowance: %s", tx.origin, msg.sender, allowance);
        uint balanceOriginBefore = token.balanceOf(tx.origin);
        uint balanceRecipientBefore = token.balanceOf(recipient);
        console.log("170 tx.origin balance before: %s, recipient balance before: %s", balanceOriginBefore, balanceRecipientBefore);
        
        token.transferFrom(tx.origin, recipient, donationAmount);
        uint balanceOriginAfter = token.balanceOf(tx.origin);
        uint balanceRecipientAfter = token.balanceOf(recipient);

        assert(balanceRecipientAfter == (balanceRecipientBefore + donationAmount));

        console.log("177 tx.origin balance after: %s, recipient balance after: %s", balanceOriginAfter, balanceRecipientAfter);
        console.log("Transfer succeeded");

        return (this.afterSwap.selector, 0);
    }

    // Function to update the pool address if needed
    function updatePool(address _newPool) external onlyOwner {
        pool = _newPool;
    }

    // Only for other apps. Uniswap doesn't call this.
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

}
