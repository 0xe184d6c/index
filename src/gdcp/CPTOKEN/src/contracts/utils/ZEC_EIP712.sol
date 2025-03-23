pragma solidity 0.8.20;



library ZEC_EIP712 {

   
    struct EIP712Domain {

        /**
        
            @dev    the EIP712Domain standard parameter

        */

        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;

    }

    struct AuthenticationData {

        bytes32 keyAuth;
        uint256 nonce;

    }

    struct DocumentHashData {

        bytes32 docHash;
        uint256 nonce;

    }

    struct AdministratorAuth {

        uint256 timeSigned;
        uint256 nonce;

    }

    struct ApproveBuyBackRefund {

        uint256 buyBackExpiration;
        uint256 nonce;
        uint256 amount;
        bytes32 buyBackId;
        address investor;

    }

    /// @dev define the domain type hash

    bytes32 constant private EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev    define the Authentication Data  type hash
    bytes32 constant private AUTHENTICATION_DATA_TYPEHASH = keccak256(
        "AuthenticationData(bytes32 keyAuth,uint256 nonce)"
    );

    /// @dev   type hash for the DocumentHash data
    bytes32 constant private DOCUMENTHASH_DATA_TYPEHASH = keccak256(
        "DocumentHashData(bytes32 docHash,uint256 nonce)"
    );

    /// @dev   type hash for administrator's auth
    bytes32 constant private ADMINISTRATOR_AUTH_TYPEHASH = keccak256(
        "AdministratorAuth(uint256 timeSigned,uint256 nonce)"
    );


    /// @dev   type hash for buyback refund approval
    bytes32 constant private APPROVE_BUYBACK_REFUND_TYPEHASH = keccak256(
        "ApproveBuyBackRefund(uint256 buyBackExpiration,uint256 nonce,uint256 amount,bytes32 buyBackId,address investor)"
    );




    /**
        @dev    function to generate the domain separator
     */
    function hashEIP712Domain(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {

        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );

    }


    /**
        @dev    function to generate the hash of the data to be signed
     */
    function hashAuthenticationData(AuthenticationData memory authenticationData) internal pure returns (bytes32) {

        return keccak256(
            abi.encode(
                AUTHENTICATION_DATA_TYPEHASH,
                authenticationData.keyAuth,
                authenticationData.nonce
            )
        );

    }


    /// @dev    function to generate the hash of the data to be signed
    function hashDocumentHashData(DocumentHashData memory documentHashData) internal pure returns (bytes32) {

        return keccak256(
            abi.encode(
                DOCUMENTHASH_DATA_TYPEHASH,
                documentHashData.docHash,
                documentHashData.nonce
            )
        );

    }



    /// @dev    function to generate the hash of the data to be signed
    function hashAdministratorAuthData(AdministratorAuth memory authenticationData) internal pure returns (bytes32) {

        return keccak256(
            abi.encode(
                ADMINISTRATOR_AUTH_TYPEHASH,
                authenticationData.timeSigned,
                authenticationData.nonce
            )
        );

    }

    /// @dev    function to generate the hash of the data to be signed
    function hashApproveBuyBackRefundData(ApproveBuyBackRefund memory approveBuyBackRefund) internal pure returns (bytes32) {

        return keccak256(
            abi.encode(
                APPROVE_BUYBACK_REFUND_TYPEHASH,
                approveBuyBackRefund.buyBackExpiration,
                approveBuyBackRefund.nonce,
                approveBuyBackRefund.amount,
                approveBuyBackRefund.buyBackId,
                approveBuyBackRefund.investor
            )
        );

    }


     /**
        @dev    compute the R S V value from the signature
    */

    function _split(bytes memory _signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {

        require(_signature.length == 65, "Error: invalid Signature"); // invalid signature length

        assembly {

            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
           

        }

    }

    function _validateErecover(bytes memory _signature, bytes32 _ethHash) internal pure returns (address) {

        (bytes32 r, bytes32 s, uint8 v) = _split(_signature);

         if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert ("InvalidSignatureS");
        }
        if (v != 27 && v != 28) {
            revert("InvalidSignatureV");
        }

        require (ecrecover(_ethHash, v, r, s) != address(0), "Error: invalid signer");
        return ecrecover(_ethHash, v, r, s);

    }

    /// @notice verify the signer of a signature using the prefixed signed hash
    /// @param _signature The data generated from the signed Typed data 
    /// @return the address of the signer

    function verifyAuthenticationSignature(bytes memory _signature, EIP712Domain memory eip712Domain, AuthenticationData memory authenticationData) internal pure returns (address) {

        bytes32 _ethHash = keccak256(abi.encodePacked(

                            "\x19\x01",
                            hashEIP712Domain(eip712Domain),
                            hashAuthenticationData(authenticationData)

                        ));

        return _validateErecover(_signature, _ethHash);

    }
   

     function verifyDocumentSignature(bytes memory _signature, EIP712Domain memory eip712Domain, DocumentHashData memory documentHashData) internal pure returns (address) {

        bytes32 _ethHash = keccak256(abi.encodePacked(

                            "\x19\x01",
                            hashEIP712Domain(eip712Domain),
                            hashDocumentHashData(documentHashData)

                        ));

        return _validateErecover(_signature, _ethHash);

    }


    function verifyAdministratorSignature(bytes memory _signature, EIP712Domain memory eip712Domain, AdministratorAuth memory administratorAuth) internal pure returns (address) {

        bytes32 _ethHash = keccak256(abi.encodePacked(

                            "\x19\x01",
                            hashEIP712Domain(eip712Domain),
                            hashAdministratorAuthData(administratorAuth)

                        ));

        return _validateErecover(_signature, _ethHash);

    }

    function verifyApproveBuyBackSignature(bytes memory _signature, EIP712Domain memory eip712Domain, ApproveBuyBackRefund memory approveBuyBackRefund) internal pure returns (address) {
        
        bytes32 _ethHash = keccak256(abi.encodePacked(

                            "\x19\x01",
                            hashEIP712Domain(eip712Domain),
                            hashApproveBuyBackRefundData(approveBuyBackRefund)

                        ));

        return _validateErecover(_signature, _ethHash);
    }

}