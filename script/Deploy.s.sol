// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Stability} from "../src/Stability.sol";
import {USDEngine} from "../src/USDEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract Deploy is Script {
    address[] public collateralTokens;
    address[] public priceFeeds;

    function run() external returns (Stability, USDEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (
            address wethUSDPriceFeed,
            address wbtcUSDPriceFeed,
            address linkUSDPriceFeed,
            address eth,
            address btc,
            address link,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        collateralTokens = [eth, btc, link];
        priceFeeds = [wethUSDPriceFeed, wbtcUSDPriceFeed, linkUSDPriceFeed];

        vm.startBroadcast(deployerKey);
        Stability stability = new Stability();
        USDEngine usdEngine = new USDEngine(collateralTokens,priceFeeds, address(stability));
        stability.transferOwnership(address(usdEngine));

        vm.stopBroadcast();

        return (stability, usdEngine, config);
    }
}
