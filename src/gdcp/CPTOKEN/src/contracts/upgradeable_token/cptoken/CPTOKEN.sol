// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title  DCP contract
/// @author Zeconomy
/// @notice This contract is of ERC1155 token standard
/// @notice This contract can be used for issuing DCPs and implementing Buy Orders
/// @dev    Tests are written in Truffle and In foundry


import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { PROGRAM } from  "../../program/PROGRAM.sol"; 
import { Enums, Helper, Structs } from "../../utils/Utils.sol";
import { Events } from "../../utils/Events.sol";
import { DomainSeparator } from "../../utils/DomainSeparator.sol";
import { ZEC_EIP712 } from "../../utils/ZEC_EIP712.sol";
import { GeneralReverts, ProgramReverts } from "../../utils/Reverts.sol";

contract CPTOKEN is Initializable, ERC1155Upgradeable, DomainSeparator {

    using Helper for uint256;
    using Helper for uint32;
    using Helper for address;
    using ZEC_EIP712 for bytes; 
    
    string private _name;             
    string private _symbol;           
    address private _contractOwner;
    address private _mhtlc;
    uint256 private _signNonce;
    PROGRAM private _DCP_PROGRAM;
    
    mapping(uint256 => uint256) private _totalSupply;
    mapping(uint256 => mapping(address => Structs.LockedTokens)) private _lockedTokens; // map issuance id to the addresses to be locked
    
    mapping(uint256 => bool) private _paymentComplete;
    mapping(address => bool) private _signers;

    /// @dev    modifier that requires that the sender must be the contract owner
    modifier onlyContractOwner {
        require(
            msg.sender == _contractOwner,
            "Only contractOwner can call this function."
        );
        _;
    }

    
    /**
        initializer to initialize in place of the constructor; the token name, token symbol, the contract owner and the token uri 

        @param _tokenName is the name assigned to the token on deployment
        @param _tokenSymbol is the symbol assigned to the token on deployment
        @param _uri is the token URI assigned on deployment

        @dev    the initialize function is used in place of the constructor to ensure that the contract is upgradable
    */

    function initialize(
        string memory _tokenName, 
        string memory _tokenSymbol, 
        string memory _uri, 
        string calldata _eip712Name, 
        string calldata _eip712Version,  
        address _program, 
        address _aSigner
    )
        public 
        virtual 
        initializer
    {
        
        _contractOwner = msg.sender;         //  set contract owner
        _name = _tokenName;                  //  set token name
        _symbol = _tokenSymbol;              //  set token symbol
        __ERC1155_init(_uri);               //  set token uri  ( upgradable safe )
        _DCP_PROGRAM = PROGRAM(_program);
        _setDomainSeparator(_eip712Name, _eip712Version);
        _signers[_aSigner] = true;

    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
        @dev    function to get the address of the contract owner
        @return contractOwner which is the address of the contract owner
    */

    function getContractOwner() public view returns (address) {
        return _contractOwner;
    }


   
    /// @notice issue tokens
    /// @notice issuance must be on or after program effective date
    /// @notice issuance must be before program  expiration
    
    function issueToken(
        address account, 
        uint256 tokenId, 
        uint256 amount,
        uint256 amountToLock,  
        address toBeneficiary, 
        string calldata notes
    ) external { 

        tokenId.isZero();
        amount.isZero();

        if (!_DCP_PROGRAM.isTokenInitialized(tokenId)) revert ProgramReverts.TokenNotInitialized(tokenId);

        uint256 _programId = _DCP_PROGRAM.getTokenProgram(tokenId)._programId;
        
        _DCP_PROGRAM.revert__If__deauthorized(_programId);
        account.revert__If__Agent(_mhtlc, _programId, _DCP_PROGRAM);
        account.revert__If__Address__Zero();
        _programId.validateEffectiveDateAndExpiration(_DCP_PROGRAM);

        _revert__If__Settled(tokenId);

        if (amountToLock > amount)
            revert GeneralReverts.InvalidAmountToLock(amountToLock);

        if(
            msg.sender.isIssuerForProgram(_programId, _DCP_PROGRAM) || 
            msg.sender == _mhtlc ||
            msg.sender.isDepositoryAgentForProgram(_programId, _DCP_PROGRAM)
        ) {

            /// @dev    handle token lock

            if (amountToLock != 0) {

                if (_lockedTokens[tokenId][account]._isLocked == false)
                    _lockedTokens[tokenId][account] = Structs.LockedTokens(true, amountToLock);
                
                else if (_lockedTokens[tokenId][account]._isLocked == true) 
                    _lockedTokens[tokenId][account]._amountLocked += amountToLock;

            } 
            _totalSupply[tokenId] += amount;                   
            _mint(account, tokenId, amount, "");
        
        }

        else {
            msg.sender.throwCallerError();
        }           
        
    }
  
    /// @notice function to burn the token can only be called by the holder
    function burnToken(uint256 tokenId, uint256 amount) external  {

        if ( amount > balanceOf(msg.sender, tokenId))
            revert GeneralReverts.InsufficientBalance();
        _totalSupply[tokenId] -= amount;
        _burn(msg.sender,tokenId,amount);
        
    }
    
    /**
        * @dev Total supply of issuance id
     */
    function totalSupply(uint256 tokenID) public view returns (uint256) {
        return _totalSupply[tokenID];
    }

    /**
     * @dev Indicates weither any token exist with a given id, or not.
     */
    function exists(uint256 tokenID) public view returns (bool) {
        return totalSupply(tokenID) > 0;
    }
    
        /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) 
        public
        virtual
        override
    {

        require(_validateBatchPayment(tokenIds, from) == false, "Error: Payment Completed");
        to.revert__If__Agent(_mhtlc, tokenIds, _DCP_PROGRAM);

        if (to != _mhtlc)
            address(this).revert__If__Locked(from, tokenIds, amounts);

        require(from.isWhitelistedForBatch(tokenIds, _DCP_PROGRAM) == true, "Error: not whitelisted");
        require(to.isWhitelistedForBatch(tokenIds, _DCP_PROGRAM) == true, "Error: not whitelisted");
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()),"ERC1155: caller is not owner nor approved" );
        _safeBatchTransferFrom(from, to, tokenIds, amounts, data);
        
    }

    /// @dev Safe transfer with beneficiaries
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data,
        address fromBeneficiary,
        address toBeneficiary,
        string memory note
    ) 
        external 
        virtual
    
    {
        require(_validateBatchPayment(tokenIds, from) == false, "Error: Payment Completed");
        to.revert__If__Agent(_mhtlc, tokenIds, _DCP_PROGRAM);

        if (to != _mhtlc)
            address(this).revert__If__Locked(from, tokenIds, amounts);
            
        from.validateBeneficiaryForBatch(fromBeneficiary, tokenIds, _DCP_PROGRAM);
        to.validateBeneficiaryForBatch(toBeneficiary, tokenIds, _DCP_PROGRAM);
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()),"ERC1155: caller is not owner nor approved" );
        _safeBatchTransferFrom(from, to, tokenIds, amounts, data);
    }
    
    /**
        * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
        *
        * Emits a {TransferSingle} event.
        *
        * Requirements:
        *
        * - `to` cannot be the zero address.
        * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
        * - `from` must have a balance of tokens of type `id` of at least `amount`.
        * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
        * acceptance magic value.
    */
     
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) 
        public
        virtual 
        override
    {
        
        _revert__If__Settled(tokenId);
        uint256 _programId = _DCP_PROGRAM.getTokenProgram(tokenId)._programId;
        to.revert__If__Agent(_mhtlc, _programId, _DCP_PROGRAM);

        if (to != _mhtlc)
            address(this).revert__If__Locked(from, tokenId, amount);

        require(from.isWhitelistedForSingle(_programId, _DCP_PROGRAM) == true, "Error: not whitelisted");
        require(to.isWhitelistedForSingle(_programId, _DCP_PROGRAM) == true, "Error: not whitelisted");
        require(msg.sender == from || isApprovedForAll(from, _msgSender()),"ERC1155: caller is not owner nor approved");
        _safeTransferFrom(from, to, tokenId, amount, data);
    }
    
    /// @dev    Safe transfer with beneficiaries
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data,
        address fromBeneficiary,
        address toBeneficiary,
        string calldata note
    ) 
        external 
        virtual 
    {

        _revert__If__Settled(tokenId);
        uint256 _programId = _DCP_PROGRAM.getTokenProgram(tokenId)._programId;
        to.revert__If__Agent(_mhtlc, _programId, _DCP_PROGRAM);

        if (to != _mhtlc)
            address(this).revert__If__Locked(from, tokenId, amount);

        from.validateBeneficiaryForSingle(fromBeneficiary, _programId, _DCP_PROGRAM);
        to.validateBeneficiaryForSingle(toBeneficiary, _programId, _DCP_PROGRAM);
        require(msg.sender == from || isApprovedForAll(from, _msgSender()),"ERC1155: caller is not owner nor approved");
        _safeTransferFrom(from, to, tokenId, amount, data);


    }

    /**
        @dev    function to transfer token ownership
        @notice address must not be address 0
        @notice address must not be the current contract owner
     */
    
    function transferContractOwnership(address _address, bytes memory _signature, ZEC_EIP712.AdministratorAuth memory _administratorAuth) public onlyContractOwner {
        
        if (_address == address(0))
            revert GeneralReverts.AddressZero();

        require(_address != _contractOwner, "Cannot reassign to current owner");

        if (_administratorAuth.timeSigned > block.timestamp)
            revert GeneralReverts.InvalidSignatureTime();
       
        if ((_administratorAuth.timeSigned + 4 hours) < block.timestamp)
            revert GeneralReverts.SignatureExpired();

        if (_administratorAuth.nonce != _signNonce)
            revert GeneralReverts.InvalidNonce();

        if (_signature.length != 65)
            revert GeneralReverts.InvalidSignature();

        address _recoveredSigner = _signature.verifyAdministratorSignature(_EIP712Domain, _administratorAuth);
        
        if ( _signers[_recoveredSigner] != true )
            revert GeneralReverts.InvalidSigner(_recoveredSigner); 
        
        ++ _signNonce; // update nonce    
        _contractOwner = _address;
    }

    function nonce() external view returns (uint256) {
        return _signNonce;
    }

    /**
        @dev    To lock an holder's issuance
     */
    function authorizeLock(uint256 _tokenId, uint256 _amount, address _holder) external returns (bool success) {

        if (
            !msg.sender.isIssuerForIssuance(_tokenId, _DCP_PROGRAM) &&
            !msg.sender.isDepositoryAgentForIssuance(_tokenId, _DCP_PROGRAM)
            )
        msg.sender.throwCallerError();
        
        _lockedTokens[_tokenId][_holder] = Structs.LockedTokens(true, _amount);
        return true;
    }

    /**
        @dev    To unlock an holder's issuance
    */
    function authorizeUnlock(uint256 _tokenId, uint256 _amount, address _holder) external returns (bool success) {
         
        if (
            !msg.sender.isIssuerForIssuance(_tokenId, _DCP_PROGRAM) &&
            !msg.sender.isDepositoryAgentForIssuance(_tokenId, _DCP_PROGRAM)
            )
        msg.sender.throwCallerError();

        uint256 _amountLocked = _lockedTokens[_tokenId][_holder]._amountLocked;

        if (_amount < _amountLocked)
            _lockedTokens[_tokenId][_holder]._amountLocked = _amountLocked - _amount;
        
        else if (_amount == _amountLocked)
            _lockedTokens[_tokenId][_holder] = Structs.LockedTokens(false, 0);
        
        else 
            revert GeneralReverts.AmountGreaterThanLockedAmount(_amountLocked);
        return true;

    }
    
  
    /**
        @dev function to set the addresses for the mint-to-pay htlc
     */

    function setHtlc(address _mintToPayHtlc) external onlyContractOwner {
        _mintToPayHtlc.revert__If__Address__Zero();
        _mhtlc = _mintToPayHtlc;
    }
    
    /// @dev    validate batch payment-complete
    function _validateBatchPayment(uint256[] memory _ids, address _account) internal view returns (bool _pass)  {

        uint256 _length = _ids.length;

        for (uint256 index = 0; index < _length; ++ index) {

            if(_paymentComplete[_ids[index]] == true) {
                return true;
            }
        }
        return false;

    }
  
    /// @dev    validate batch payment-complete
    /// @dev    for external calls only, to fetch the list of settled issuance ids
    
    function validateBatchPayment(uint256[] calldata _ids) external view returns (bool[] memory _settled)  {

        bool[] memory settled = new bool[](_ids.length);
        for (uint256 index = 0; index < _ids.length; index++) {

            bool _isSettled = _paymentComplete[_ids[index]];
            settled[index] = _isSettled;
        }

        return settled;

    }

    /// @notice Mark an issuance id as paid for an holder
    /// @notice Caller must be the valid agent
    /// @notice Issuance id must be unpaid bgefore the call
    /// @notice Holder must be whitelisted under the program linked to the issuance id
    
    function markPaid(uint256 _tokenId) external  {

        uint256 _programId = _DCP_PROGRAM.getTokenProgram(_tokenId)._programId;

        msg.sender.validatePaymentAgent(
            _programId,
            Helper.CallerValidationType.PROGRAM,
            _DCP_PROGRAM
        );
        
        if (_paymentComplete[_tokenId] == true)
            revert GeneralReverts.PaymentCompleted(_tokenId);
        
        _paymentComplete[_tokenId] = true;

    }

    /// @notice Check if an issuance id has been marked as paid for a particular holder
    /// @return settled which is the payment status
    
    function isPaid(uint256 _tokenId) public view returns (bool settled) {
        return _paymentComplete[_tokenId];
    }

    /// @dev    revert if an issuance has been marked as paid
    function _revert__If__Settled(uint256 _issuanceId) internal {
        
        if (isPaid(_issuanceId) == true)
            revert GeneralReverts.PaymentCompleted(_issuanceId);

    }

    /// @dev    To set domain separator
    function setDomainSeparator(
        string calldata _eip712Name,
        string calldata _eip712Version
    )
        external
    {
        require(msg.sender == _contractOwner, "Only contract owner");
        _setDomainSeparator(_eip712Name, _eip712Version);
    }

    /// @dev    To fetch locked tokens
    function getLockedTokens(address _holder, uint256 _tokenId) external view returns (Structs.LockedTokens memory) {
        return _lockedTokens[_tokenId][_holder];
    }

    
    
}

