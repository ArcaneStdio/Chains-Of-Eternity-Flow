import "FlowTransactionScheduler"
import "FlowToken"
import "FungibleToken"
import "NonFungibleToken"
import "MarketPlace2"
import "ItemManager"
import "RentItemHandler"


/// Schedule an increment of the Counter with a relative delay in seconds
transaction(
    delaySeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    listingID: UInt64,
    paymentAmount: UFix64,
    listingid: UInt64,
    paymentamount: UFix64,
) {
    let vaultRef: auth(FungibleToken.Withdraw) &{FungibleToken.Vault}
    let collectionRef: &ItemManager.Collection
    let withdrawRef: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}

    prepare(signer: auth(Storage, Capabilities , BorrowValue) &Account) {
        let future = getCurrentBlock().timestamp + delaySeconds

        self.withdrawRef = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(from: ItemManager.CollectionStoragePath)
            ?? panic("Missing ItemManager collection")
        self.vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/flowTokenVault)
        ?? panic("Missing FlowToken vault in buyer account. Please create & link one.")
        // 3) Withdraw the paymentAmount (should be >= listing price; contract will refund any extra)
        let payment <- self.vaultRef.withdraw(amount: paymentAmount)
        self.collectionRef = signer.storage.borrow<&ItemManager.Collection>(
            from: ItemManager.CollectionStoragePath // Assuming this exists; if not, replace with the actual StoragePath, e.g., /storage/ItemManagerCollection
        ) ?? panic("Missing ItemManager collection in buyer account. Please create & link one.")

        let dataStruct = RentItemHandler.Loradata1(
            listingID: listingID,
            paymentAmount: paymentAmount,
            withdrawref: self.withdrawRef
        )
        MarketPlace2.rent(listingID: listingID, buyer: signer.address, buyerCollection: self.collectionRef, payment: <-payment , rentalTime : 120.00)


        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low
        

        let est = FlowTransactionScheduler.estimate(
            data: dataStruct,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort
        )

        assert(
            est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )

        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        let handlerCap = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/RentItemHandler)

        let receipt <- FlowTransactionScheduler.schedule(
            handlerCap: handlerCap,
            data: dataStruct,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled transaction id: ".concat(receipt.id.toString()).concat(" at ").concat(receipt.timestamp.toString()))
        
        destroy receipt
    }
    execute {
    }
}


