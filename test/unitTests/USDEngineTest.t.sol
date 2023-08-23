// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {Stability} from "../../src/Stability.sol";
import {USDEngine} from "../../src/USDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract USDEngineTest is Test {
    Deploy deployer;
    Stability stability;
    USDEngine usdEngine;
    HelperConfig config;
    address ethUSDPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL = 10 ether;
    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new Deploy();
        (stability, usdEngine, config) = deployer.run();
        (ethUSDPriceFeed,,, weth,,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(address(USER), STARTING_BALANCE);
    }

    function testGetUSDValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedAmount = 30000e18;

        uint256 actualUSD = usdEngine._getPrice(weth, ethAmount);
        assertEq(actualUSD, expectedAmount);
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(usdEngine), COLLATERAL);

        vm.expectRevert(usdEngine.MustBeMoreThanZero.selector);
        usdEngine.deposit(weth, 0);
        vm.stopPrank();
    }
}
