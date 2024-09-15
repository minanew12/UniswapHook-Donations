// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolDonateTest} from "v4-core/test/PoolDonateTest.sol";
import {PoolTakeTest} from "v4-core/test/PoolTakeTest.sol";
import {PoolClaimsTest} from "v4-core/test/PoolClaimsTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import "forge-std/console.sol";
import "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
// import "forge-std/console.sol";

contract SwapHelper {
    PoolManager manager = PoolManager(0xCa6DBBe730e31fDaACaA096821199EEED5AD84aE);
    PoolSwapTest swapRouter = PoolSwapTest(0xEc9537B6D66c14E872365AB0EAE50dF7b254D4Fc);
    PoolModifyLiquidityTest modifyLiquidityRouter = PoolModifyLiquidityTest(0x1f03f235e371202e49194F63C7096F5697848822);

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    Currency token0;
    Currency token1;

    PoolKey key;

    constructor(MockERC20 tokenA, MockERC20 tokenB, address hook) {
        if (address(tokenA) > address(tokenB)) {
            (token0, token1) = (Currency.wrap(address(tokenB)), Currency.wrap(address(tokenA)));
        } else {
            (token0, token1) = (Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)));
        }

        tokenA.approve(address(modifyLiquidityRouter), type(uint256).max);
        tokenB.approve(address(modifyLiquidityRouter), type(uint256).max);
        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);
        tokenA.approve(hook, type(uint256).max);
        tokenB.approve(hook, type(uint256).max);

        tokenA.mint(msg.sender, 100 * 10 ** 18);
        tokenB.mint(msg.sender, 100 * 10 ** 18);
        tokenA.mint(address(this), 100 * 10 ** 18);
        tokenB.mint(address(this), 100 * 10 ** 18);

        key = PoolKey({currency0: token0, currency1: token1, fee: 3000, tickSpacing: 120, hooks: IHooks(address(hook))});
    }

    function Swap(bool zeroForOne, int256 amountToSwap) public {
        // uint256 percent = 10;
        // // Workflow: The user will need to call enableDonation on the AfterSwapDonationHook contract
        // donationHook.enableDonation(RECIPIENT, percent);

        // Approve the donationHook contract to spend on behalf of tx.origin, which is the user / EOA
        // This is essential, otherwise, in afterSwap, token.transferFrom will fail
        // Workflow: The user will need to call approve for token0 on their own.
        // t0.approve(address(donationHook), type(uint256).max);

        // Setup the swap and do it
        PoolKey memory pool = key;
        // bool zeroForOne = true;
        // int256 amountToSwap = 1 ether;
        bytes memory data = abi.encode(msg.sender);
        swap(pool, zeroForOne, amountToSwap, data);
    }

    /// @notice Helper function for a simple ERC20 swaps that allows for unlimited price impact
    function swap(PoolKey memory _key, bool zeroForOne, int256 amountSpecified, bytes memory hookData)
        internal
        returns (BalanceDelta)
    {
        // allow native input for exact-input, guide users to the `swapNativeInput` function
        bool isNativeInput = zeroForOne && _key.currency0.isAddressZero();
        if (isNativeInput) require(0 > amountSpecified, "Use swapNativeInput() for native-token exact-output swaps");

        uint256 value = isNativeInput ? uint256(-amountSpecified) : 0;

        return swapRouter.swap{value: value}(
            _key,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            hookData
        );
    }
}
