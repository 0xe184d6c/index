pragma solidity 0.8.20;

import { GeneralReverts, ProgramReverts, TokenReverts } from "./Reverts.sol";
import { ZEC_EIP712 } from "./ZEC_EIP712.sol";
import { PROGRAM } from "../program/PROGRAM.sol";
import { CPTOKEN } from "../upgradeable_token/cptoken/CPTOKEN.sol";

library Enums {

    /**
        @dev  Enumerator to handle the  state of requested offers

        INVALID:  non existing offer request
        OPEN:     currently open and active offer request
        SETTLED:  settled and closed offer request
        EXPIRED:  Expired and refunded offers
    */

    enum OrderStatus {
        INVALID,
        SUBMITTED,
        PENDING,
        REFUNDED,
        SETTLED
    }


    enum TransferredDCPStatus {
        INVALID,
        TRANSFERRED,
        REFUNDED,
        BURNT
    }

     enum OfferState {

        INVALID,
        OPEN,
        SETTLED,
        EXPIRED,
        REJECTED

    }

    enum AccountType {
        DIRECT,
        CUSTODIAN,
        AGENT
    }

    enum InitializationState {
        NULL,
        INITIALIZED,
        DISCONTINUED
    }

    enum Convert {
        NULL,
        FDCP_DCP,
        DCP_FDCP
    }

    enum FDCP {
        DCP,
        SDCP,
        LDCP,
        RDCP
    }


}


library Structs {

     struct Program {

        uint256 _programId;
        uint256 _maximumTenor;
        uint256 _minimumTenor;
        uint256 _maximumAuthorizedOutstandingAmount;
        uint256 _effectiveDate;
        uint256 _expiryDate;
        address _owner;
        address _validator;   
        
    }

    struct InitializeTokens {
        mapping(uint256 => bool) _isInitialized;
        mapping(uint256 => uint256) _tokenToProgram;
    }

    struct Document {

        bytes32 _documentHash;
        address[] _signers;
    }

    struct Documents {
        mapping(uint256 => Document[]) _programDocuments;
        mapping(bytes32 => Index) _docIndex;
    }

    struct Order {

        bytes32 _transactionId;
        uint256 _tokenId;
        uint256 _amount;
        address _investor;
        address _beneficiary;

    }

    struct Index {
        bool _isAssigned;
        uint256 _index;
    }

    struct LockedOrders {
        mapping(address => bytes32[]) _lockedOrders;
        mapping(bytes32 => Index) _lockedOrderIndex;
    }

    struct WhitelistData {
        Enums.AccountType _accountType;
        bool _isWhitelisted;
    }

    struct Orders {
        mapping(bytes32 => Order) _orders;
        mapping(bytes32 => Enums.OrderStatus) _status;
        uint256 _nonce;
    }

    struct LockedTokens {
        bool _isLocked;
        uint256 _amountLocked;
    }

    struct AccountHoldingsInHtlc {

        mapping(address => uint256) _cummulativeBalance;
        mapping(address => bytes32[]) _accountOrders;
        mapping(bytes32 => Index) _orderIndex;

    }


}


library Helper {

    enum CallerValidationType {
        ISSUANCE,
        PROGRAM
    }

    function isZero(uint256 _value) internal pure returns (bool) {

        if ( _value == 0 )
            revert GeneralReverts.IsZero();

        return false;

    }

    function revert__If__Address__Zero(address _self) internal {
        if (_self == address(0))
            revert GeneralReverts.AddressZero();
    }

    function isIssuerForIssuance(address _self, uint256 _issuanceId, PROGRAM _program) internal view returns (bool) {
        return (
            _self == _program.getTokenProgram(_issuanceId)._owner
            );
    }
    
    function isIssuerForProgram(address _self, uint256 _programId, PROGRAM _program) internal view returns (bool) {
        return (
            _self == _program.getProgram(_programId)._owner
        );
    }

    function isDepositoryAgentForIssuance(address _self, uint256 _issuanceId, PROGRAM _program) internal view returns (bool) {
        return(
            _self == _program.getTokenProgram(_issuanceId)._validator
        );
    }

    function isDepositoryAgentForProgram(address _self, uint256 _programId, PROGRAM _program) internal view returns (bool) {
        return (
            _self ==_program.getProgram(_programId)._validator
        );
    }

    function throwCallerError(address _self) internal pure {
        revert GeneralReverts.InvalidCaller(_self);
    }

    function throwIsExpiredError(bytes32 _orderId) internal pure {
        revert GeneralReverts.ExpiredOrder(_orderId);
    }

    function throwNotExpiredError(bytes32 _orderId) internal pure {
        revert GeneralReverts.NotExpired(_orderId);
    }

    function _validateIssuerViaIssuance(address _issuer, uint256 _issuanceId, PROGRAM _program) internal view returns (bool) {

        if (isIssuerForIssuance(_issuer, _issuanceId, _program) == false)
            throwCallerError(_issuer);

        return true;
    }

    function _validateIssuerViaProgram (address _issuer, uint256 _programId, PROGRAM _program) internal view returns (bool) {

        if (isIssuerForProgram(_issuer, _programId, _program) == false)
            throwCallerError(_issuer); 
            
        return true;
    }

    function _validateDepositoryAgentViaIssuance(
        address _agent, 
        uint256 _issuanceId, 
        PROGRAM _program
    )   
        internal 
        view 
        returns (bool) 
    {

        if (isDepositoryAgentForIssuance(
            _agent, 
            _issuanceId, 
            _program) == false
        )
            throwCallerError(_agent);

        return true;
    }

    function _validateDepositoryAgentViaProgram(
        address _agent, 
        uint256 _programId, 
        PROGRAM _program
    ) 
        internal 
        view 
        returns (bool)
    {

        if (isDepositoryAgentForProgram(
            _agent, 
            _programId, 
            _program) == false
        )
            throwCallerError(_agent); 
            
        return true;
    }


    function validateIssuer(
        address _self, 
        uint256 _tokenOrProgramId, 
        CallerValidationType _validationType,
        PROGRAM _program
    )
        internal 
        view 
        returns (bool)
    {

        if (_validationType == CallerValidationType.ISSUANCE)
            _validateIssuerViaIssuance(_self, _tokenOrProgramId, _program);

        else if (_validationType == CallerValidationType.PROGRAM)
                _validateIssuerViaProgram(_self, _tokenOrProgramId, _program);
                 
        else
            revert GeneralReverts.UnexpectedValidation();

    }

    function validatePaymentAgent(
        address _self,
        uint256 _tokenOrProgramId, 
        CallerValidationType _validationType,
        PROGRAM _program
    ) 
        internal 
        view
        returns (bool)
    {
        if (_validationType == CallerValidationType.ISSUANCE)
            _validateDepositoryAgentViaIssuance(_self, _tokenOrProgramId, _program);
        
        else if (_validationType == CallerValidationType.PROGRAM)
            _validateDepositoryAgentViaProgram(_self, _tokenOrProgramId, _program);
        
        else
            revert GeneralReverts.UnexpectedValidation();

    }

    function isWhitelistedForSingle(address _self, uint256 _programId, PROGRAM _program) internal view returns (bool) {
        
        if  (isIssuerForProgram(_self, _programId, _program) == true )
            return true;
        
        else 
            return _program.isWhitelisted(_programId, _self)._isWhitelisted;

    }

    function isWhitelistedForBatch(address _self, uint256[] memory _ids, PROGRAM _program) internal view returns (bool) {

        uint256 length = _ids.length;

        for (uint256 index = 0; index < length; ++ index) {

            uint256 _programId = _program.getTokenProgram(_ids[index])._programId;
            bool _result = isWhitelistedForSingle(_self, _programId, _program);

            if (_result == false ) return false;

        }

        return true;

    }

    function accountType(address _self, uint256 _programId, PROGRAM _program) internal view returns (Enums.AccountType) {

        if (isWhitelistedForSingle(_self, _programId, _program) == false)
            revert ProgramReverts.NotWhiteListed(_programId, _self);
        
        return _program.isWhitelisted(_programId, _self)._accountType;
    }

    function validateEffectiveDateAndExpiration(uint256 _self, PROGRAM _program) internal view returns (bool) {

        Structs.Program memory __program = _program.getProgram(_self);

        if (
            block.timestamp < __program._effectiveDate || 
            block.timestamp > __program._expiryDate
        ) revert 

        TokenReverts.OnOrAfterEffectiveDateButBeforeExpiration(
            block.timestamp,
            __program._effectiveDate,
            __program._expiryDate
        );

        else
            return true;

    }

    function validateExpiredOrder(bytes32 _self, uint256 _expiration) internal view {
        
        if (block.timestamp > _expiration)
            throwIsExpiredError(_self);

    }

    function validateUnExpiredOrder(bytes32 _self, uint256 _expiration) internal view {

        if (block.timestamp <= _expiration)
            throwNotExpiredError(_self);
    }

    function validateBeneficiaryForSingle(address _self, address _beneficiary, uint256 _programId, PROGRAM _program) internal {
        
        //  account must be whitelisted
        //  check if account is custodian
        if (accountType(_self, _programId, _program) == Enums.AccountType.CUSTODIAN) {

             //  beneficiary must not be address zero if above is true
            revert__If__Address__Zero(_beneficiary);

            //  beneficiary must be whitelisted if above is valid
            if (isWhitelistedForSingle(_beneficiary, _programId, _program) == false)
                revert ProgramReverts.NotWhiteListed(_programId, _beneficiary);

        } else
            return;  
        
    }

    function validateBeneficiaryForBatch(address _self, address _beneficiary, uint256[] memory _ids, PROGRAM _program) internal {

        uint256 length = _ids.length;

        for (uint256 index = 0; index < length; ++index) {

            uint256 _programId = _program.getTokenProgram(_ids[index])._programId;
            validateBeneficiaryForSingle(_self, _beneficiary, _programId, _program);

        }

    }

    /// @dev Zero is a valid index value by default, but not in this case
    /// @dev By default all values in the struct hold index value zero, hence the need for a boolean check
    function isAssigedIndex(
        Structs.LockedOrders storage _self, 
        bytes32 _transactionId
    )   internal 
        view 
        returns (bool) 
    {

        return _self._lockedOrderIndex[_transactionId]._isAssigned;

    }

    function popFromLockedOrders(
        Structs.LockedOrders storage _self, 
        address _account,
        bytes32 _transactionId
    ) internal 
    {

        require(
            isAssigedIndex(_self, _transactionId) == true,
            "Error: Index not assigned to order"
        );

        //  get index of the data to be removed
        uint256 _index = _self._lockedOrderIndex[_transactionId]._index;
        uint256 _length = _self._lockedOrders[_account].length;

        if (_length == 1) {
            _self._lockedOrders[_account].pop();
        }

        else if ((_index != 0) && (_index == _length - 1)) {
            _self._lockedOrders[_account].pop();   
        }

        else {

             //  move the last element to this index without shifting data in the array
            _self._lockedOrders[_account][_index] = _self._lockedOrders[_account][_length - 1];

            //  pop the array
            _self._lockedOrders[_account].pop();

            //  update the index data of the moved order
            _self._lockedOrderIndex[_self._lockedOrders[_account][_index]]._index = _index;

        }
       
        //  update index data of the removed order
        _self._lockedOrderIndex[_transactionId] = Structs.Index(false, 0);

    }


    /// @dev    OPEN and ACCEPTED orders are the only valid orders to be recognized as locked
    function pushOrderToLockedOrders(
        Structs.LockedOrders storage _self, 
        address _account,
        bytes32 _transactionId
    ) internal 
    {
            
        _self._lockedOrders[_account].push(_transactionId);
        _self._lockedOrderIndex[_transactionId] = Structs.Index(true, _self._lockedOrders[_account].length - 1);
            
    }

    function revert__If__Agent(address _self, address _mhtlc, uint256 _programId, PROGRAM _program) internal {

        if ((_self != _mhtlc) && (accountType(_self, _programId, _program) == Enums.AccountType.AGENT)) {
            revert GeneralReverts.IssuanceNotPermitted();
        }

    }


    function revert__If__Agent(address _self, address _mhtlc, uint256[] memory _ids, PROGRAM _program) internal {

        uint256 length = _ids.length;

        for (uint256 index = 0; index < length; ++index) {

            uint256 _programId = _program.getTokenProgram(_ids[index])._programId;
            revert__If__Agent(_self, _mhtlc, _programId, _program);

        }

    }

    function isLocked(address _cptoken, address _account, uint256 _tokenId, uint256 _amount) internal view returns (bool) {

        CPTOKEN cptoken = intialize__cptoken__interface(_cptoken);
        Structs.LockedTokens memory _lockedTokens = cptoken.getLockedTokens(_account, _tokenId);

        if (_lockedTokens._isLocked == false)
            return false;
        
        else {

            /// @dev    check if the amount is captured within free tokens
            uint256 _balance = cptoken.balanceOf(_account, _tokenId);

            if ( _amount > (_balance - _lockedTokens._amountLocked))
                return true;
            
            return false;

        }

    }

    function revert__If__Locked(
        address _cptoken, 
        address _account, 
        uint256 _tokenId, 
        uint256 _amount
    ) internal {
        
        if (isLocked(_cptoken, _account, _tokenId, _amount) == true)
            revert GeneralReverts.TokenLocked(_tokenId);

    }

    function revert__If__Locked(
        address _cptoken, 
        address _account, 
        uint256[] memory _tokenIds, 
        uint256[] memory _amounts
    ) internal {

        uint256 _length = _tokenIds.length;

        for (uint256 index = 0; index < _length; ++index) {
            revert__If__Locked(_cptoken, _account, _tokenIds[index], _amounts[index]);
        }

    }

    function intialize__cptoken__interface(
        address _cptoken
    ) 
        internal 
        view 
        returns (CPTOKEN) 
    {
        return CPTOKEN(_cptoken);
    }

    function pushToAccountHoldings(
        Structs.AccountHoldingsInHtlc storage _self,
        address _account,
        bytes32 _transactionId
    ) internal 
    {
        _self._accountOrders[_account].push(_transactionId);
        _self._orderIndex[_transactionId] = Structs.Index(
                                            true,
                                            _self._accountOrders[_account].length -1
                                            );
    }

    function popFromAccountHoldings(
        Structs.AccountHoldingsInHtlc storage _self,
        address _account,
        bytes32 _transactionId
    ) internal
     
    {
        require(
            _self._orderIndex[_transactionId]._isAssigned == true,
            "Index not assigned"
        );

        uint256 _index = _self._orderIndex[_transactionId]._index;
        uint256 _length = _self._accountOrders[_account].length;
      

        if (_length == 1) {
            _self._accountOrders[_account].pop();
        }

        else if ((_index != 0) && (_index == _length - 1)) {
            _self._accountOrders[_account].pop();   
        }

        else {

             //  move the last element to this index without shifting data in the array
            _self._accountOrders[_account][_index] = _self._accountOrders[_account][_length - 1];

            //  pop the array
            _self._accountOrders[_account].pop();

            //  update the index data of the moved order
            _self._orderIndex[_self._accountOrders[_account][_index]]._index = _index;

        }
       
        //  update index data of the removed order
        _self._orderIndex[_transactionId] = Structs.Index(false, 0);

    }

    function revert__Unmatched__Programs(
        uint256 _tokenId1, 
        uint256 _tokenId2, 
        PROGRAM _program
    ) internal 
    
    {
        uint256 _programId1 = _program.getTokenProgram(_tokenId1)._programId;
        uint256 _programId2 = _program.getTokenProgram(_tokenId2)._programId;

        if (_programId1 != _programId2)
            revert ProgramReverts.ProgramMismatched();
    }

}    
