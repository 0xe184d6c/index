// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import { GeneralReverts, ProgramReverts } from "../utils/Reverts.sol";
import { Enums, Helper, Structs } from "../utils/Utils.sol";
import { DomainSeparator } from "../utils/DomainSeparator.sol";
import { ZEC_EIP712 } from "../utils/ZEC_EIP712.sol";
import { CPTOKEN } from "../upgradeable_token/cptoken/CPTOKEN.sol";
import { MTHTLC_V1 } from "../upgradeable_HTLC/MINT_TO_PAY_HTLC/MTHTLC_V1.sol";

contract PROGRAM is Initializable, NoncesUpgradeable, DomainSeparator  {

    using Helper for uint256;
    using Helper for uint32;
    using Helper for address;
    using ZEC_EIP712 for bytes;
    
    mapping (uint256 => Structs.Program) private _program;          //  private map that maps the Program struct the program id
    mapping (uint256 => bool) private _usedProgramId;       //  private map that tracks used and existing program id to avoid duplicated ids for different owners

    mapping (uint256 => mapping(bytes32 => bytes[])) private _documentSignatures;            //  the array of signatures of a document hash mapped to a program id
    mapping (uint256 => mapping(bytes32 => mapping (bytes => bool))) private _documentSignatureMarker;
    mapping (uint256 => mapping(address => Structs.WhitelistData)) private _accountWhiteLists;
    mapping (address => bool) private _approvedProgramCreator;


    address private _cptokenAddress;
    address private _contractOwner;
    Structs.Documents private _documents;
    Structs.InitializeTokens private _initializeTokens;
    MTHTLC_V1 private _mthtlc;

    event CreateProgram(uint256 indexed _programId, address indexed _owner);         
    event InitializeToken(uint256 indexed _programId, uint256 indexed _tokenId);   
    event DiscontinueToken(uint256 indexed _programId, uint256 indexed _tokenId);   
    event AccountWhitelist(uint256 indexed _programId, address indexed _account);
    event AccountBlacklist(uint256 indexed _programId, address indexed _account);
    event SetAuthorization(address indexed _account, bool _approved);
    

    /// @dev    initializer to set cptoken address
    /// @custom:oz-upgrades
    function initialize (string calldata _eip712Name, string calldata _eip712Version) public initializer {
        _contractOwner = msg.sender;
        _setDomainSeparator(_eip712Name, _eip712Version);
        __Nonces_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
   
    /// @dev    An authorized issuer create Program
    /// @notice _programId is the id of the program
    function createProgram( 

        uint256 _programId, uint256 _maximumTenor, uint256 _minimumTenor, uint256 _maximumAuthorizedOutstandingAmount, 
        uint256 _effectiveDate, uint256 _expiryDate, address _validator

        ) external {

    
        if (_approvedProgramCreator[msg.sender] == false)
            revert GeneralReverts.NotAuthorizedProgramCreator(msg.sender);

        _programId.isZero();
       
    
        if (_usedProgramId[_programId] == true)
            revert ProgramReverts.ExistingProgram(_programId);

        /// @dev validate effective date
        if ( _effectiveDate > _expiryDate )
          revert ProgramReverts.InvalidEffectiveDate();

        /// @dev    validate expiry date
        if  ( _expiryDate < block.timestamp )
            revert ProgramReverts.InvalidExpiryDate();

        _validator.revert__If__Address__Zero();
        
        _program[_programId] = Structs.Program(
                                    _programId, _maximumTenor, _minimumTenor, _maximumAuthorizedOutstandingAmount,
                                    _effectiveDate, _expiryDate, msg.sender, _validator
                                );    

        _usedProgramId[_programId] = true;
        emit CreateProgram(_programId, msg.sender);

        
        
    }


 
    /// @dev    function to fetch the details of a program using the program id
    /// @param      _programId is the id of the program that will be used to fetch the program details
    
    function getProgram(uint256 _programId) public view returns (Structs.Program memory)  {

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        return  _program[_programId];
        

    }
    
    /// @notice function to initialize a token
    /// @notice reverts if the token has been initialized
    /// @dev    a token can only be linked to a program
    /// @param  _tokenId is to be registered to the program
    /// @param  _programId is the program the token will be registered to
    
    function initializeToken(uint256 _tokenId, uint256 _programId, uint32 _maturityDate) external {

        _programId.isZero();
        _tokenId.isZero();
        uint256(_maturityDate).isZero();

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        if (msg.sender != _program[_programId]._owner)
            revert GeneralReverts.InvalidCaller(msg.sender);

        if (_initializeTokens._isInitialized[_tokenId] == true)
            revert ProgramReverts.TokenInitialized();

        revert__If__deauthorized(_programId);
        
        _initializeTokens._isInitialized[_tokenId] = true;
        _initializeTokens._tokenToProgram[_tokenId] = _programId;
        emit InitializeToken(_programId, _tokenId);

    }

    /**
        @notice deregister a token id from a program
        @dev    tokens can be discontinued even if they are still in circulation
        @notice Program link not cleared. To be kept as a reference to permit token operations 
                such as transfers except new issuances
     */ 
    function discontinueToken(uint256 _tokenId) external {

        if (_initializeTokens._isInitialized[_tokenId] == false)
            revert ProgramReverts.TokenNotInitialized(_tokenId);

        uint256 _programId = _initializeTokens._tokenToProgram[_tokenId];

        if (msg.sender != _program[_programId]._owner)
            revert GeneralReverts.InvalidCaller(msg.sender);

        _initializeTokens._isInitialized[_tokenId] = false;
        emit DiscontinueToken(_programId, _tokenId);
        
    }


    /**
        @notice Function gets the program details of an initialized / discontinued token
        @dev    Recall that program refs are retained upon `discontinueToken` function call
    */

    function getTokenProgram(uint256 _tokenId) external view returns (Structs.Program memory) {

        uint256 _programId = _initializeTokens._tokenToProgram[_tokenId];

        if (_programId == 0)
            revert ProgramReverts.NoProgramRef();

        return getProgram(_programId);

    }

    /// @dev    checks if a token has been initialized
    function isTokenInitialized(uint256 _tokenId) public view returns (bool) {

        return _initializeTokens._isInitialized[_tokenId];

    }
    
    /// @notice function to set the link to the document of a program
    /// @param  _programId is the id to the program
    function setDocument(uint256 _programId, bytes32 _documentHash, address[] memory _signers) external returns (bool success) {

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        if (_documentHash == bytes32(0))
            revert GeneralReverts.BytesZero();
        
        /// @dev    checks if document has been assigned index
        if (_documents._docIndex[_documentHash]._isAssigned == true)
            revert ProgramReverts.AssignedDocument();

        if (msg.sender != _program[_programId]._owner)
            revert GeneralReverts.InvalidCaller(msg.sender);

        revert__If__deauthorized(_programId);

        Structs.Document memory _document = Structs.Document(
                _documentHash, 
                _signers
        );

        _documents._programDocuments[_programId].push(_document);
        _documents._docIndex[_documentHash] = Structs.Index(true, _documents._programDocuments[_programId].length - 1);
        
        return true;

    }
    
    /// @notice function to fetch the array of links to a program using the program id
    function getProgramDocument(uint256 _programId) external view returns (Structs.Document[] memory) {

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        return _documents._programDocuments[_programId];

    }

    
    /// @notice function to set program signatures
    /// @dev    signer signs the hash as a message and provides the signature to this function
    
    function signDocument(uint256 _programId, ZEC_EIP712.DocumentHashData memory _hashData, bytes memory _signature) external returns (bool success) {

        ///@dev check if document was assigned index
        if (_documents._docIndex[_hashData.docHash]._isAssigned == false)
            revert ProgramReverts.UnassignedDocument();

        if (_documentSignatureMarker[_programId][_hashData.docHash][_signature] == true) 
            revert ProgramReverts.HashAssociatedWithDocument();
        
        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        if (_signature.length != 65)
            revert GeneralReverts.InvalidSignature();

        /// @dev    get document index
        uint256 _index = _documents._docIndex[_hashData.docHash]._index;

        if (_isDocumentSigner(msg.sender, _documents._programDocuments[_programId][_index]._signers) == false)
            msg.sender.throwCallerError();

        _useCheckedNonce(msg.sender, _hashData.nonce);

        address _recoveredAddress = _signature.verifyDocumentSignature(_EIP712Domain, _hashData); 
        
        if (_recoveredAddress != msg.sender)
            revert GeneralReverts.InvalidSigner(_recoveredAddress);

        _documentSignatures[_programId][_hashData.docHash].push(_signature);
        _documentSignatureMarker[_programId][_hashData.docHash][_signature] = true;

        return true;


    }
    
    /// @notice function to fetch the program's signatures
    function getDocumentSignature(uint256 _programId, bytes32 _hash) external view returns (bytes[] memory) {

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        return _documentSignatures[_programId][_hash];

    }

    
    /// @notice   Whitelist account in a given program 
    function whitelistAccount(uint256 _programId, address _account, Enums.AccountType _accountType) external {

        if (_account == address(0))
            revert GeneralReverts.AddressZero();

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        if ((msg.sender != _program[_programId]._owner) && (msg.sender != _program[_programId]._validator))
            revert GeneralReverts.InvalidCaller(msg.sender);

        revert__If__deauthorized(_programId);
        
        _accountWhiteLists[_programId][_account] = Structs.WhitelistData(_accountType, true);
        emit AccountWhitelist(_programId, _account);

    }

    /// @notice   dewhitelist account for a given program 
    function deWhitelistAccount(uint256 _programId, address _account) external {

         if (_account == address(0))
            revert GeneralReverts.AddressZero();

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        if ((msg.sender != _program[_programId]._owner) && (msg.sender != _program[_programId]._validator))
            revert GeneralReverts.InvalidCaller(msg.sender);

        revert__If__deauthorized(_programId);

        _mthtlc.unlockAll(_account);
        _accountWhiteLists[_programId][_account]._isWhitelisted = false;
        
        emit AccountBlacklist(_programId, _account);
    }

    /// @dev    checks whitelist status
    function isWhitelisted(uint256 _programId, address _account) external view returns (Structs.WhitelistData memory) {
        
        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);
        return _accountWhiteLists[_programId][_account];

    }

    /// @dev    get validator for a given program
    function getValidator(uint256 _programId) external view returns (address _agent) {

        if (_usedProgramId[_programId] == false)
            revert ProgramReverts.ProgramDoesNotExist(_programId);

        return _program[_programId]._validator;
    }


    /// @notice contract owner sets cptoken address
    /// @notice must not be address zero
    function setTokenContract(address _cptoken) external {

        if (msg.sender != _contractOwner)
            revert GeneralReverts.InvalidCaller(msg.sender);
        
        if (_cptoken == address(0))
            revert GeneralReverts.AddressZero();
        _cptokenAddress = _cptoken;
    }


    /// @dev    Update domain separator
    function setDomainSeparator(string calldata _eip712Name, string calldata _eip712Version) external {
        require(msg.sender == _contractOwner, "Only contract owner");
        _setDomainSeparator(_eip712Name, _eip712Version);
    }

    /// @dev    Set approval for program creation
    function setAuthorization(address _account, bool _authorize) external {

        if (msg.sender != _contractOwner)
            msg.sender.throwCallerError();
        
        _approvedProgramCreator[_account] = _authorize;
        emit SetAuthorization(_account, _authorize);
    }

    /// @dev    Checks if an account is approved to create program
    function isProgramCreatorAuthorized(address _account) public view returns (bool) {
        return _approvedProgramCreator[_account];
    }

    /// @dev    validate the signers
    function _isDocumentSigner(address _account, address[] memory _signers) internal view returns (bool) {

        for (uint256 index = 0; index < _signers.length; index++) {
            if (_account == _signers[index])
                return true;
        }

        return false;

    }
    
    /// @dev    transfer contract ownership
    function transferContractOwnerShip(address _account) external {
        _account.revert__If__Address__Zero();

        if (msg.sender != _contractOwner)
            msg.sender.throwCallerError();
        
        _contractOwner = _account;
    }

    /// @dev    set htlc
    function setHtlc(address __mthtlc) external {
         __mthtlc.revert__If__Address__Zero();
         
         if (msg.sender != _contractOwner)
            msg.sender.throwCallerError();
            
        _mthtlc = MTHTLC_V1(__mthtlc);
    }


    function revert__If__deauthorized(uint256 _programId) public {

        address _issuer = _program[_programId]._owner;
        if (isProgramCreatorAuthorized(_issuer) == false)
            revert GeneralReverts.OwnerDeauthorized();

    }
}
