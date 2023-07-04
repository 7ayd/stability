// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Stability is ERC20Burnable, Ownable {
    error MustBeMoreThanZero();
    error InsufficientBalance();
    error ZeroAddress();

    constructor() ERC20("Stability", "sUSD") {}

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert ZeroAddress();
        }
        if (_amount <= 0) {
            revert MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert InsufficientBalance();
        }
        super.burn(_amount);
    }
}
