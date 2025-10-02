import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import NonFungibleToken from 0x631e88ae7f1d7c20
import ItemManager from 0x0095f13a82f1a835

access(all) contract AuctionHouse {

    // Events
    access(all) event Listed(itemID: UInt64, seller: Address, basePrice: UFix64, endTime: UFix64)
    access(all) event BidPlaced(itemID: UInt64, bidder: Address, amount: UFix64)
    access(all) event BidReplaced(itemID: UInt64, oldBidder: Address, newBidder: Address, amount: UFix64)
    access(all) event AuctionCompleted(itemID: UInt64, winner: Address?, finalPrice: UFix64)
    access(all) event Cancelled(itemID: UInt64, seller: Address)

    // Fee + Owner
    access(all) let feePercent: UFix64
    access(all) var owner: Address

    // Listing (value type). We update by replacing the whole struct.
    access(all) struct Listing {
        access(all) let id: UInt64
        access(all) let seller: Address
        access(all) let basePrice: UFix64
        access(all) let tokenID: UInt64
        access(all) var currentBid: UFix64
        access(all) var highestBidder: Address?
        access(all) let endTime: UFix64
        // Secondary init for updates
        init(
            id: UInt64,
            seller: Address,
            basePrice: UFix64,
            tokenID: UInt64,
            currentBid: UFix64,
            highestBidder: Address?,
            endTime: UFix64
        ) {
            self.id = id
            self.seller = seller
            self.basePrice = basePrice
            self.tokenID = tokenID
            self.currentBid = currentBid
            self.highestBidder = highestBidder
            self.endTime = endTime
        }

        access(all) fun setCurrentBid(newBid: UFix64) {
            self.currentBid = newBid
        }

        access(all) fun setHighestBidder(newBidder: Address?) {
            self.highestBidder = newBidder
        }
    }

    // Storage
    access(all) var itemsForSale: {UInt64: Listing}
    // CORRECT TYPE: resource dictionary mapping listingID -> FungibleToken.Vault
    access(contract) var bidVaults: @{UInt64: {FungibleToken.Vault}}
    access(contract) var saleCollection: @{NonFungibleToken.Collection}
    access(contract) var nextListingID: UInt64

    // Init
    init(feePercent: UFix64) {
        self.owner = self.account.address
        self.feePercent = feePercent
        self.itemsForSale = {}
        self.nextListingID = 1
        self.bidVaults <- {}
        self.saleCollection <- ItemManager.createEmptyCollection(nftType: Type<@{NonFungibleToken.NFT}>())
    }

    //
    // LIST & BID
    //

    access(all) fun listItem(
        nft: @{NonFungibleToken.NFT},
        basePrice: UFix64,
        seller: Address,
        endTime: UFix64
    ) : UInt64{
        pre {
            basePrice > 0.0: "basePrice must be positive"
            endTime > getCurrentBlock().timestamp: "endTime must be in the future"
        }

        let tokenID = nft.id
        self.saleCollection.deposit(token: <- nft)

        let listingID = self.nextListingID
        let listing = Listing(id: listingID, seller: seller, basePrice: basePrice, tokenID: tokenID, currentBid: basePrice, highestBidder: nil, endTime: endTime)
        self.itemsForSale[listingID] = listing
        self.nextListingID = listingID + 1

        emit Listed(itemID: listingID, seller: seller, basePrice: basePrice, endTime: endTime)

        return listingID
    }

    /// Bid: bidder provides an owned Vault (moved in). Contract escrows it and refunds previous highest bidder.
    access(all) fun placeBid(listingID: UInt64, bidder: Address, payment: @{FungibleToken.Vault}) {
        let listing = self.itemsForSale[listingID] ?? panic("Listing not found")

        if getCurrentBlock().timestamp >= listing.endTime {
            destroy payment
            panic("Auction already ended")
        } else {

            let bidAmount: UFix64 = payment.balance

            if bidAmount <= listing.currentBid {
                // refund immediately to bidder (avoid leaking)
                let refund <- payment
                let bidderReceiver = getAccount(bidder).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                if bidderReceiver != nil {
                    bidderReceiver!.deposit(from: <- refund)
                } else {
                    destroy refund
                    panic("Bid must be higher than current bid; bidder has no public Flow receiver to refund to")
                }
                return
            }

            // If there is an existing vault for this listing, remove it and refund the previous bidder
            if self.bidVaults.containsKey(listingID) {
                let oldVault <- self.bidVaults.remove(key: listingID)!
                let prevBidder = listing.highestBidder
                if prevBidder != nil {
                    let prevReceiver = getAccount(prevBidder!).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                        ?? panic("Previous bidder has no public Flow receiver to refund to")
                    prevReceiver.deposit(from: <- oldVault)
                } else {
                    // defensive: destroy if no prev bidder recorded
                    destroy oldVault
                }
            }

            // Insert new bid vault (escrow the bidder's payment)
            // move the payment into the resource dictionary directly
            self.bidVaults[listingID] <-! payment

            // Replace the Listing with an updated copy (value-type update)
            let updated = Listing(
                id: listing.id,
                seller: listing.seller,
                basePrice: listing.basePrice,
                tokenID: listing.tokenID,
                currentBid: bidAmount,
                highestBidder: bidder,
                endTime: listing.endTime
            )
            self.itemsForSale[listingID] = updated
            // listing.setCurrentBid(newBid: bidAmount)
            // listing.setHighestBidder(newBidder: bidder)

            emit BidPlaced(itemID: listingID, bidder: bidder, amount: bidAmount)
        }
    }

    //
    // CANCEL
    //
    access(all) fun cancelListing(listingID: UInt64, seller: Address, sellerCollection: &ItemManager.Collection) {
        let listing = self.itemsForSale.remove(key: listingID) ?? panic("Listing not found")
        if listing.seller != seller {
            self.itemsForSale[listingID] = listing
            panic("Only the original seller can cancel the listing")
        }

        // If there's an active bid, remove and refund it, then re-store the listing and abort
        if self.bidVaults.containsKey(listingID) {
            let existingBidVault <- self.bidVaults.remove(key: listingID)!
            let prevBidder = listing.highestBidder
            if prevBidder != nil {
                let prevReceiver = getAccount(prevBidder!).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    ?? panic("Previous bidder has no public Flow receiver to refund to")
                prevReceiver.deposit(from: <- existingBidVault)
            } else {
                destroy existingBidVault
            }
            // put listing back and abort
            self.itemsForSale[listingID] = listing
            panic("Cannot cancel listing with active bids; previous bidder refunded")
        }

        // No active bids: return NFT to seller
        let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
        sellerCollection.deposit(token: <- nft)
        emit Cancelled(itemID: listingID, seller: seller)
    }

    //
    // FINALIZE (called by scheduler)
    //
    access(all) fun completeAuction(listingID: UInt64) {
        let listing = self.itemsForSale.remove(key: listingID) ?? panic("Listing not found")

        if getCurrentBlock().timestamp < listing.endTime {
            self.itemsForSale[listingID] = listing
            panic("Auction has not ended yet")
        }

        // No valid bids -> return NFT to seller
        if listing.highestBidder == nil || listing.currentBid == listing.basePrice {
            let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
            let sellerCollection = getAccount(listing.seller)
                .storage
                .borrow<&{NonFungibleToken.Receiver}>(
                    ItemManager.CollectionPublicPath
                )
                ?? panic("Seller has not published a public ItemManager collection capability")
            sellerCollection.deposit(token: <- nft)
            emit AuctionCompleted(itemID: listingID, winner: nil, finalPrice: 0.0)
            return
        }

        // Winner path: remove escrowed vault (must exist)
        let winningVault <- self.bidVaults.remove(key: listingID) ?? panic("Winning bid vault not found")

        let finalAmount: UFix64 = winningVault.balance
        let fee: UFix64 = finalAmount * self.feePercent
        let sellerAmount: UFix64 = finalAmount - fee

        let ownerReceiver = getAccount(self.owner).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Owner's FlowToken receiver not found")
        let sellerReceiver = getAccount(listing.seller).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Seller's FlowToken receiver not found")

        if fee > 0.0 {
            let feeVault <- winningVault.withdraw(amount: fee)
            ownerReceiver.deposit(from: <- feeVault)
        }
        if sellerAmount > 0.0 {
            let sellerVault <- winningVault.withdraw(amount: sellerAmount)
            sellerReceiver.deposit(from: <- sellerVault)
        }

        destroy winningVault

        // transfer NFT to winner
        let nft <- self.saleCollection.withdraw(withdrawID: listing.tokenID)
        let winner = listing.highestBidder!
        let winnerCollection = getAccount(winner).storage.borrow<&{NonFungibleToken.Receiver}>(
            ItemManager.CollectionPublicPath
        )
            ?? panic("Winner has not published a public ItemManager collection capability")
        winnerCollection.deposit(token: <- nft)

        emit AuctionCompleted(itemID: listingID, winner: winner, finalPrice: finalAmount)
    }

    //
    // ADMIN
    //
    access(all) fun setOwner(newOwner: Address) {
        pre { newOwner != self.owner: "Already the owner" }
        self.owner = newOwner
    }
}
