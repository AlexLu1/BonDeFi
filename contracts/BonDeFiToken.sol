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
    uint256 public immutable totalInterest;
    uint256 public immutable interestFrequency;
    address public immutable interestToken;
    uint256 internal investorFundsAmount;
    uint256 public interestPaymentsLeft;
    //logic for keeping track of holders internally
    mapping(address => uint256) private balances;
    address[] private currentHolders;
    mapping(address => bool) private isHolder;

    constructor(address administrator, address bondIssuer, address _stableCoin,
    uint256 _faceValue, uint256 _maturityDate, uint256 _totalInterest, uint256 _interestFrequency)
        ERC20("BonDeFiToken", "BDF")
    {
        _grantRole(ADMIN, administrator);
        _grantRole(BOND_ISSUER, bondIssuer);
        stableCoin = _stableCoin;
        maturityDate = _maturityDate;
        totalInterest = _totalInterest;
        interestFrequency = _interestFrequency;
        interestPaymentsLeft = _interestFrequency;
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
    function distributeInterest() public onlyRole(ADMIN) onlyRole(BOND_ISSUER){
        require(interestPaymentsLeft>0, "All interest payments already done.");
        interestPaymentsLeft -= 1;
        //distribute interest token instead of stable coin if there isnt enough deposit
        if(balanceOf(address(this)) < totalInterest/interestFrequency){
            require(_distribution(interestToken),"Distribution of interest coin failed.");
            return;
        }
        require(_distribution(stableCoin),"Distribution of stable coin failed.");
    }
    
    //distribute the specified token to every current token holder
    function _distribution(address erc20token) private returns (bool){
        for (uint256 i = 0; i < currentHolders.length; i++) {
            address holder = currentHolders[i];
            uint256 amountInterest = balances[holder] * (totalInterest/interestFrequency);
            if(!IERC20(erc20token).transfer(holder,amountInterest)){
                return false;
            }
        }
        return true;
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
    //overrides for internal tracking logic
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        require(super.transfer(recipient, amount), "Transfer failed.");
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        require(super.transferFrom(sender, recipient, amount), "Transfer failed.");
        return true;
    }

    //updates helper variables for internal tracking
    function _updateHolders(address sender, address recipient) private {
        //check if sender still has tokens
        if(balances[sender] <= 0){
            isHolder[sender] = false;
            _removeHolder(sender);
        }
        //check if recipient is already tracked
        if(!isHolder[recipient]){
            isHolder[recipient] = true;
            currentHolders.push(recipient);
        }
    }

    //remove holder from holder list
    function _removeHolder(address holder) private{
        //swap with last element and remove last element
        for (uint256 i = 0; i < currentHolders.length; i++) {
            if (currentHolders[i] == holder) {
                currentHolders[i] = currentHolders[currentHolders.length - 1];
                currentHolders.pop();
                break;
            }
        }
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
