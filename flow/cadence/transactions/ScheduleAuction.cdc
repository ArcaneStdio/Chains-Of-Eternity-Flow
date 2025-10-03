import FlowTransactionScheduler from 0x8c5303eaa26202d6
import FlowToken from 0x7e60df042a9c0868
import FungibleToken from 0x9a0766d93b6608b7
import AuctionHouse from 0x0095f13a82f1a835
import AuctionCallbackHandler from 0x0095f13a82f1a835
import NonFungibleToken from 0x631e88ae7f1d7c20
import ItemManager from 0x0095f13a82f1a835
/// Schedule an increment of the Counter with a relative delay in seconds
transaction(
    delaySeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    tokenID: UInt64,
    price: UFix64
) {
    let withdrawRef: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}
    prepare(signer: auth(Storage, Capabilities) &Account) {
        self.withdrawRef = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(from: ItemManager.CollectionStoragePath)
            ?? panic("Missing ItemManager collection")

        // Withdraw NFT from seller's collection (this requires signer's withdraw auth)
        let nft <- self.withdrawRef.withdraw(withdrawID: tokenID)

        // Pass the NFT resource and signer.address into contract
        let future = getCurrentBlock().timestamp + delaySeconds
        let listId: UInt64 = AuctionHouse.listItem(nft: <- nft, basePrice: price, seller: signer.address, endTime: future)
        let transactionData = AuctionCallbackHandler.loradata(listingId: listId)

        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        let est = FlowTransactionScheduler.estimate(
            data: transactionData,
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

        if !signer.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            // create a public capability to the scheduled transaction manager
            let managerRef = signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(managerRef, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }

        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil

        if let cap = signer.capabilities.storage
                            .getControllers(forPath: /storage/AuctionCallbackHandler)[0]
                            .capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
            handlerCap = cap
        } else {
            handlerCap = signer.capabilities.storage
                            .getControllers(forPath: /storage/AuctionCallbackHandler)[1]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        }


        let manager = AuctionCallbackHandler.account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        manager.schedule(
            handlerCap: handlerCap,
            data: transactionData,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled transaction at \(future)")
    }
}


