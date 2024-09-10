// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract BonDeFiInterestToken is ERC20,ERC20Burnable{

    constructor(address _bondToken,uint256 _tokenAmount,string memory _name,string memory _symbol)
    ERC20(_name, _symbol) {
        _mint(_bondToken, _tokenAmount);
    }

}
