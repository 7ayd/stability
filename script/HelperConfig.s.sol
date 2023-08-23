// SPDX-Lisences-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address linkUSDPriceFeed;
        address eth;
        address btc;
        address link;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 30000e8;
    int256 public constant LINK_USD_PRICE = 10e8;
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // This is a fake private key for a local network

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUSDPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            linkUSDPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            eth: 0xc778417E063141139Fce010982780140Aa0cD5Ab,
            btc: 0xc778417E063141139Fce010982780140Aa0cD5Ab,
            link: 0xc778417E063141139Fce010982780140Aa0cD5Ab,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUSDPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("Wrapped Ether", "WETH",msg.sender, 1000e8);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("Wrapped Bitcoin", "WBTC",msg.sender, 1000e8);

        MockV3Aggregator linkUsdPriceFeed = new MockV3Aggregator(DECIMALS, LINK_USD_PRICE);
        ERC20Mock wlinkMock = new ERC20Mock("Chainlink", "LINK",msg.sender, 1000e8);

        vm.stopBroadcast();

        return NetworkConfig({
            wethUSDPriceFeed: address(ethUsdPriceFeed),
            wbtcUSDPriceFeed: address(btcUsdPriceFeed),
            linkUSDPriceFeed: address(linkUsdPriceFeed),
            eth: address(wethMock),
            btc: address(wbtcMock),
            link: address(wlinkMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
