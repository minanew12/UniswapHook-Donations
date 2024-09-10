// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseHook} from "lib/v4-periphery/src/base/hooks/BaseHook.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";

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
    uint public testValue; 

// -------------- begin donation associated functions ---------------
    function disableDonation() public {
        // Reset the value to the default value.
        delete donationMap[msg.sender];
    }

    function enableDonation(address recipient, uint256 percent) public {
        console.log("enableDonation msg.sender: %s", msg.sender);
        console.log("enableDonation recipient: %s", recipient);
        console.log("enableDonation percent: %s", percent);

        // DonationMapping memory local = DonationMapping(payable(recipient), percent);
        // local.recipient = payable(recipient);
        // local.percent   = percent;
        // donationMap[msg.sender] = local;

        donationMap[msg.sender] = DonationMapping(payable(recipient), percent);
        // DonationMapping memory local = donationMap[msg.sender];
        // console.log("after enableDonation msg.sender: %s", msg.sender);
        // console.log("after enableDonation recipient: %s", local.recipient);
        // console.log("after enableDonation percent: %s", local.percent);

        // donationMap[msg.sender].recipient = payable(recipient);
        // donationMap[msg.sender].percent = percent;

        testValue++;
    }

    // function donationDetails() public view returns (DonationMapping memory) {
    //     return donationMap[msg.sender];
    // }

    // the following should all have internal view, not public
    // but have been changed to public view for testing

    function donationEnabled() public view returns (bool) {
        return (donationMap[msg.sender].recipient != payable(0x0));
    }

    function donationPercent() public view returns (uint256) {
        return (donationMap[msg.sender].percent);
    }

    function donationRecipient() public view returns (address) {
        return (donationMap[msg.sender].recipient);
    }
// -------------- end donation associated functions ---------------

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        owner = msg.sender;
        testValue = 1; // for testing
    }

    // Modifier to restrict access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /// @notice The hook called after a swap
    /// @param ...sender The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param swapParams The parameters for the swap
    /// @param delta The amount owed to the caller (positive) or owed to the pool (negative)
    /// @param ...Arbitrary data handed into the PoolManager by the swapper to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return int128 The hook's delta in unspecified currency. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterSwap(
        address, // sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        require(msg.sender == address(pool), "Unauthorized caller");
        
        // Check that donation is enabled for the sender
        if (!donationEnabled())
            return (this.afterSwap.selector, 0);
        
        uint256 spendAmount = swapParams.amountSpecified < 0
            ? uint256(-swapParams.amountSpecified)
            : uint256(int256(-delta.amount0()));

        uint256 donationAmount = (spendAmount * donationPercent()) / 100;
        address recipient = donationRecipient();

        key.currency0.transfer(recipient, donationAmount);

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
