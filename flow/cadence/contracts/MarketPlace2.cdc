import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import NonFungibleToken from 0x631e88ae7f1d7c20
import ItemManager from 0x0095f13a82f1a835
import Arcane from 0x0095f13a82f1a835

access(all) contract MarketPlace2 {

    // Events to log listing and purchase actions
    access(all) event Listed(itemID: UInt64, seller: Address, price: UFix64)
    access(all) event Purchased(itemID: UInt64, seller: Address, buyer: Address, price: UFix64)
    access(all) event Rented(itemID: UInt64, seller: Address, buyer: Address, price: UFix64 , rentalTime : UFix64)
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
        access(all) let rentalPrice : UFix64

        init(id: UInt64, seller: Address, price: UFix64, tokenID: UInt64) {
            self.id = id
            self.seller = seller
            self.price = price
            self.tokenID = tokenID
            self.rentalPrice = price * 0.001
        }
    }

    // Storage for active listings: mapping listingID -> Listing
    access(all) var itemsForSale: {UInt64: Listing}

    // A private NFT collection to hold all listed NFTs (escrow)
    access(contract) var saleCollection: @{NonFungibleToken.Collection}

    access(contract) var TokenVault: @{FungibleToken.Vault}

    // Auto-incrementing ID for listings
    access(contract) var nextListingID: UInt64

    /// Initialize contract: set owner and fee, prepare empty storage
    init(feePercent: UFix64) {
        self.owner = self.account.address
        self.feePercent = feePercent
        self.itemsForSale = {}
        self.nextListingID = 1
        // Create an empty collection to hold NFTs for sale (pass required arg)
        self.saleCollection <- ItemManager.createEmptyCollection(nftType: Type<@{NonFungibleToken.NFT}>())
        self.TokenVault <- Arcane.createEmptyVault(vaultType: Type<@Arcane.Vault>())
    }

    //
    // ESCROW FLOW (no borrowing from other accounts inside contract)
    //

    /// Seller lists an NFT for sale by MOVING the NFT into the marketplace.
    /// The seller must withdraw the NFT in a signed transaction and pass it here.
    access(all) fun listItem(nft: @{NonFungibleToken.NFT}, price: UFix64, seller: Address) {
        pre { price > 0.0: "Price must be positive" }

        let tokenID = nft.id

        // Deposit the NFT into the marketplace escrow (we own saleCollection)
        self.saleCollection.deposit(token: <- nft)

        // Create a listing record
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

    access(all) fun Reward() {
        for item in self.itemsForSale.values {
            let seller = item.seller
            let sellerReceiver = getAccount(seller).capabilities.borrow<&{FungibleToken.Receiver}>(/public/ArcaneReceiver)
                ?? panic("Seller's FlowToken receiver not found")
            let rewardVault <- self.TokenVault.withdraw(amount: 10.0) as! @Arcane.Vault
            sellerReceiver.deposit(from: <- rewardVault)
        }
    }

    access(all) fun depositFees(from: @{FungibleToken.Vault}) {
        self.TokenVault.deposit(from: <- from)
    }

    // access(all) fun addToken( from @{FungibleToken.Vault}) {
    //     let vaultRef = self.account.borrow<&FlowToken.Vault>(from: /storage/ArcaneVault)
    //         ?? panic("Could not borrow reference to the owner's Vault!")
    //     let sentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
    //     self.TokenVault <- sentVault
    // }

    /// Purchase a listed NFT by ID. Buyer provides a FlowToken vault with the payment,
    /// and a reference to their ItemManager.Collection where NFT will be deposited.
    access(all) fun purchase(
        listingID: UInt64,
        buyer: Address,
        buyerCollection: &ItemManager.Collection,
        payment: @{FungibleToken.Vault}
    ) {
        // Find and remove the listing
        let listing = self.itemsForSale.remove(key: listingID)
            ?? panic("Listing not found")

        let price = listing.price
        if payment.balance < price {
            panic("Insufficient payment for purchase")
        }

        // Calculate fee and seller payout
        let fee = price * self.feePercent
        let sellerAmount = price - fee

        // Send fee to contract owner using their public Flow receiver capability
        let ownerReceiver = getAccount(self.owner)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Owner's FlowToken receiver not found")

        let feeVault <- payment.withdraw(amount: fee)
        ownerReceiver.deposit(from: <- feeVault)

        // Send proceeds to seller using their public Flow receiver capability
        let sellerReceiver = getAccount(listing.seller)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Seller's FlowToken receiver not found")

        let sellerVault <- payment.withdraw(amount: sellerAmount)
        sellerReceiver.deposit(from: <- sellerVault)

        // Refund any overpayment to buyer using buyer's public receiver
        if payment.balance > 0.0 {
            let buyerReceiver = getAccount(buyer)
                .capabilities
                .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("Buyer's FlowToken receiver not found")
            buyerReceiver.deposit(from: <- payment)
        } else {
            destroy payment
        }

        // Transfer the NFT from marketplace escrow to buyer's collection
        let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
        buyerCollection.deposit(token: <- nft)

        emit Purchased(itemID: listingID, seller: listing.seller, buyer: buyer, price: price)
    }

    //rent Item
    access(all) fun rent(
        listingID: UInt64,
        buyer: Address,
        buyerCollection: &ItemManager.Collection,
        payment: @{FungibleToken.Vault},
        rentalTime : UFix64
    ) {
        // Find and remove the listing
        let listing = self.itemsForSale[listingID]
            ?? panic("Listing not found")

        let rentalPrice = listing.rentalPrice
        if payment.balance < rentalPrice * rentalTime {
            panic("Insufficient payment for purchase")
        }

        // Calculate fee and seller payout
        let fee = payment.balance * self.feePercent
        let sellerAmount = payment.balance - fee

        // Send fee to contract owner using their public Flow receiver capability
        let ownerReceiver = getAccount(self.owner)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Owner's FlowToken receiver not found")

        let feeVault <- payment.withdraw(amount: fee)
        ownerReceiver.deposit(from: <- feeVault)

        // Send proceeds to seller using their public Flow receiver capability
        let sellerReceiver = getAccount(listing.seller)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Seller's FlowToken receiver not found")

        let sellerVault <- payment.withdraw(amount: sellerAmount)
        sellerReceiver.deposit(from: <- sellerVault)

        // Refund any overpayment to buyer using buyer's public receiver
        if payment.balance > 0.0 {
            let buyerReceiver = getAccount(buyer)
                .capabilities
                .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("Buyer's FlowToken receiver not found")
            buyerReceiver.deposit(from: <- payment)
        } else {
            destroy payment
        }

        // Transfer the NFT from marketplace escrow to buyer's collection
        let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
        buyerCollection.deposit(token: <- nft)

        emit Rented(itemID: listingID, seller: listing.seller, buyer: buyer, price: rentalPrice * rentalTime , rentalTime : rentalTime)
    }

    access(all) fun returnItem(
        listingID: UInt64,
        withdrawRef: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}
    ) {
        let listing = self.itemsForSale[listingID]
            ?? panic("Listing not found")

        // Withdraw NFT from marketplace escrow and send back to seller
        let nft <- withdrawRef.withdraw(withdrawID: listing.tokenID)
        self.saleCollection.deposit(token: <- nft) 
    }



    /// Cancel an active listing and return NFT to seller. Only callable by original seller.
    /// The seller must call this in a signed tx and pass their collection ref.
    access(all) fun cancelListing(listingID: UInt64, seller: Address, sellerCollection: &ItemManager.Collection) {
        let listing = self.itemsForSale.remove(key: listingID)
            ?? panic("Listing not found")
        if listing.seller != seller {
            panic("Only the original seller can cancel the listing")
        }

        // Withdraw NFT from marketplace escrow and send back to seller
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
