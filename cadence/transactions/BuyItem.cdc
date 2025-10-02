import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import NonFungibleToken from 0x631e88ae7f1d7c20 
import ItemManager from 0x0095f13a82f1a835   // replace if different
import MarketPlace2 from 0x0095f13a82f1a835   // replace with marketplace address
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
        MarketPlace2.purchase(
            listingID: listingID,
            buyer: buyer.address,
            buyerCollection: self.collectionRef,
            payment: <-payment
        )
    }
    execute {
    log("Purchase transaction executed — check marketplace events for details.")
    }
}