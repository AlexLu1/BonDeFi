// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BonDeFiToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant BOND_ISSUER = keccak256("BOND_ISSUER");
    address public immutable stableCoin;
    address public immutable interestCoin;
    uint256 public immutable unitSize;
    uint256 public immutable maturityDate;
    constructor(address administrator, address bondIssuer, address _stableCoin,address _interestCoin,
    uint256 faceValue, uint256 _maturityDate, uint256 _unitSize) 
        ERC20("BonDeFiToken", "BDF")
    {
        _grantRole(ADMIN, administrator);
        _grantRole(BOND_ISSUER, bondIssuer);
        stableCoin = _stableCoin;
        interestCoin = _interestCoin;
        unitSize = _unitSize;
        maturityDate = _maturityDate;
        _mint(msg.sender, (faceValue / _unitSize) * 10 ** decimals());
    }

    function buyBond(uint256 amountTokens) public{
        require(IERC20(stableCoin).transferFrom(msg.sender,address(this),amountTokens*unitSize),"Stable coin transfer failed");
        require(ERC20(this).transfer(msg.sender,amountTokens),"Bond token transfer failed");
    }

    function distributeInterest(address tokenHolder,uint256 amount) public onlyRole(ADMIN){
        require(IERC20(interestCoin).transferFrom(interestCoin,tokenHolder,amount),"Transfer failed");
    }

    function distributeInterestAll(address[] memory tokenHolders, uint256[] memory amounts) public onlyRole(ADMIN) {
        require(tokenHolders.length == amounts.length, "Token holders and amounts length mismatch");
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            require(IERC20(interestCoin).transferFrom(msg.sender, tokenHolders[i], amounts[i]), "Transfer failed");
        }
    }

    function claimInvestorFunds() public onlyRole(BOND_ISSUER){
        uint256 amountInvestorCoins = IERC20(stableCoin).balanceOf(address(this));
        require(amountInvestorCoins > 0,"No investor funds available.");
        require(ERC20(this).transfer(msg.sender,amountInvestorCoins),"Failed to transfer stable coins");
    }

    function claimFaceValue(uint256 amountTokens) public{
        //check maturity
        require(block.timestamp >= maturityDate,"Maturity not yet reached");
        //execute transfer
        require(amountTokens > 0,"Can't claim zero coins");
        require(ERC20(this).transferFrom(msg.sender,address(this),amountTokens),"Bond token transfer failed");
        require(IERC20(stableCoin).transfer(msg.sender,amountTokens*unitSize),"Stable coin transfer failed");
        //burn coins
        _burn(address(this),amountTokens);
    }

    // The following functions are overrides required by Solidity.
    // Override required for pausable
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
        function pause() public onlyRole(ADMIN) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN) {
        _unpause();
    }
}
