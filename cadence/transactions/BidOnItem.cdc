import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import NonFungibleToken from 0xf8d6e0586b0a20c7
import ItemManager from 0xf8d6e0586b0a20c7   // replace if different
import AuctionHouse from 0xf8d6e0586b0a20c7   // replace with marketplace address
transaction(listingID: UInt64, paymentAmount: UFix64) {
    let vaultRef: auth(FungibleToken.Withdraw) &{FungibleToken.Vault}
    let collectionRef: &ItemManager.Collection
    prepare(buyer: auth(Storage, BorrowValue) &Account) {
        self.vaultRef = buyer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/flowTokenVault)
        ?? panic("Missing FlowToken vault in buyer account. Please create & link one.")
        // 3) Withdraw the paymentAmount (should be >= listing price; contract will refund any extra)
        let payment <- self.vaultRef.withdraw(amount: paymentAmount)
        self.collectionRef = buyer.storage.borrow<&ItemManager.Collection>(
            from: ItemManager.CollectionStoragePath // Assuming this exists; if not, replace with the actual StoragePath, e.g., /storage/ItemManagerCollection
        ) ?? panic("Missing ItemManager collection in buyer account. Please create & link one.")
        // 4) Call marketplace purchase. Buyer address passed so contract can route refunds, deposits, etc.
        AuctionHouse.placeBid(
            listingID: listingID,
            bidder: buyer.address,
            payment: <-payment
        )
    }
    execute {
    log("Purchase transaction executed — check marketplace events for details.")
    }
}