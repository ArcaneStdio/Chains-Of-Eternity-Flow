import QuestManager from 0xf8d6e0586b0a20c7
import HeroNFT from 0xf8d6e0586b0a20c7
import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import FlowTransactionSchedulerUtils from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import QuestTransactionUserHandler from 0xf8d6e0586b0a20c7
import RandomPicker from 0xf8d6e0586b0a20c7
/// Create a quest and schedule its cleanup after 2 days
transaction(
    questID: UInt64,
    priority: UInt8,
    executionEffort: UInt64
)  {
    
    prepare(signer: auth(Storage, Capabilities, SaveValue) &Account) {
        // Borrow the Manager from QuestManager contract account
        //let managerRef = QuestManager.account.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)
           // ?? panic("Could not borrow Manager reference from QuestManager contract")
        
        let player: Address = signer.address

        let collectionRef = signer.storage.borrow<&HeroNFT.Collection>(from: HeroNFT.CollectionStoragePath)
        ?? panic ("blah")

        let ids = collectionRef.getIDs()

        if ids.length == 0 {
            panic ("blah")
        }

        let nftRef = collectionRef.borrowNFT(ids[0])
        let heroRef = nftRef as! &HeroNFT.NFT

       // return heroRef.heroData.level
        let playerlevel = heroRef.heroData.level

        QuestManager.joinQuest(
            playerAcct: signer,
            questID: questID,
            playerLevel: UInt8(playerlevel)
        )
        
        log("Successfully joined quest ID: ".concat(questID.toString()))

        let transactionData = QuestTransactionUserHandler.playerinput(player: player, questID: questID)
        
        // Schedule cleanup for 2 days from now (172800 seconds)
        let cleanupTimestamp: UFix64 = getCurrentBlock().timestamp + 172800.0
     
        // Convert priority
        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low
        
        // Estimate fees
        let est = FlowTransactionScheduler.estimate(
            data: transactionData,
            timestamp: cleanupTimestamp,
            priority: pr,
            executionEffort: executionEffort
        )
        
        assert(
            est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )
        
        // Withdraw fees from signer's Flow vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault
        
        // Create FlowTransactionSchedulerUtils Manager if not exists
        if !signer.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
            
            // Create a public capability to the scheduled transaction manager
            let managerRef = signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(managerRef, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }
        
        // Get or create the Handler capability
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        
        // Check if handler already exists
        if !signer.storage.check<@QuestTransactionUserHandler.Handler>(from: /storage/QuestTransactionUserHandler) {
            let handler <- QuestTransactionUserHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/QuestTransactionUserHandler)
        }
        
        // Get the capability (try to get existing controllers first)
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/QuestTransactionUserHandler)
        
        if controllers.length > 0 {
            if let cap = controllers[0].capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                handlerCap = cap
            } else if controllers.length > 1 {
                handlerCap = controllers[1].capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
            }
        }
        
        // If no valid capability found, issue a new one
        if handlerCap == nil || !handlerCap!.check() {
            handlerCap = signer.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/QuestTransactionUserHandler)
        }
        
        assert(handlerCap != nil && handlerCap!.check(), message: "Handler capability is invalid")
        
        // Borrow the FlowTransactionSchedulerUtils Manager to schedule
        let schedulerManager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from FlowTransactionSchedulerUtils")
        
        // Schedule the cleanup transaction
        schedulerManager.schedule(
            handlerCap: handlerCap!,
            data: transactionData,
            timestamp: cleanupTimestamp,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )
        
        log("Quest created with ID: ".concat(questID.toString()))
        log("Cleanup scheduled for timestamp: ".concat(cleanupTimestamp.toString()))
    }
}