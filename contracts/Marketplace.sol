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

    modifier collectionExist(address collectionOwner, uint256 collectionIndex) {
        require(
            collectionIndex > 0 &&
                userCollections[collectionOwner] >= collectionIndex,
            "Collection doesn't exist!"
        );
        _;
    }

    modifier tokenOwner(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId
    ) {
        Collection _collection = collection[collectionOwner][collectionIndex];
        require(
            _collection.ownerOf(tokenId) == msg.sender,
            "Sender is not owner of token!"
        );
        _;
    }

    mapping(address => mapping(uint256 => Collection)) private collection;
    mapping(address => uint256) private userCollections;
    //CONTRACT ADDRESS -> ITERATON NUMBER -> OFFER STRUCT
    mapping(Collection => mapping(uint256 => Offer[])) offers;
    //CONTRACT ADDRESS -> TOKENID -> ITEM
    mapping(Collection => mapping(uint256 => Item)) listedItems;

    struct Item {
        uint256 price;
        address seller;
    }

    struct Offer {
        address offerFrom;
        uint256 offeredPrice;
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
    )
        external
        payable
        collectionExist(collectionOwner, collectionIndex)
        tokenOwner(collectionOwner, collectionIndex, tokenId)
    {
        require(msg.value == listFee, "Fee doesn't match!");

        Collection _collection = collection[collectionOwner][collectionIndex];
        address contractAddress = address(this);

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

    function makeOffer(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId
    )
        external
        payable
        collectionExist(collectionOwner, collectionIndex)
        tokenOwner(collectionOwner, collectionIndex, tokenId)
    {
        require(msg.value > 0, "You need to send sum bigger than 0.");

        Collection _collection = collection[collectionOwner][collectionIndex];
        offers[_collection][tokenId].push(Offer(msg.sender, msg.value));
    }

    function cancelOffer(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId,
        uint256 index
    ) external collectionExist(collectionOwner, collectionIndex) {
        Collection _collection = collection[collectionOwner][collectionIndex];

        require(
            _collection.ownerOf(tokenId) == msg.sender || msg.sender == owner(),
            "Sender is not owner of token!"
        );

        delete offers[_collection][tokenId][index];
    }

    function approveOffer(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId,
        uint256 index
    )
        external
        collectionExist(collectionOwner, collectionIndex)
        tokenOwner(collectionOwner, collectionIndex, tokenId)
        nonReentrant
    {
        Collection _collection = collection[collectionOwner][collectionIndex];
        Offer[] storage _offers = offers[_collection][tokenId];

        require(
            _offers.length > index && _offers[index].offerFrom != address(0),
            "Offer doesn't exist!"
        );

        payable(msg.sender).transfer(_offers[index].offeredPrice);
    }

    function withrawFee() external onlyOwner {
        payable(owner()).transfer(collectedFee);
        collectedFee = 0;
    }
}
