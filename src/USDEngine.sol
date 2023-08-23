// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Stability} from "./Stability.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contract/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title sUSDEngine
 * @author this.7ayd
 *
 * This system maintains the properites of the sUSD token.
 * - Dollar Pegged
 * - Algorithmically Stable
 * - Overcollateralized
 *
 * @notice this handles all the logic for the Stability Stablecoin Ecosystem. Burning, Minting, Collateralization, Liquidation, and Health Factor.
 */

contract USDEngine is ReentrancyGuard {
    //////// ERRORS ////////
    error MustBeMoreThanZero();
    error CollateralNotSupported();
    error CollateralAddressesMustBeSameLengthAsPriceFeedAddresses();
    error DepositFailed();
    error HealthFactorTooLow();
    error MintFailed();
    error TransferFailed();
    error HealthFactorOK();
    error HealthFactorNotImproved();

    //////// STATE VARIABLES ////////
    uint256 private constant PRICE_FEED_DECIMALS_ADJUSTMENT = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MINIMUM_HEALH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; //10%
    uint256 private constant LIQUIDATION_PRECISION = 100;

    mapping(address token => address priceFeed) public priceFeeds; // mapping of collaterals to prices feeds
    mapping(address user => mapping(address token => uint256)) public collateralBalances; // mapping of user to collateral to balance
    mapping(address user => uint256 stableAmount) public stableBalances; // mapping of user to stablecoin balance
    address[] private collateralTokens; // array of collateral tokens
    Stability private immutable stability; // the stability token

    //////// EVENTS ////////
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed collateral, uint256 amount
    );

    ///////// MODIFIERS /////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert MustBeMoreThanZero();
        }
        _;
    }

    modifier collateralAllowed(address _collateral) {
        if (priceFeeds[_collateral] == address(0)) {
            revert CollateralNotSupported();
        }
        _;
    }

    ///////// CONSTRUCTOR /////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address stabilityAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert CollateralAddressesMustBeSameLengthAsPriceFeedAddresses();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            collateralTokens.push(tokenAddresses[i]);
        }
        stability = Stability(stabilityAddress);
    }

    ///////// Functions /////////

    /*
     * @param _collateral The address of the collateral to deposit
     * @param _amount The amount of collateral to deposit
     * @param _amountToMint The amount of stablecoin to mint
     * @notice this function will deposit collateral and mint in 1 transaction
     */
    function depositCollateralAndMint(address _collateral, uint256 _amount, uint256 _amountToMint) external {
        deposit(_collateral, _amount);
        mintUSD(_amountToMint);
    }

    /*
     * @param _collateral The address of the collateral to deposit
     * @param _amount The amount of collateral to deposit
     */
    function deposit(address _collateral, uint256 _amount)
        public
        moreThanZero(_amount)
        collateralAllowed(_collateral)
        nonReentrant
    {
        collateralBalances[msg.sender][_collateral] += _amount;
        emit CollateralDeposited(msg.sender, _collateral, _amount);
        bool success = IERC20(_collateral).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert DepositFailed();
        }
    }
    /*
     * @param _tokenCollateralAddress The address of the collateral to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @notice will check to ensure health factor is above 1
     * @notice will revert if the user does not have enough collateral
     */

    function redeemCollateral(address _tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, _tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBelowOne(msg.sender);
    }
    /*
    * @param _tokenCollatoralAddress The address of the collateral to redeem
    * @param _amountCollateral The amount of collateral to redeem
    * @param _amountToBurn The amount of stablecoin to burn
    * @notice this function will redeem collateral and burn stablecoin in 1 transaction
    */

    function redeemCollateralForStable(
        address _tokenCollatoralAddress,
        uint256 _amountCollateral,
        uint256 _amountToBurn
    ) external {
        burnUSD(_amountToBurn);
        redeemCollateral(_tokenCollatoralAddress, _amountCollateral);
    }

    /*
     * @param _amountToMint The amount of stablecoin to mint
     * @notice must have approriate collateral deposited
     */
    function mintUSD(uint256 _amountToMint) public moreThanZero(_amountToMint) nonReentrant {
        stableBalances[msg.sender] += _amountToMint;
        _revertIfHealthFactorIsBelowOne(msg.sender);
        bool minted = stability.mint(msg.sender, _amountToMint);
        if (!minted) {
            revert MintFailed();
        }
    }
    /*
     * @param _amount The amount of stablecoin to burn
     * @notice must have the correct amount of stablecoin and new solidity will do safemath
     */

    function burnUSD(uint256 _ammount) public moreThanZero(_ammount) {
        _burnStable(_ammount, msg.sender, msg.sender);
    }

    /*
    * @param _collateral The address of the collateral to liquidate
    * @param _user The address of the user to liquidate. Must have a health factor below 1 to liquidate. 
    * @param _debtToCover The amount of stablecoin to cover
    * @notice you can partially liquidate a user and get a bonus for liquidating them
    */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _getHealthFactor(user);
        if (startingHealthFactor >= MINIMUM_HEALH_FACTOR) {
            revert HealthFactorOK();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountUSD(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);

        //burn stable
        _burnStable(debtToCover, user, msg.sender);

        uint256 endingHealthFactor = _getHealthFactor(user);
        if (endingHealthFactor <= startingHealthFactor) {
            revert HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBelowOne(msg.sender);
    }

    function getHealthFactor() external view {}

    ///////// _Interal Functions /////////

    function _getAccountInformation(address _user) private view returns (uint256 stableMinted, uint256 valueInUSD) {
        stableMinted = stableBalances[_user];
        valueInUSD = getUserCollgetUserCollateralValueInUSD(_user);
        return (stableMinted, valueInUSD);
    }
    /*
     * @notice returns the health factor for a user
     * @param _user The address of the user
     * @return the health factor for the user
     */

    function _getHealthFactor(address _user) private view returns (uint256) {
        (uint256 stableMinted, uint256 valueInUSD) = _getAccountInformation(_user);
        uint256 adjustedCollateral = (valueInUSD * LIQUIDATION_THRESHOLD) / 100;
        return (adjustedCollateral * PRECISION) / stableMinted;
    }

    function _revertIfHealthFactorIsBelowOne(address _user) internal view {
        uint256 healthFactor = _getHealthFactor(_user);
        if (healthFactor < MINIMUM_HEALH_FACTOR) {
            revert HealthFactorTooLow();
        }
    }

    function _redeemCollateral(address _from, address _to, address _tokenCollateral, uint256 _amount) private {
        collateralBalances[_from][_tokenCollateral] -= _amount;
        emit CollateralRedeemed(_from, _to, _tokenCollateral, _amount);
        bool success = IERC20(_tokenCollateral).transfer(_to, _amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    function _burnStable(uint256 _amountToBurn, address burnFrom, address burnTo) private {
        stableBalances[burnFrom] -= _amountToBurn;
        bool success = stability.transferFrom(burnFrom, burnTo, _amountToBurn);
        if (!success) {
            revert TransferFailed();
        }
        stability.burn(_amountToBurn);
    }
    /////// Public View Functions /////////

    function getTokenAmountUSD(address _token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((usdAmountInWei * PRECISION) / uint256(price) * PRICE_FEED_DECIMALS_ADJUSTMENT);
    }

    function getUserCollgetUserCollateralValueInUSD(address _user) public view returns (uint256 valueInUSD) {
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 balance = collateralBalances[_user][token];
            uint256 price = _getPrice(token, balance);
            valueInUSD += balance * price;
        }
        return valueInUSD;
    }

    function _getPrice(address token, uint256 ammount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * PRICE_FEED_DECIMALS_ADJUSTMENT) * ammount) / PRECISION;
    }
}
