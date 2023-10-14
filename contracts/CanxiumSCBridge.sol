// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./lib/Pausable.sol";

contract CanxiumSCBridge is AccessControl, Pausable {
    // max hot balance %
    uint public maxHotBalancePercent = 30;
    // max eth or token can be accessed by hot wallet
    mapping(address => uint) private hotBalances;

    // history of release eth/token
    mapping(bytes32 => bool) private released;
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // user events
    event TransferToken(address indexed token, address indexed receiver, uint indexed amount);

    // operator event
    event ReleaseToken(address indexed token, address indexed receiver, uint indexed amout);

    constructor(address owner, address operator) payable {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(OPERATOR_ROLE, operator);
    }

    // #### PUBLIC FUNC #### //
    
    // transfer eth/erc20 token to other chain
    function transfer(address token, address receiver, uint amount) public payable whenNotPaused() {
        require(receiver != address(0), "invalid receiver address");
        uint balance = address(this).balance;
        // transfer eth
        if (token == address(0)) {
            require(msg.value > 0, "you have to deposit a positive amount");
            amount = msg.value;
        } else {
            require(msg.value == 0, "deposit native coin for this token transfer is not allowed");
            IERC20 iToken = IERC20(token);
            require(iToken.transferFrom(msg.sender, address(this), amount), "insufficient allowance token balance");
            balance = iToken.balanceOf(address(this));
        }

        uint maxBalance = balance * maxHotBalancePercent / 100;
        // increase hot balance if it not reach x% of total balance of contract
        hotBalances[token] = hotBalances[token] + amount;
        if (hotBalances[token] > maxBalance) {
            hotBalances[token] = maxBalance;
        }

        emit TransferToken(token, receiver, amount);
    }

    // return hot balance of a token
    function hotBalance(address token) public view returns (uint) {
        return hotBalances[token];
    }

    // is this tx hash have been released coin/token
    function isReleased(bytes32 txHash) public view returns (bool) {
        return released[txHash];
    }

    // #### OPERATOR FUNC #### //

    // release ETH/ERC20
    function release(bytes32 txHash, address token, address receiver, uint amount) public onlyRole(OPERATOR_ROLE) whenNotPaused() {
        require(released[txHash] == false, "Already release for this transaction hash");
        require(hotBalances[token] >= amount, "Insufficient hot balance");
        if (token == address(0)) {
            payable(receiver).transfer(amount);
        } else {
            IERC20 iToken = IERC20(token);
            iToken.transfer(receiver, amount);
        }

        released[txHash] = true;
        hotBalances[token] = hotBalances[token] - amount;
        emit ReleaseToken(token, receiver, amount);
    }

    // #### OWNER FUNC #### //

    // approve more balance for hot wallet, for ethereum side
    function approve(address token, uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = address(this).balance;
        if (token != address(0)) {
            IERC20 iToken = IERC20(token);
            balance = iToken.balanceOf(address(this));
        }

        require(amount <= balance, "Insufficient aprroved amout");
        hotBalances[token] = amount;
    }

    function setMaxHotBalance(uint percent) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maxHotBalancePercent = percent;
    }

    function withdraw(address token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        }

        IERC20 iToken = IERC20(token);
        iToken.transfer(msg.sender, iToken.balanceOf(address(this)));
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
