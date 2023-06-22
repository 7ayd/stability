// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "{ERC20Burnable.sol, ERC20.sol}" from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "{Ownable.sol}" from "@openzeppelin/contracts/access/Ownable.sol";

contract Stability is ERC20Burnable, Ownable {
    constructor() ERC20("Stability", "USDS"){}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if()
    }

}
