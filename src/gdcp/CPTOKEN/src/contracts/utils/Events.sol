// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Enums } from "./Utils.sol";

library Events {

    event SubmitOrder(
        bytes32 indexed transactionId,
        address indexed investor,
        uint256 id,
        uint256 amount
    );

    event TransferBack(
        bytes32 indexed transactionId,
        address indexed investor,
        uint256 id,
        uint256 amount
    );

    event Settle(
        bytes32 transactionId
    );

    event PendOrder(
        bytes32 transactionId
    );


    /// @dev    Events declaration for Vaults
    event Convert(
        uint8 conversion,
        uint256 dcpId,
        uint256 fromAmount,
        uint256 toAmount
    );
    
}