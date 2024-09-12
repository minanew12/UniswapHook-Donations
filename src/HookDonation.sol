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

contract AfterSwapDonationHook is BaseHook {
    using CurrencyLibrary for Currency;

    struct DonationMapping {
        address payable recipient;
        uint256 percent; // how much to donate
    }

    address public owner;
    mapping(address => DonationMapping) donationMap;

    event Donation(address indexed payee, address indexed recipient, uint256 donatedAmount);

    // -------------- begin donation associated functions ---------------
    /// Disables donation for msg.sender
    function disableDonation() public {
        // Reset the value to the default value.
        delete donationMap[msg.sender];
    }

    /// Enables donation to the specified recipient, with the given percentage
    function enableDonation(address recipient, uint256 percent) public {
        donationMap[tx.origin] = DonationMapping(payable(recipient), percent);
    }

    function donationEnabled(address addr) public view returns (bool) {
        bool result = donationMap[addr].recipient != payable(0x0);
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
        return donationPercent(msg.sender);
    }

    function donationRecipient(address addr) public view returns (address) {
        return donationMap[addr].recipient;
    }

    function donationRecipient() public view returns (address) {
        return donationRecipient(msg.sender);
    }

    // -------------- end donation associated functions ---------------

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        owner = msg.sender;
    }

    /// @notice The hook called after a swap
    /// @param ...manager The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param swapParams The parameters for the swap
    /// @param delta The amount owed to the caller (positive) or owed to the pool (negative)
    /// @param ... userdata handed into the PoolManager by the swapper to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return int128 The hook's delta in unspecified currency. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata // userdata
    ) external override returns (bytes4, int128) {
        // Check that donation is enabled for the tx.origin, otherwise, return early
        if (!donationEnabled(tx.origin)) {
            return (this.afterSwap.selector, 0);
        }

        // calculate the amount to donate away.
        // The donation amount is always the first currency.
        uint256 spendAmount =
            swapParams.amountSpecified < 0 ? uint256(-swapParams.amountSpecified) : uint256(int256(-delta.amount0()));
        uint256 percent = donationPercent(tx.origin);
        uint256 donationAmount = (spendAmount * percent) / 100;
        address recipient = donationRecipient(tx.origin);

        IERC20Minimal token = IERC20Minimal(Currency.unwrap(key.currency0));
        uint256 allowance = token.allowance(tx.origin, address(this));
        assert(allowance >= donationAmount); // check that we're allowed to spend on behalf of tx.origin

        // Track the balance before the transfer
        uint256 balanceOriginBefore = token.balanceOf(tx.origin);
        uint256 balanceRecipientBefore = token.balanceOf(recipient);

        token.transferFrom(tx.origin, recipient, donationAmount);
        emit Donation(tx.origin, recipient, donationAmount);

        // Track the balance after the transfer
        uint256 balanceOriginAfter = token.balanceOf(tx.origin);
        uint256 balanceRecipientAfter = token.balanceOf(recipient);

        assert((balanceOriginBefore - donationAmount) == balanceOriginAfter);
        assert(balanceRecipientAfter == (balanceRecipientBefore + donationAmount));

        return (this.afterSwap.selector, 0);
    }

    // Only for other apps. Uniswap doesn't call this.
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
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
