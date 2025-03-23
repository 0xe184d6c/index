// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;


/// @title  Mint To Pay HTLC contract
/// @author Zeconomy
/// @dev    Tests are written in foundry


import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { CPTOKEN } from "../../upgradeable_token/cptoken/CPTOKEN.sol";
import { PROGRAM } from "../../program/PROGRAM.sol";
import { Enums, Helper, Structs } from "../../utils/Utils.sol";
import { Events } from "../../utils/Events.sol";
import { GeneralReverts } from "../../utils/Reverts.sol";
import { ERC1155Receiver } from "../../utils/ERC1155Receiver.sol";

contract MTHTLC_V1 is Initializable, ERC1155Receiver, ReentrancyGuardUpgradeable {

    using Helper for uint256;
    using Helper for address;
    using Helper for Structs.LockedOrders;
    using Helper for Structs.AccountHoldingsInHtlc;
    
    /// @dev    Structs declaration
    Structs.LockedOrders private _lockedOrders;     /// locked orders
    Structs.Orders private _orders;          /// orders
    Structs.AccountHoldingsInHtlc private _accountHoldings;
   

    /**
        @dev  initialize the CPTOKEN by the ERC1155 INTERFACE.
        @dev  this will extend the functionalities of the token standard to the CPTOKEN variable
    */
    CPTOKEN private _CPTOKEN;
    PROGRAM private _DCP_PROGRAM;
    

    /// @dev contract owner
    address _contractOwner;

    /**
        @dev    Intializer that acts as a constructor for the contract to initialize contract state
    */
    function initialize(address cptokenAddress, address program) public virtual initializer {
        _CPTOKEN = CPTOKEN(payable(cptokenAddress));
        _contractOwner = msg.sender;
        _DCP_PROGRAM = PROGRAM(program);
        __ReentrancyGuard_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev    Orders locked/deposited by the investor
    /// @dev    These orders are still within the reach of the investor to be canceled
    /// @dev    Function fetches the deposited amount associated with the transaction
    function _getLockedOrderBalance(bytes32 _transactionId) internal view returns (uint256) {

        if (_orders._status[_transactionId] != Enums.OrderStatus.SUBMITTED) 
            return 0;
        return _orders._orders[_transactionId]._amount;
    }

     /// @dev   function fetches deposited amount in batches
     /// @dev   These orders are within the reach of the investor to be canceled    
    function getBatchTransactionHTLCBalances(bytes32[] memory _transactionIds) private view returns (uint256[] memory) {

        uint256 _length = _transactionIds.length;
        uint256[] memory _balances = new uint256[](_length);

        for (uint256 index = 0; index < _transactionIds.length; index++) {
            uint256 _balance = _getLockedOrderBalance(_transactionIds[index]);
            _balances[index] = _balance;
        }

        return _balances;
    }

    /// @dev    Submits buyback and rollorder transactions
    function submit(
        address _beneficiary,
        uint256 _tokenId,
        uint256 _amount,
        string calldata _note
    ) external 
    {

        _tokenId.isZero();
        _amount.isZero();

        bytes32 _transactionId = sha256(abi.encodePacked(
            _orders._nonce
        ));

        if (_orders._status[_transactionId] != Enums.OrderStatus.INVALID)
            revert GeneralReverts.OrderExists(_transactionId);

        _orders._nonce ++;

        _orders._orders[_transactionId] = Structs.Order(
            _transactionId,
            _tokenId,
            _amount,
            msg.sender,
            _beneficiary
        );

        _orders._status[_transactionId] = Enums.OrderStatus.SUBMITTED;

        /// @dev    Tracks refundable orders
        _lockedOrders.pushOrderToLockedOrders(msg.sender, _transactionId);

        /// @dev    Tracks account's holdings
        _accountHoldings._cummulativeBalance[msg.sender] += _amount;
        _accountHoldings.pushToAccountHoldings(msg.sender, _transactionId);

        /// @dev    Sends DCP to htlc
        _CPTOKEN.safeTransferFrom(
            msg.sender, 
            address(this), 
            _tokenId,
            _amount, 
            "", 
            _beneficiary, 
            address(0), 
            _note
        );            

        /// @dev    Emits event
        emit Events.SubmitOrder(
            _transactionId,
            msg.sender,
            _tokenId,
            _amount
        );

    }


    /// @dev    Function for accounts to reclaim their dcps provided it is still in its refundable state
    /// @dev    Orders in the submitted state are reclaimable
    function reclaim( 
        bytes32 _transactionId,
        string memory _note
    ) external {

        if (_orders._status[_transactionId] != Enums.OrderStatus.SUBMITTED)
            revert GeneralReverts.OrderNotSubmitted(_transactionId);

        Structs.Order memory _order = _orders._orders[_transactionId];

        if (msg.sender != _order._investor)
            msg.sender.throwCallerError();
        
        _orders._status[_transactionId] = Enums.OrderStatus.REFUNDED;

        /// @dev    Untracks order from refundables
        _lockedOrders.popFromLockedOrders(msg.sender, _transactionId);

        /// @dev    Updates cummulative holdings
        _accountHoldings._cummulativeBalance[msg.sender] -= _order._amount;
        _accountHoldings.popFromAccountHoldings(msg.sender, _transactionId);

        /// @dev Returns DCP to account
        _CPTOKEN.safeTransferFrom(
            address(this), 
            _order._investor, 
            _order._tokenId, 
            _order._amount, 
            "", 
            address(0), 
            _order._beneficiary, 
            _note
        );

        emit Events.TransferBack(
            _transactionId,
            _order._investor,
            _order._tokenId,
            _order._amount
        );
        
    }


    /// @dev    Orders are locked, hence unreclaimable unless unlocked
    function hold(
        bytes32 _transactionId
    ) external {

        if (_orders._status[_transactionId] != Enums.OrderStatus.SUBMITTED)
            revert GeneralReverts.OrderNotSubmitted(_transactionId);

        Structs.Order memory _order = _orders._orders[_transactionId];

        msg.sender.validateIssuer(
            _order._tokenId,
            Helper.CallerValidationType.ISSUANCE,
            _DCP_PROGRAM
        );

        _orders._status[_transactionId] = Enums.OrderStatus.PENDING;
        _lockedOrders.popFromLockedOrders(_order._investor, _transactionId);
        emit Events.PendOrder(_transactionId);

    }

    /// @dev    Locked orders are unlocked
   function unlock(
        bytes32 _transactionId,
        string calldata _note
    ) external {

        if (
            _orders._status[_transactionId] != Enums.OrderStatus.SUBMITTED &&
            _orders._status[_transactionId] != Enums.OrderStatus.PENDING
            )
            revert GeneralReverts.OrderCannotBeUnlocked(_transactionId);
        
        Structs.Order memory _order = _orders._orders[_transactionId];

        if (
            !msg.sender.isIssuerForIssuance(_order._tokenId, _DCP_PROGRAM) &&
            !msg.sender.isDepositoryAgentForIssuance(_order._tokenId, _DCP_PROGRAM)
            )
        msg.sender.throwCallerError();

        if (_orders._status[_transactionId] == Enums.OrderStatus.SUBMITTED)
            _lockedOrders.popFromLockedOrders(_order._investor, _transactionId);
        
        _orders._status[_transactionId] = Enums.OrderStatus.REFUNDED;

        /// @dev    Accounts owning the orders are refunded
        _accountHoldings._cummulativeBalance[_order._investor] -= _order._amount;
        _accountHoldings.popFromAccountHoldings(_order._investor, _transactionId);

        _CPTOKEN.safeTransferFrom(
            address(this), 
            _order._investor,
            _order._tokenId, 
            _order._amount, 
            "", 
            address(0), 
            _order._beneficiary, 
            _note
        );

        emit Events.TransferBack(
            _transactionId,
            _order._investor,
            _order._tokenId,
            _order._amount
        );  

    }

    /// @dev    Settle buybacks and  roll orders
    function settle(
        bytes32 _transactionId,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _amountToLock,
        address _beneficiary,
        string calldata _notes
    ) external {

        /// @dev validate either is zero
        if (
            (_tokenId == 0) && (_amount != 0) ||
            (_tokenId != 0) && (_amount == 0)
        )
            revert GeneralReverts.BothOrNoneZerosExpected();

        /// check state
        if (_orders._status[_transactionId] != Enums.OrderStatus.PENDING)
            revert GeneralReverts.OrderNotAccepted(_transactionId);

        Structs.Order memory _order = _orders._orders[_transactionId];

        /// @dev check agent
        msg.sender.validatePaymentAgent(
            _order._tokenId,
            Helper.CallerValidationType.ISSUANCE,
            _DCP_PROGRAM
        );

        /// @dev    check program matches for the token ids
        _tokenId.revert__Unmatched__Programs(_order._tokenId, _DCP_PROGRAM);

        _orders._status[_transactionId] = Enums.OrderStatus.SETTLED;

        /// @dev    Update account holdings
        _accountHoldings._cummulativeBalance[_order._investor] -= _order._amount;
        _accountHoldings.popFromAccountHoldings(_order._investor, _transactionId);

        _CPTOKEN.burnToken(
            _order._tokenId, 
            _order._amount
        );

        if (_tokenId !=0 && _amount !=0)
           _CPTOKEN.issueToken(
            _order._investor, 
            _tokenId, 
            _amount,
            _amountToLock,
            _beneficiary,
            _notes
        );

        emit Events.Settle(_transactionId);
    }

    /// @dev    Fetch array of refundable orders for an account
    function getLockedOrders(address _account) external view returns (bytes32[] memory) {

        return _lockedOrders._lockedOrders[_account]; 
       
    }

    /// @dev Fetch account holdings
    function getAccountHoldings(address _account) external view returns (uint256, bytes32[] memory) {
        return (
                _accountHoldings._cummulativeBalance[_account],
                _accountHoldings._accountOrders[_account]
            );

    }

    /// @dev    Transfer contract ownership
    function transferContractOwnerShip(address _account) external {
        _account.revert__If__Address__Zero();

        if (msg.sender != _contractOwner)
            msg.sender.throwCallerError();
        
        _contractOwner = _account;
    }

    /// @dev implement reentrance guard
    /// @notice called by program contract
    /// @dev    To initiate force refunds upon dewhitelist
    function unlockAll(address _account) external nonReentrant() {

        if (msg.sender != address(_DCP_PROGRAM))
            msg.sender.throwCallerError();

        if (_accountHoldings._cummulativeBalance[_account] > 0 ) {

            do {

                /// @dev picks order from first index, refunds and pops it
                bytes32 _transactionId = _accountHoldings._accountOrders[_account][0];
                Structs.Order memory _order = _orders._orders[_transactionId];
                
                /// @dev    if order is listed as refundable in locked orders, pop it
                if (_orders._status[_transactionId] == Enums.OrderStatus.SUBMITTED)
                    _lockedOrders.popFromLockedOrders(_order._investor, _transactionId);

                _orders._status[_transactionId] = Enums.OrderStatus.REFUNDED;
                _CPTOKEN.safeTransferFrom(
                    address(this), 
                    _order._investor,
                    _order._tokenId, 
                    _order._amount, 
                    "", 
                    address(0), 
                    _order._beneficiary, 
                    ""
                );

                _accountHoldings._cummulativeBalance[_order._investor] -= _order._amount;
                _accountHoldings.popFromAccountHoldings(_order._investor, _transactionId);
            } while (_accountHoldings._accountOrders[_account].length > 0);

        }


    }

}

