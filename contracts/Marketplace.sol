// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Collection.sol";

error CollectionDoesNotExist(address collectionOwner, uint256 collectionIndex);
error NotTokenOwner(address sender, uint256 tokenId);
error ListingFeeNotMatch(uint256 fee);
error TokenNotApproved();
error CannotBuyOwnToken();
error ItemAlreadyListed(uint256 tokenId);
error ItemNotListed(uint256 tokenId);
error SenderValueNotEqualToPrice(address sender, uint256 _val);
error OfferPriceCannotBeZero(uint256 price);
error CannotMakeOfferToOwnableToken();
error OfferDoesNotExist();
error SenderHasNoPermissions(address sender);
error NothingToWithdraw();
error ItemPriceMustGreaterThanZero();
error IndexDoesNotExist();

contract Marketplace is Ownable, ReentrancyGuard {
    uint256 public listFee = 0.02 ether;
    uint256 private lockedAmount;

    event CollectionCreated(string name, string description);
    event ItemListed(uint256 _tokenId, address from, address to);
    event ItemBought(
        uint256 _tokenId,
        address buyer,
        address seller,
        uint256 price
    );
    event OfferCreated(address from, address to, uint256 offeredPrice);
    event OfferCanceled(address from);
    event OfferApproved(address from, address to, uint256 offeredPrice);

    modifier collectionExist(address collectionOwner, uint256 collectionIndex) {
        if (
            !(collectionIndex > 0 &&
                userCollections[collectionOwner] >= collectionIndex)
        ) {
            revert CollectionDoesNotExist(collectionOwner, collectionIndex);
        }
        _;
    }

    modifier tokenOwner(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId
    ) {
        Collection _collection = collection[collectionOwner][collectionIndex];

        if (_collection.ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner(msg.sender, tokenId);
        }
        _;
    }

    //USER ADDRESS => INDEX => COLLECTION.
    mapping(address => mapping(uint256 => Collection)) private collection;
    //USER ADDRESS => NUMBER OF COLLECTION HE CREATED.
    mapping(address => uint256) private userCollections;
    //CONTRACT ADDRESS -> TOKENID -> OFFER STRUCT.
    mapping(Collection => mapping(uint256 => Offer[])) public offers;
    //USER ADDRESS => NONE-USER-COLLECTIONS.
    mapping(address => ExternalToken[]) public userBoughtTokens;
    //Collection => tokenId => bool(listed or not.)
    mapping(Collection => mapping(uint256 => ItemStatus))
        public listedItemStatus;
    Item[] public listedItems;

    struct ExternalToken {
        address collectionAddress;
        uint256 tokenId;
    }

    struct ItemStatus {
        bool isListed;
        uint256 price;
    }

    struct Item {
        address collectionAddress;
        uint256 tokenId;
        uint256 price;
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

    function getUserCollectionTotal(address _addr)
        public
        view
        returns (uint256)
    {
        return userCollections[_addr];
    }

    function getCollection(address _addr, uint256 index)
        external
        view
        returns (Collection)
    {
        return collection[_addr][index];
    }

    function getTotalBoughtTokens(address _addr)
        external
        view
        returns (uint256)
    {
        return userBoughtTokens[_addr].length;
    }

    function getTotalListedItems() external view returns (uint256) {
        return listedItems.length;
    }

    function getTotalOffersByToken(Collection _collection, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return offers[_collection][tokenId].length;
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
        if (msg.value != listFee) {
            revert ListingFeeNotMatch(msg.value);
        }
        if (price == 0) {
            revert ItemPriceMustGreaterThanZero();
        }

        Collection _collection = collection[collectionOwner][collectionIndex];
        address contractAddress = address(this);

        if (
            !_collection.isApprovedForAll(msg.sender, contractAddress) &&
            _collection.getApproved(tokenId) != contractAddress
        ) {
            revert TokenNotApproved();
        }
        if (listedItemStatus[_collection][tokenId].isListed) {
            revert ItemAlreadyListed(tokenId);
        }

        listedItems.push(Item(address(_collection), tokenId, price));
        listedItemStatus[_collection][tokenId] = ItemStatus(true, price);

        emit ItemListed(tokenId, msg.sender, contractAddress);
    }

    function buyItem(uint256 item, uint256 indexOfBoughtToken)
        external
        payable
        nonReentrant
    {
        if (item >= listedItems.length) {
            revert IndexDoesNotExist();
        }

        Item memory _item = listedItems[item];
        Collection _collection = Collection(_item.collectionAddress);
        address _tokenOwner = _collection.ownerOf(_item.tokenId);
        address collectionOwner = _collection.owner();

        if (msg.value != _item.price) {
            revert SenderValueNotEqualToPrice(msg.sender, msg.value);
        }
        if (msg.sender == _tokenOwner) {
            revert CannotBuyOwnToken();
        }

        payable(_tokenOwner).transfer(msg.value);

        _collection.transferFrom(_tokenOwner, msg.sender, _item.tokenId);

        delete listedItemStatus[_collection][_item.tokenId];
        listedItems[item] = listedItems[listedItems.length - 1];
        listedItems.pop();

        if (_tokenOwner == collectionOwner) {
            userBoughtTokens[msg.sender].push(
                ExternalToken(address(_collection), _item.tokenId)
            );
        } else {
            ExternalToken[] storage _userExternalTokens = userBoughtTokens[
                _tokenOwner
            ];

            if (
                _userExternalTokens.length <= indexOfBoughtToken ||
                (_userExternalTokens[indexOfBoughtToken].collectionAddress !=
                    address(_collection) ||
                    _userExternalTokens[indexOfBoughtToken].tokenId !=
                    _item.tokenId)
            ) {
                revert IndexDoesNotExist();
            }

            _userExternalTokens[indexOfBoughtToken] = _userExternalTokens[
                _userExternalTokens.length - 1
            ];
            _userExternalTokens.pop();

            if (msg.sender != collectionOwner) {
                userBoughtTokens[msg.sender].push(
                    ExternalToken(address(_collection), _item.tokenId)
                );
            }
        }

        emit ItemBought(_item.tokenId, msg.sender, _tokenOwner, _item.price);
    }

    function makeOffer(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId
    ) external payable collectionExist(collectionOwner, collectionIndex) {
        if (msg.value == 0) {
            revert OfferPriceCannotBeZero(msg.value);
        }

        Collection _collection = collection[collectionOwner][collectionIndex];

        //Expected to throw error if token id doesn't exist.
        address _tokenOwner = _collection.ownerOf(tokenId);

        if (_tokenOwner == msg.sender) {
            revert CannotMakeOfferToOwnableToken();
        }

        offers[_collection][tokenId].push(Offer(msg.sender, msg.value));

        lockedAmount += msg.value;

        emit OfferCreated(msg.sender, _tokenOwner, msg.value);
    }

    function cancelOffer(
        address collectionOwner,
        uint256 collectionIndex,
        uint256 tokenId,
        uint256 index
    ) external collectionExist(collectionOwner, collectionIndex) nonReentrant {
        Collection _collection = collection[collectionOwner][collectionIndex];
        Offer[] storage _offers = offers[_collection][tokenId];

        if (
            !(_offers.length > index && _offers[index].offerFrom != address(0))
        ) {
            revert OfferDoesNotExist();
        }
        if (
            _collection.ownerOf(tokenId) != msg.sender &&
            msg.sender != _offers[index].offerFrom
        ) {
            revert SenderHasNoPermissions(msg.sender);
        }

        payable(_offers[index].offerFrom).transfer(_offers[index].offeredPrice);

        unchecked {
            lockedAmount -= _offers[index].offeredPrice;
        }

        _offers[index] = _offers[_offers.length - 1];
        _offers.pop();

        emit OfferCanceled(msg.sender);
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

        if (
            !(_offers.length > index && _offers[index].offerFrom != address(0))
        ) {
            revert OfferDoesNotExist();
        }

        address _offeredFrom = _offers[index].offerFrom;

        payable(msg.sender).transfer(_offers[index].offeredPrice);

        unchecked {
            lockedAmount -= _offers[index].offeredPrice;
        }

        _collection.transferFrom(msg.sender, _offeredFrom, tokenId);

        emit OfferApproved(
            msg.sender,
            _offeredFrom,
            _offers[index].offeredPrice
        );

        _offers[index] = _offers[_offers.length - 1];
        _offers.pop();
    }

    function withrawFee() external onlyOwner {
        uint256 balance = address(this).balance;

        if (balance == 0) {
            revert NothingToWithdraw();
        }

        payable(owner()).transfer(balance - lockedAmount);
    }
}
