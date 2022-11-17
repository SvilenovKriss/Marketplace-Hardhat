// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Collection is ERC721URIStorage {
    using Counters for Counters.Counter;

    address public owner;
    Counters.Counter private tokenId;

    constructor(
        string memory name,
        string memory description,
        address _owner
    ) ERC721(name, description) {
        owner = _owner;
    }

    function mint(string memory _tokenURI) external returns (uint256) {
        require(msg.sender == owner, "Caller is not owner!");

        tokenId.increment();

        uint256 currentTokenId = tokenId.current();

        _safeMint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, _tokenURI);

        return currentTokenId;
    }
}
