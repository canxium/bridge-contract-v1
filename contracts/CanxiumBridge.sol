// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./lib/Pausable.sol";
import "./lib/ISignatureTransfer.sol";

contract CanxiumBridge is AccessControl, Pausable {
    // max hot balance %
    uint private maxHotBalancePercent = 30;

    // max cau or token can be accessed by hot wallet
    mapping(address => uint) private hotBalances;

    // history of release cau/token
    mapping(bytes32 => bool) private released;

    // permit2 interface
    ISignatureTransfer private permit2;
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // user events
    event TransferToken(address token, address receiver, uint amount, uint32 chainId);

    // operator event
    event ReleaseToken(address indexed token, address indexed receiver, uint indexed amout);

    constructor(address owner, address operator, address permit) payable {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(OPERATOR_ROLE, operator);
        permit2 = ISignatureTransfer(permit);
    }

    // #### PUBLIC FUNC #### //
    
    // transfer cau/crc20 token to other chain
    function transfer(
        uint32 chainId,
        address token,
        uint amount,
        address receiver,
        // permit2 params
        uint256 nonce,
        uint256 deadline,
        bytes calldata sig
    ) public payable whenNotPaused() {
        // transfer cau
        uint maxBalance = 0;
        if (token == address(0)) {
            require(msg.value > 0, "You have to deposit a positive amount");
            maxBalance = address(this).balance * maxHotBalancePercent / 100;
        } else {
            require(msg.value == 0, "Deposit native coin for this token transfer is not allowed");
            // transfer the token amount back to this contract address
            permit2.permitTransferFrom(
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({
                        token: token,
                        amount: amount
                    }),
                    nonce: nonce,
                    deadline: deadline
                }),
                ISignatureTransfer.SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount
                }),
                msg.sender,
                sig
            );

            IERC20 iToken = IERC20(token);
            maxBalance = iToken.balanceOf(address(this)) * maxHotBalancePercent / 100;
        }

        // increase hot balance if it not reach 30% of total balance of contract
        hotBalances[token] = hotBalances[token] + amount;
        if (hotBalances[token] > maxBalance) {
            hotBalances[token] = maxBalance;
        }

        emit TransferToken(token, receiver, amount, chainId);
    }

    // #### OPERATOR FUNC (HOT WALLET) #### //

    // release CAU/WERC20
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

    // return hot balance of a token
    function hotBalance(address token) public view returns (uint) {
        return hotBalances[token];
    }

    // is this tx hash have been released coin/token
    function isReleased(bytes32 txHash) public view returns (bool) {
        return released[txHash];
    }

    // #### OWNER FUNC (COLD WALLET) #### //

    // approve more balance for hot wallet
    function approve(address token, uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = address(this).balance;
        if (token != address(0)) {
            IERC20 iToken = IERC20(token);
            balance = iToken.balanceOf(address(this));
        }

        require(amount <= balance, "Insufficient aprroved amout");
        hotBalances[token] = amount;
    }

    // deposit wrap token to be released for users who bridge token from other chains
    // we pre-mint some token by cold address and deposit to this contract to be released by hot wallet for more secure.
    function deposit(address token, uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Deposit wrap token address");
        IERC20 iToken = IERC20(token);
        require(iToken.transferFrom(msg.sender, address(this), amount), "Insufficient allowance token balance");
        uint balance = iToken.balanceOf(address(this));
        hotBalances[token] = balance;
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
