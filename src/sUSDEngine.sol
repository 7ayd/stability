// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLib, AggregatorV3Interface} from "";
import {StabilityStableCoin} from "./Stability.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title sUSDEngine
 * @author this.7ayd
 *
 * This system maintains the properites of the sUSD token.
 * - Dollar Pegged
 * - Algorithmically Stable
 * - Overcollateralized
 *
 * @notice this handles all the logic for the Stability Stablecoin Ecosystem.
 */

contract sUSDEngine is ReentrancyGuard {
    //////// ERRORS ////////
    error MustsBeMoreThanZero();
    error CollateralNotSupported();
    error CollateralAddressesMustBeSameLengthAsPriceFeedAddresses();

    //////// STATE VARIABLES ////////
    mapping(address token => address priceFeed) public allowedCollat; // mapping of collateral to price feed
    mapping(address user => mapping(address token => uint256))
        public collateralBalances; // mapping of user to collateral to balance

    StabilityStableCoin private immutable stability; // the stability token

    ///////// MODIFIERS /////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert MustBeMoreThanZero();
        }
        _;
    }

    modifier collateralAllowed(address _collateral) {
        if (allowedCollat[_collateral] == address(0)) {
            revert CollateralNotSupported();
        }
        _;
    }

    ///////// CONSTRUCTOR /////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address stabilityAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert CollateralAddressesMustBeSameLengthAsPriceFeedAddresses();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            allowedCollat[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        stability = StabilityStableCoin(stabilityAddress);
    }

    ///////// Functions /////////
    function depositCollateralAndMint() external {}

    /*
     * @param _collateral The address of the collateral to deposit
     * @param _amount The amount of collateral to deposit
     */
    function deposit(
        address _collateral,
        uint256 _amount
    )
        external
        moreThanZero(_amount)
        collateralAllowed(_collateral)
        nonReentrant
    {}

    function redeemCollateral() external {}

    function redeemCollateralForStable() external {}

    function mintSUDC() external {}

    function burnSUSD() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
