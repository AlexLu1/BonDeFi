// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    address public immutable stableCoin;

    constructor(uint256 _tokenAmount,address _bondToken,address _stableCoin)
    ERC20("BonDeFiTokenInterest", "BDFI") {
        _mint(msg.sender, _tokenAmount * 10 ** decimals());
        require(IERC20(_bondToken).approve(_bondToken,_tokenAmount),"Could not authorize bond");
        stableCoin = _stableCoin;
    }

    function claimInterest(uint256 amountTokens) public{
        //execute transfer
        require(amountTokens > 0,"Can't claim zero coins");
        require(ERC20(this).transferFrom(msg.sender,address(this),amountTokens),"Interest token transfer failed");
        require(IERC20(stableCoin).transfer(msg.sender,amountTokens),"Stable coin transfer failed");
        //burn coins
        _burn(address(this),amountTokens);
    }

}
