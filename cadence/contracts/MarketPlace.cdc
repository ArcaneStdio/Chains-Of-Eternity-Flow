import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import NonFungibleToken from 0x631e88ae7f1d7c20
import ItemManager from 0xf8d6e0586b0a20c7

access(all) contract MarketPlace {

    // Events to log listing and purchase actions
    access(all) event Listed(itemID: UInt64, seller: Address, price: UFix64)
    access(all) event Purchased(itemID: UInt64, seller: Address, buyer: Address, price: UFix64)
    access(all) event Cancelled(itemID: UInt64, seller: Address)

    // The percentage fee (0.0 to 1.0) taken by marketplace on each sale
    access(all) let feePercent: UFix64

    // Marketplace owner (deployer) who receives fees
    access(all) var owner: Address

    // A simple struct representing a listing for an NFT
    access(all) struct Listing {
        access(all) let id: UInt64
        access(all) let seller: Address
        access(all) let price: UFix64
        access(all) let tokenID: UInt64

        init(id: UInt64, seller: Address, price: UFix64, tokenID: UInt64) {
            self.id = id
            self.seller = seller
            self.price = price
            self.tokenID = tokenID
        }
    }

    // Storage for active listings: mapping listingID -> Listing
    access(all) var itemsForSale: {UInt64: Listing}

    // A private NFT collection to hold all listed NFTs
    access(contract) var saleCollection: @{NonFungibleToken.Collection}

    // Auto-incrementing ID for listings
    access(contract) var nextListingID: UInt64

    /// Initialize contract: set owner and fee, prepare empty storage
    init(feePercent: UFix64) {
        self.owner = self.account.address
        self.feePercent = feePercent
        self.itemsForSale = {}
        self.nextListingID = 1
        // Create an empty collection to hold NFTs for sale
        self.saleCollection <- ItemManager.createEmptyCollection(nftType: Type<@ItemManager.NFT>())
    }

    /// List an NFT for sale at a fixed price (in FLOW). 
    /// The seller must call this and pass in their NFT and desired price.
    access(all) fun listItem(tokenID: UInt64, price: UFix64, seller: Address) {
        pre {
            price > 0.0: "Price must be positive"
        }
        let signer = getAccount(seller)
        let sellerCollection = signer.storage.borrow<&ItemManager.Collection>(from: ItemManager.CollectionStoragePath)
        ?? panic("Could not borrow seller collection")
        // Withdraw the NFT from the seller's collection
        let nft <- sellerCollection.withdraw(withdrawID: tokenID)
        // Deposit the NFT into the marketplace's sale collection
        self.saleCollection.deposit(token: <- nft)
        // Create and store a new Listing
        let listingID = self.nextListingID
        self.itemsForSale[listingID] = Listing(
            id: listingID, 
            seller: seller, 
            price: price, 
            tokenID: tokenID
        )
        self.nextListingID = listingID + 1
        emit Listed(itemID: listingID, seller: seller, price: price)
    }

    /// Purchase a listed NFT by ID. Buyer provides a FlowToken vault with the payment.
    /// Transfers the NFT to buyer and splits payment between seller and owner.
    access(all) fun purchase(listingID: UInt64, buyer: Address, 
                     buyerCollection: &ItemManager.Collection, 
                     payment: @{FungibleToken.Vault}) {
        // Find and remove the listing
        let listing = self.itemsForSale.remove(key: listingID) 
                        ?? panic("Listing not found")
        // Ensure payment is exactly the price
        let price = listing.price
        if payment.balance < price {
            panic("Insufficient payment for purchase")
        }
        // Calculate fee and seller payout
        let fee = price * self.feePercent
        let sellerAmount = price - fee

        // Withdraw fee and send to contract owner
        let ownerAccount = getAccount(self.owner)
        let ownerVaultRef = ownerAccount
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Owner's FlowToken receiver not found")
        let feeVault <- payment.withdraw(amount: fee)
        ownerVaultRef.deposit(from: <- feeVault)

        // Withdraw remaining to seller and deposit to seller's vault
        let sellerAccount = getAccount(listing.seller)
        let sellerVaultRef = sellerAccount
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Seller's FlowToken receiver not found")
        let sellerVault <- payment.withdraw(amount: sellerAmount)
        sellerVaultRef.deposit(from: <- sellerVault)

        // Any extra tokens in 'payment' (if overpaid) are returned to buyer
        if payment.balance > 0.0 {
            let buyerVaultRef = getAccount(buyer)
                .capabilities
                .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("Buyer's FlowToken receiver not found")
            buyerVaultRef.deposit(from: <- payment)
        } else {
            destroy payment
        }

        // Transfer the NFT from marketplace to buyer
        let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
        buyerCollection.deposit(token: <- nft)

        emit Purchased(itemID: listingID, seller: listing.seller, buyer: buyer, price: price)
    }

    /// Cancel an active listing and return NFT to seller. Only callable by original seller.
    access(all) fun cancelListing(listingID: UInt64, seller: Address, 
                          sellerCollection: &ItemManager.Collection) {
        let listing = self.itemsForSale.remove(key: listingID) 
                        ?? panic("Listing not found")
        if listing.seller != seller {
            panic("Only the original seller can cancel the listing")
        }
        // Withdraw NFT from marketplace and return it to seller
        let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
        sellerCollection.deposit(token: <- nft)
        emit Cancelled(itemID: listingID, seller: seller)
    }

    /// Change the marketplace fee receiver (owner). Only current owner can call.
    access(all) fun setOwner(newOwner: Address) {
        pre {
            newOwner != self.owner: "Already the owner"
        }
        self.owner = newOwner
    }
}
