// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "contracts/BonDeFiInterestToken.sol";


contract BonDeFiToken is ERC20, ERC20Pausable, AccessControl {
    
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant BOND_ISSUER = keccak256("BOND_ISSUER");
    address public immutable stableCoin;
    uint256 public immutable maturityDate;
    address public immutable interestToken;
    uint256 internal investorFundsAmount;

    constructor(address administrator, address bondIssuer, address _stableCoin,
    uint256 _faceValue, uint256 _maturityDate, uint256 _totalInterest)
        ERC20("BonDeFiToken", "BDF")
    {
        _grantRole(ADMIN, administrator);
        _grantRole(BOND_ISSUER, bondIssuer);
        stableCoin = _stableCoin;
        maturityDate = _maturityDate;
        investorFundsAmount = 0;
        _mint(address(this), _faceValue);
        //Create interest token
        BonDeFiInterestToken newInterestToken = new BonDeFiInterestToken(address(this),_totalInterest,"BonDeFiTokenInterest","BDFI");
        interestToken = address(newInterestToken);
    }
    function buyBond(uint256 amountTokens) public{
        investorFundsAmount += amountTokens;
        require(ERC20(this).balanceOf(address(this)) - amountTokens >= 0);
        require(IERC20(stableCoin).transferFrom(msg.sender,address(this),amountTokens),"Stable coin transfer failed");
        require(ERC20(this).transfer(msg.sender,amountTokens),"Bond token transfer failed");
    }

    function depositPayment(uint256 amountTokens) public{
        require(IERC20(stableCoin).transferFrom(msg.sender,address(this),amountTokens),"Stable coin deposit failed.");
    }

    function distributeInterest(address tokenHolder,uint256 amount) public onlyRole(ADMIN){
        require(IERC20(interestToken).transfer(tokenHolder,amount),"Transfer failed");
    }

    function distributeInterestAll(address[] memory tokenHolders, uint256[] memory amounts) public onlyRole(ADMIN) {
        require(tokenHolders.length == amounts.length, "Token holders and amounts length mismatch");
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            require(IERC20(interestToken).transfer(tokenHolders[i], amounts[i]), "Transfer failed");
        }
    }
    
    function claimInvestorFunds() public onlyRole(BOND_ISSUER){
        require(investorFundsAmount > 0,"No investor funds available.");
        require(IERC20(stableCoin).transfer(msg.sender,investorFundsAmount),"Failed to transfer stable coins");
    }

    function claimInterest(uint256 amountTokens) public{
        //execute transfer
        require(amountTokens > 0,"Can't claim zero coins");
        require(IERC20(interestToken).transferFrom(msg.sender,address(this),amountTokens),"Interest token transfer failed");
        require(IERC20(stableCoin).transfer(msg.sender,amountTokens),"Stable coin transfer failed");
        //burn coins
        ERC20Burnable(interestToken).burn(amountTokens);
    }

    function claimFaceValue(uint256 amountTokens) public{
        //check maturity
        require(block.timestamp >= maturityDate,"Maturity not yet reached");
        //execute transfer
        require(amountTokens > 0,"Can't claim zero coins");
        require(ERC20(this).transferFrom(msg.sender,address(this),amountTokens),"Bond token transfer failed");
        require(IERC20(stableCoin).transfer(msg.sender,amountTokens),"Stable coin transfer failed");
        //burn coins
        _burn(address(this),amountTokens);
    }
    //for demonstration only
    function showBondTokens() public view returns (uint256) {
        return ERC20(this).balanceOf(msg.sender);
    }
    function showInterestTokens() public view returns (uint256){
        return IERC20(interestToken).balanceOf(msg.sender);
    }
    function showStableCoins() public view returns (uint256){
        return IERC20(stableCoin).balanceOf(msg.sender);
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
