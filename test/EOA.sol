// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.26;

import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {SwapRouterNoChecks} from "lib/v4-core/src/test/SwapRouterNoChecks.sol";
import {Deployers} from "lib/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {ERC20} from "lib/v4-core/lib/solmate/src/tokens/ERC20.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import {PoolSwapTest} from "lib/v4-core/src/test/PoolSwapTest.sol";
import {Constants} from "lib/v4-core/test/utils/Constants.sol";

// This is a contract that pretends to be an end-user
contract EOA {

    IPoolManager manager;
    SwapRouterNoChecks swapRouter;
    Deployers deployers;
    PoolKey pool;
    AfterSwapDonationHook donationHook;

    constructor(IPoolManager _manager, SwapRouterNoChecks _swapRouter, Deployers _deployers, PoolKey memory _pool,
      AfterSwapDonationHook _donationHook
    ) {
        manager = _manager;
        swapRouter = _swapRouter;
        deployers = _deployers;
        pool = _pool;
        donationHook = _donationHook;
    }

    function approveSpending(address token, address spender, uint amount) public returns (bool, address) {
        bool approved = ERC20(token).approve(spender, amount);
        return (approved, spender);
    }

    function swap(int256 amountSpecified) public payable {
        // IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
        //     zeroForOne: true,
        //     amountSpecified: -int256(amountToSwap),
        //     sqrtPriceLimitX96: SQRT_PRICE_1_2
        // });
        // bytes memory hookData = abi.encode(msg.sender);
       PoolKey memory _key = pool;

       swapRouter.swap{value: msg.value}(
            _key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(amountSpecified),
                sqrtPriceLimitX96: Constants.SQRT_PRICE_1_1
            })
        );
        // swapRouter.swap(key, params);
    }

    function swap(PoolKey memory _key, bool zeroForOne, int256 amountSpecified, bytes memory hookData) public {
        // deployers.swap(_key, zeroForOne, amountSpecified, hookData);
    }

    function disableDonation() public {
        // Reset the value to the default value.
        donationHook.disableDonation();
    }

    function enableDonation(address recipient, uint256 percent) public {
        donationHook.enableDonation(recipient, percent);
    }

    // the following should all have internal view, not public
    // but have been changed to public view for testing

    function donationEnabled() public view returns (bool) {
        return donationHook.donationEnabled();
    }

    function donationPercent() public view returns (uint256) {
        return donationHook.donationPercent();
    }

    function donationRecipient() public view returns (address) {
        return donationHook.donationRecipient();
    }

    function donationPayee() public view returns (address) {
        return donationHook.donationPayee();
    }

}