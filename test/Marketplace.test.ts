import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { Collection, Collection__factory, Marketplace, Marketplace__factory } from "../typechain-types";

interface Wallet {
    address: string;
}

describe("Marketplace", function () {
    const fee = ethers.utils.parseEther("0.02");
    const price = ethers.utils.parseEther("0.01");
    const tokenId = 1;
    const collectionIndex = 1;
    const offerIndex = 0;

    async function deployMarketplaceWithCollectionFixture() {
        let owner: Wallet;
        let addrOne: Wallet;
        let addrTwo: Wallet;

        [owner, addrOne, addrTwo] = await ethers.getSigners();
        let marketplaceFactory: Marketplace__factory = await ethers.getContractFactory("Marketplace");

        let marketplace: Marketplace = await marketplaceFactory.deploy();

        await marketplace.deployed();

        await marketplace.createCollection("Monkey", "new monkey collection");

        let collectionFactory: Collection__factory = await ethers.getContractFactory("Collection");
        const collectionAddress = await marketplace.getCollection(collectionIndex);

        const collection = await collectionFactory.attach(collectionAddress);

        await collection.mint('DCA');
        await collection.setApprovalForAll(marketplace.address, true);

        return { owner, addrOne, addrTwo, marketplace, collection };
    }

    describe('createCollection', async () => {
        it('Should new create collection', async () => {
            const { marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            expect(await marketplace.getUserCollectionTotal()).to.equal(1);
            expect(await marketplace.getCollection(collectionIndex)).to.not.equal('0x0000000000000000000000000000000000000000');
        });
        it('Should throw with error: "Caller is not owner!"', async () => {
            const { addrOne, collection } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await expect(collection.connect(secondAddressSigner).mint('DCA 2')).to.revertedWith('Caller is not owner!');
        });
    });


    describe('listItem', async () => {
        it('Should throw error: "ERC721: invalid token ID"', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const invalidTokenId = 2;

            await expect(marketplace.listItem(owner.address, collectionIndex, invalidTokenId, price)).to.revertedWith('ERC721: invalid token ID');
        });
        it('Modifier collectionExist should throw error"', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const invalidCollectionIndex = 2;

            await expect(marketplace.listItem(owner.address, invalidCollectionIndex, tokenId, price)).to.be.revertedWithCustomError(marketplace, `CollectionDoesNotExist`);
        });
        it('Modifier tokenOwner should throw error"', async () => {
            const { owner, addrOne, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await expect(marketplace.connect(secondAddressSigner).listItem(owner.address, 1, 1, 123)).to.be.revertedWithCustomError(marketplace, `NotTokenOwner`);
        });
        it('Should throw error: "ListingFeeNotMatch"', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: ethers.utils.parseEther("0.01") }))
                .to.be.revertedWithCustomError(marketplace, 'ListingFeeNotMatch');
        });
        it('Should throw error: "ItemPriceMustGreaterThanZero"', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.listItem(owner.address, collectionIndex, tokenId, 0, { value: fee }))
                .to.be.revertedWithCustomError(marketplace, 'ItemPriceMustGreaterThanZero');
        });
        it('Should throw error: "TokenNotApproved"', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const newCollectionIndex = 2;
            await marketplace.createCollection("Monkey", "new monkey collection");

            let collectionFactory: Collection__factory = await ethers.getContractFactory("Collection");
            const collectionAddress = await marketplace.getCollection(newCollectionIndex);

            const collection = await collectionFactory.attach(collectionAddress);

            await collection.mint('New test token');

            await expect(marketplace.listItem(owner.address, 2, tokenId, price, { value: fee }))
                .to.be.revertedWithCustomError(marketplace, 'TokenNotApproved');
        });
        it('Should list item successfully', async () => {
            const { owner, marketplace, collection } = await loadFixture(deployMarketplaceWithCollectionFixture);

            expect(await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee })).to.emit(marketplace, 'ItemListed');
            expect(await marketplace.listedItems(collection.address, collectionIndex)).to.equal(price);
        });
        it('Should throw error: "ItemAlreadyListed"', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee });

            await expect(marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee }))
                .to.be.revertedWithCustomError(marketplace, 'ItemAlreadyListed');
        });
    });
    describe('buyItem', async () => {
        it('Should throw error: ItemNotListed', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.buyItem(owner.address, 1, 1)).to.be.revertedWithCustomError(marketplace, 'ItemNotListed');
        });
        it('Should throw error: SenderValueNotEqualToPrice', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee });

            await expect(marketplace.buyItem(owner.address, collectionIndex, tokenId)).to.be.revertedWithCustomError(marketplace, 'SenderValueNotEqualToPrice');
        });
        it('Should throw error: CannotBuyOwnToken', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee });

            await expect(marketplace.buyItem(owner.address, collectionIndex, tokenId, { value: price })).to.be.revertedWithCustomError(marketplace, 'CannotBuyOwnToken');
        });
        it('Should buy token successfully', async () => {
            const { owner, addrOne, marketplace, collection } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee });

            expect(await marketplace.connect(secondAddressSigner).buyItem(owner.address, collectionIndex, tokenId, { value: price })).to.emit(marketplace, 'ItemBought');
            expect(await ethers.provider.getBalance(marketplace.address)).to.equal(fee);
            expect(await collection.ownerOf(tokenId)).to.equal(addrOne.address);
            expect(await marketplace.listedItems(collection.address, collectionIndex)).to.equal(0);
        });
    });
    describe('makeOffer', async () => {
        it('Should throw error: OfferPriceCannotBeZero', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.makeOffer(owner.address, collectionIndex, tokenId)).to.be.revertedWithCustomError(marketplace, 'OfferPriceCannotBeZero');
        });
        it('Should throw error: CannotMakeOfferToOwnableToken', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.makeOffer(owner.address, collectionIndex, tokenId, { value: price })).to.be.revertedWithCustomError(marketplace, 'CannotMakeOfferToOwnableToken');
        });
        it('Should throw error: CannotOfferToListedItem', async () => {
            const { owner, addrOne, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee });

            await expect(marketplace.connect(secondAddressSigner).makeOffer(owner.address, collectionIndex, tokenId, { value: price })).to.be.revertedWithCustomError(marketplace, 'CannotOfferToListedItem');
        });
        it('Should make offer successfully', async () => {
            const { owner, addrOne, marketplace, collection } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await expect(marketplace.connect(secondAddressSigner).makeOffer(owner.address, collectionIndex, tokenId, { value: price })).to.emit(marketplace, 'OfferCreated');
            expect((await marketplace.offers(collection.address, tokenId, offerIndex)).offerFrom).to.equal(addrOne.address);
        });
    });
    describe('cancelOffer', async () => {
        it('Should throw error: OfferDoesNotExist', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.cancelOffer(owner.address, collectionIndex, tokenId, offerIndex)).to.be.revertedWithCustomError(marketplace, 'OfferDoesNotExist');
        });
        it('Should throw error: SenderHasNoPermissions', async () => {
            const { owner, addrOne, addrTwo, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);
            const thirdAddressSigner = await ethers.getSigner(addrTwo.address);

            await marketplace.connect(secondAddressSigner).makeOffer(owner.address, collectionIndex, tokenId, { value: price });

            await expect(marketplace.connect(thirdAddressSigner).cancelOffer(owner.address, collectionIndex, tokenId, offerIndex)).to.be.revertedWithCustomError(marketplace, 'SenderHasNoPermissions');
        });
        it('Should cancel offer successfully', async () => {
            const { owner, addrOne, marketplace, collection } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await marketplace.connect(secondAddressSigner).makeOffer(owner.address, collectionIndex, tokenId, { value: price });

            expect(await marketplace.cancelOffer(owner.address, collectionIndex, tokenId, offerIndex)).to.emit(marketplace, 'OfferCanceled');
            expect(await ethers.provider.getBalance(marketplace.address)).to.equal(0);
        });
    });
    describe('approveOffer', async () => {
        it('Should throw error: OfferDoesNotExist', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.approveOffer(owner.address, collectionIndex, tokenId, offerIndex)).to.be.revertedWithCustomError(marketplace, 'OfferDoesNotExist');
        });
        it('Should approve offer successfully', async () => {
            const { owner, addrOne, marketplace, collection } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await marketplace.connect(secondAddressSigner).makeOffer(owner.address, collectionIndex, tokenId, { value: price });

            expect(await marketplace.approveOffer(owner.address, collectionIndex, tokenId, offerIndex)).to.emit(marketplace, 'OfferApproved');
            expect(await collection.ownerOf(tokenId)).to.equal(addrOne.address);
        });
    });
    describe('withrawFee', async () => {
        it('Should throw error: OfferDoesNotExist', async () => {
            const { addrOne, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);
            const secondAddressSigner = await ethers.getSigner(addrOne.address);

            await expect(marketplace.connect(secondAddressSigner).withrawFee()).to.be.revertedWith('Ownable: caller is not the owner');
        });
        it('Should throw error: NothingToWithdraw', async () => {
            const { addrOne, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await expect(marketplace.withrawFee()).to.be.revertedWithCustomError(marketplace, 'NothingToWithdraw');
        });
        it('Shoul withdraw fees successfully', async () => {
            const { owner, marketplace } = await loadFixture(deployMarketplaceWithCollectionFixture);

            await marketplace.listItem(owner.address, collectionIndex, tokenId, price, { value: fee });

            expect(await ethers.provider.getBalance(marketplace.address)).to.equal(fee);

            await marketplace.withrawFee();

            expect(await ethers.provider.getBalance(marketplace.address)).to.equal(0)
        });
    });
});