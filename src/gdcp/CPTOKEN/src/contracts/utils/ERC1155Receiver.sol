pragma solidity ^0.8.17;

import { IERC1155Receiver  } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract ERC1155Receiver is IERC1155Receiver {

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external pure override returns(bytes4){
        return this.onERC1155Received.selector;
    }

    /**
        *   @inheritdoc IERC1155Receiver
        *   @dev contract implements the batch ECR1155Receiver. This is required for ERC1155 tokens to be sent to this contract
    */
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external pure override returns(bytes4){
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool){
        return (
              interfaceId == this.supportsInterface.selector ||
              interfaceId == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector
          );
    }

}