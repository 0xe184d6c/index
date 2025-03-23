pragma solidity 0.8.20;

import { Enums } from "./Utils.sol";


library GeneralReverts {

    error InvalidCaller(address _caller);
    error NotApproved(address _holder, address _spender);
    error AddressZero();
    error NullAction();
    error FilledOrder(bytes32 _orderId);
    error DCPNotMinted(bytes32 _orderId);
    error InsufficientBalance();
    error InvalidSignature();
    error InvalidNonce();
    error InvalidSigner(address _returnedSigner);
    error IsZero();
    error SignatureExpired();
    error InvalidSignatureTime();
    error PopulatedIssuance(uint256 _issuanceid);
    error OrderCannotBeCanceled(bytes32 _orderId);
    error OrderCannotBeUnlocked(bytes32 _orderId);
    error OrderCannotBeReleased(bytes32 _orderId);
    error UnexpectedValidation();
    error ExpiredOrder(bytes32 _orderId);
    error InvalidOrder(bytes32 _orderId );
    error OrderExists(bytes32 _orderId);
    error NotExpired(bytes32 _orderId);
    error SettledOrder(bytes32 _orderId);
    error RefundedOrder(bytes32 _orderId);
    error UnexpectedType();
    error OrderNotSubmitted(bytes32 _orderId);
    error OrderNotAccepted(bytes32 _orderId);
    error BothOrNoneZerosExpected();
    error PaymentCompleted(uint256 _issuanceId);
    error IssuanceNotPermitted();
    error TokenLocked(uint256 _tokenId);
    error NotAuthorizedProgramCreator(address _address);
    error OwnerDeauthorized();
    error AmountGreaterThanLockedAmount(uint256 _lockedAmount);
    error InvalidAmountToLock(uint256 _amountToLock);
    error BytesZero();
}

library TokenReverts {

    error OnOrAfterEffectiveDateButBeforeExpiration(uint256 _dateAttempted, uint256 _effectiveDate, uint256 _expiryDate);
    error IssuanceLinkError(uint256 _issuanceId, uint256 _programId);
}

library ProgramReverts {

    error NotWhiteListed(uint256 _programId, address _address);
    error ExistingProgram(uint256 _programId);
    error ProgramDoesNotExist(uint256 _programId);
    error TokenNotInitialized(uint256 _tokenId);
    error TokenInitialized();
    error NoProgramRef();
    error InvalidEffectiveDate();
    error InvalidExpiryDate();
    error HashAssociatedWithDocument();
    error ProgramMismatched();
    error UnassignedDocument();
    error AssignedDocument();
    
}

library RollOrderReverts {

    error RollOrderExists(bytes32 _rollOrderId);
    error InvalidRollOrder(bytes32 _rollOrderId);
    error ExpiredRollOrder(bytes32 _rollOrderId);
    error RollOrderNotOpened(bytes32 _rollOrderId);
    error DCPTransferredForRollOrder();
    error DCPNotTransferredForRollOrder();

}

library VaultReverts {
    error InvalidConversion(Enums.FDCP from, Enums.FDCP to);
    error InsufficientBalance(uint256 balance, uint256 outstanding);
}