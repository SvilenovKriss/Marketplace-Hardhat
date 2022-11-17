// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Collection.sol";

contract Marketplace is Ownable, ReentrancyGuard {
    uint256 public feeAmount = 0.02 ether;
    uint256 private collectedFee;

    event LogCollectionCreated(string name, string description);
    event LogListedItem(uint256 _tokenId, address from, address to);
    event LogBoughtItem(
        uint256 _tokenId,
        address buyer,
        address seller,
        uint256 price
    );

    mapping(address => mapping(uint256 => Collection)) private collection;
    mapping(address => uint256) private userCollections;
    mapping(uint256 => Item) public listedItems;
    uint256 private itemCount;

    struct Item {
        uint256 tokenId;
        uint256 price;
        IERC721 _collection;
        address owner;
        address seller;
        bool isSold;
    }

    function createCollection(string memory name, string memory description)
        external
    {
        userCollections[msg.sender]++;
        uint256 collectionNum = userCollections[msg.sender];
        collection[msg.sender][collectionNum] = new Collection(
            name,
            description,
            msg.sender
        );

        emit LogCollectionCreated(name, description);
    }

    function getUserCollectionTotal() public view returns (uint256) {
        return userCollections[msg.sender];
    }

    function getCollection(uint256 index) external view returns (Collection) {
        return collection[msg.sender][index];
    }

    function listItem(
        uint256 index,
        uint256 tokenId,
        uint256 price
    ) external {
        require(
            index > 0 && userCollections[msg.sender] >= index,
            "Collection doesn't exist!"
        );

        Collection currentCollection = collection[msg.sender][index];
        address contractAddress = address(this);

        currentCollection.transferFrom(msg.sender, contractAddress, tokenId);

        itemCount++;
        listedItems[itemCount] = Item(
            tokenId,
            price,
            currentCollection,
            payable(msg.sender),
            payable(contractAddress),
            false
        );

        emit LogListedItem(tokenId, msg.sender, contractAddress);
    }

    function buyItem(uint256 listedItemIndex, uint256 collectionIndex)
        external
        payable
        nonReentrant
    {
        require(
            itemCount > 0 && listedItemIndex <= itemCount,
            "Item doesn't exist!"
        );

        Item storage item = listedItems[listedItemIndex];

        require(!item.isSold, "Item is already sold!");
        require(msg.value == item.price, "Sum doesn't match price of item!");
        require(
            collectionIndex > 0 &&
                collectionIndex <= userCollections[item.owner],
            "Collection doesn't exist!"
        );

        uint256 tokenId = item.tokenId;
        Collection _collection = collection[item.owner][collectionIndex];

        payable(item.owner).transfer(msg.value);

        item.isSold = true;

        _collection.transferFrom(address(this), msg.sender, tokenId);

        emit LogBoughtItem(tokenId, msg.sender, item.owner, item.price);
    }

    function getCollectedFee() external view returns (uint256) {
        return collectedFee;
    }

    function withrawFee() external onlyOwner {
        payable(owner()).transfer(collectedFee);
    }
}
