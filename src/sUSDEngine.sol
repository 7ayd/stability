// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

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

contract sUSDEngine {
    //////// ERRORS ////////
    error MustBeMoreThanZero();

    //////// STATE VARIABLES ////////
    mapping(address token => address priceFeed) public collateralAllowed; // mapping of collateral to price feed

    ///////// MODIFIERS /////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert MustBeMoreThanZero();
        }
        _;
    }

    modifier collateralAllowed(address _collateral) {
        require(
            collateralAllowed[_collateral] != address(0),
            "Collateral not allowed"
        );
        _;
    }

    ///////// CONSTRUCTOR /////////
    constructor() {}

    ///////// Functions /////////
    function depositCollateralAndMint() external {}

    /*
     * @param _collateral The address of the collateral to deposit
     * @param _amount The amount of collateral to deposit
     */
    function deposit(
        address _collateral,
        uint256 _amount
    ) external moreThanZero(_amount) {}

    function redeemCollateral() external {}

    function redeemCollateralForStable() external {}

    function mintsUDC() external {}

    function burnsUSD() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
