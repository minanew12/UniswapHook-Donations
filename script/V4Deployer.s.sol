// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
// import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
// import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/src/test/PoolDonateTest.sol";
import {PoolTakeTest} from "@uniswap/v4-core/src/test/PoolTakeTest.sol";
import {PoolClaimsTest} from "@uniswap/v4-core/src/test/PoolClaimsTest.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {AfterSwapDonationHook} from "../src/HookDonation.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {console} from "@uniswap/v4-core/lib/forge-std/src/console.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Constants} from "lib/v4-core/test/utils/Constants.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
// K:\Development\Ethereum\UniswapHook-Donations\lib\v4-periphery\lib\v4-core\src\types\PoolId.sol
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
// K:\Development\Ethereum\UniswapHook-Donations\lib\v4-periphery\lib\v4-core\src\libraries\LPFeeLibrary.sol
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

contract V4Deployer is Script {
    using LPFeeLibrary for uint24;
    Currency internal currency0;
    Currency internal currency1;

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    IPoolManager.ModifyLiquidityParams public LIQUIDITY_PARAMS =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: 0});

    AfterSwapDonationHook public donationHook;

    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;
    IPoolManager _manager;
    PoolModifyLiquidityTest modifyLiquidityRouter;

    function run() public payable {
        vm.startBroadcast();

        // https://discord.com/channels/1202009457014349844/1283886646604988437
        PoolManager manager = PoolManager(address(0xCa6DBBe730e31fDaACaA096821199EEED5AD84aE));
        IPoolManager iManager = IPoolManager(address(0xCa6DBBe730e31fDaACaA096821199EEED5AD84aE));
        modifyLiquidityRouter = PoolModifyLiquidityTest(address(0x1f03f235e371202e49194F63C7096F5697848822));
        PoolSwapTest swapRouter = PoolSwapTest(address(0xEc9537B6D66c14E872365AB0EAE50dF7b254D4Fc));

        // Mint mock ERC20s or initialize a pool
        // Do it directly here as well without using Deployers
        // Define tokens and pool parameters
        MockERC20 token0 = new MockERC20("Wrapped Ether", "WETH", 18);
        MockERC20 token1 = new MockERC20("Tether", "USDT", 6);

        address wallet = 0x0080614a1B5821340C73c5A0455e55CF20b1a164;
        token0.mint(wallet, 1001 ether);

        uint256 MAX_TOKENS = 2 ** 255;
        token0.mint(address(this), MAX_TOKENS);
        token1.mint(address(this), MAX_TOKENS);

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        uint24 fee = 3000; // Fee in basis points, ie, 0.30%
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER, flags, type(AfterSwapDonationHook).creationCode, abi.encode(address(iManager))
        );
        console.log("Hook Address: %s", hookAddress);
        donationHook = new AfterSwapDonationHook{salt: salt}(iManager);
        console.log("AfterSwapDonationHook address: %s", address(donationHook));
        console.log("Token0: %s", address(token0));
        console.log("Token1: %s", address(token1));

        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token0.approve(address(manager), type(uint256).max);

        token1.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);

        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);

        // Create PoolKey
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: fee,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        // IPoolManager.ModifyLiquidityParams memory LIQUIDITY_PARAMS =
        //   IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: 0});

        // initPoolAndAddLiquidity
        manager.initialize(key, Constants.SQRT_PRICE_1_1, "");
        console.log("Initialize successful");
        uint256 balance;
        balance = token0.balanceOf(wallet);
        console.log("Wallet balance: %s", balance);
        modifyLiquidityRouter.modifyLiquidity{value: msg.value}(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        // initPoolAndAddLiquidity(
        //   Currency.wrap(address(token0)), Currency.wrap(address(token1)), IHooks(hookAddress),
        //   fee, Constants.SQRT_PRICE_1_1, Constants.ZERO_BYTES
        // );

        vm.stopBroadcast();
    }

    // function initPool(
    //     Currency _currency0,
    //     Currency _currency1,
    //     IHooks hooks,
    //     uint24 fee,
    //     uint160 sqrtPriceX96,
    //     bytes memory initData
    // ) internal returns (PoolKey memory _key, PoolId id) {
    //     _key = PoolKey(_currency0, _currency1, fee, fee.isDynamicFee() ? int24(60) : int24(fee / 100 * 2), hooks);
    //     id = _key.toId();
    //     _manager.initialize(_key, sqrtPriceX96, initData);
    // }

    // function initPool(
    //     Currency _currency0,
    //     Currency _currency1,
    //     IHooks hooks,
    //     uint24 fee,
    //     int24 tickSpacing,
    //     uint160 sqrtPriceX96,
    //     bytes memory initData
    // ) internal returns (PoolKey memory _key, PoolId id) {
    //     _key = PoolKey(_currency0, _currency1, fee, tickSpacing, hooks);
    //     id = _key.toId();
    //     _manager.initialize(_key, sqrtPriceX96, initData);
    // }

    // function initPoolAndAddLiquidity(
    //     Currency _currency0,
    //     Currency _currency1,
    //     IHooks hooks,
    //     uint24 fee,
    //     uint160 sqrtPriceX96,
    //     bytes memory initData
    // ) internal returns (PoolKey memory _key, PoolId id) {
    //     (_key, id) = initPool(_currency0, _currency1, hooks, fee, sqrtPriceX96, initData);
    //     modifyLiquidityRouter.modifyLiquidity{value: msg.value}(_key, LIQUIDITY_PARAMS, ZERO_BYTES);
    // }

    // function deployMintAndApprove2Currencies() internal returns (Currency, Currency) {
    //     Currency _currencyA = deployMintAndApproveCurrency();
    //     Currency _currencyB = deployMintAndApproveCurrency();

    //     (currency0, currency1) =
    //         SortTokens.sort(MockERC20(Currency.unwrap(_currencyA)), MockERC20(Currency.unwrap(_currencyB)));
    //     return (currency0, currency1);
    // }

    // function deployMintAndApproveCurrency() internal returns (Currency currency) {
    //     MockERC20 token = deployTokens(1, 2 ** 255)[0];

    //     address[9] memory toApprove = [
    //         address(swapRouter),
    //         address(swapRouterNoChecks),
    //         address(modifyLiquidityRouter),
    //         address(modifyLiquidityNoChecks),
    //         address(donateRouter),
    //         address(takeRouter),
    //         address(claimsRouter),
    //         address(nestedActionRouter.executor()),
    //         address(actionsRouter)
    //     ];

    //     for (uint256 i = 0; i < toApprove.length; i++) {
    //         token.approve(toApprove[i], Constants.MAX_UINT256);
    //     }

    //     return Currency.wrap(address(token));
    // }
}
