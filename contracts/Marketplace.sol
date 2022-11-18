// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Collection.sol";

contract Marketplace is Ownable, ReentrancyGuard {
    uint256 public listFee = 0.02 ether;
    uint256 public collectedFee;

    event CollectionCreated(string name, string description);
    event ItemListed(uint256 _tokenId, address from, address to);
    event ItemBought(
        uint256 _tokenId,
        address buyer,
        address seller,
        uint256 price
    );

    modifier collectionExist(address collectionOwner, uint256 index) {
        require(
            index > 0 && userCollections[collectionOwner] >= index,
            "Collection doesn't exist!"
        );
        _;
    }

    mapping(address => mapping(uint256 => Collection)) private collection;
    mapping(address => uint256) private userCollections;
    mapping(Collection => mapping(uint256 => Item)) listedItems;

    struct Item {
        uint256 price;
        address seller;
    }

    struct Offer {
        address offerFrom;
        uint256 offeredPrice;
        uint256 tokenId;
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

        emit CollectionCreated(name, description);
    }

    function getUserCollectionTotal() public view returns (uint256) {
        return userCollections[msg.sender];
    }

    function getCollection(uint256 index) external view returns (Collection) {
        return collection[msg.sender][index];
    }

    function listItem(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId,
        uint256 price
    ) external payable collectionExist(collectionOwner, collectionIndex) {
        require(msg.value == listFee, "Fee doesn't match!");

        Collection _collection = collection[collectionOwner][collectionIndex];
        address contractAddress = address(this);

        require(
            _collection.ownerOf(tokenId) == msg.sender,
            "Only owner can list token!"
        );
        require(
            _collection.isApprovedForAll(msg.sender, address(this)),
            "Token not approved for marketplace!"
        );
        require(
            listedItems[_collection][tokenId].price == 0,
            "Item already listed!"
        );

        listedItems[_collection][tokenId] = Item(price, payable(msg.sender));

        collectedFee += msg.value;

        emit ItemListed(tokenId, msg.sender, contractAddress);
    }

    function buyItem(
        uint256 tokenId,
        uint256 collectionIndex,
        address collectionOwner
    )
        external
        payable
        nonReentrant
        collectionExist(collectionOwner, collectionIndex)
    {
        Collection _collection = collection[collectionOwner][collectionIndex];
        Item memory item = listedItems[_collection][tokenId];

        require(item.price > 0, "Item doesn't exist!");
        require(msg.value == item.price, "Sum doesn't match price of item!");

        payable(item.seller).transfer(msg.value);

        _collection.transferFrom(
            _collection.ownerOf(tokenId),
            msg.sender,
            tokenId
        );

        delete (listedItems[_collection][tokenId]);

        emit ItemBought(tokenId, msg.sender, item.seller, item.price);
    }

    function withrawFee() external onlyOwner {
        payable(owner()).transfer(collectedFee);
        collectedFee = 0;
    }
}
