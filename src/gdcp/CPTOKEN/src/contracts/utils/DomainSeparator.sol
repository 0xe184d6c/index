// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import { ZEC_EIP712 } from "./ZEC_EIP712.sol";

abstract contract DomainSeparator {

    ZEC_EIP712.EIP712Domain internal _EIP712Domain;

    function _setDomainSeparator(string calldata _eip712Name, string calldata _eip712Version) internal {
        _EIP712Domain = ZEC_EIP712.EIP712Domain (_eip712Name, _eip712Version, block.chainid, address(this));
    }


    function getDomainSeparator() public view returns (ZEC_EIP712.EIP712Domain memory) {
        return _EIP712Domain;
    }

}