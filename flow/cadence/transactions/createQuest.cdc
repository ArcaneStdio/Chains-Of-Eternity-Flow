import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import FlowTransactionSchedulerUtils from 0xf8d6e0586b0a20c7
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import QuestManager from 0xf8d6e0586b0a20c7
import QuestTransactionQuestHandler from 0xf8d6e0586b0a20c7
import RandomPicker from 0xf8d6e0586b0a20c7
/// Create a quest and schedule its cleanup after 2 days
transaction(
    level: UInt8,
    rarity: String,
    priority: UInt8,
    executionEffort: UInt64
) {
    
    prepare(signer: auth(Storage, Capabilities) &Account) {


        //VRF
        let receipt <- signer.storage.load<@RandomPicker.Receipt>(from: RandomPicker.ReceiptStoragePath)
            ?? panic("No Receipt found in storage at path=".concat(RandomPicker.ReceiptStoragePath.toString()))

        // Reveal by redeeming my receipt - fingers crossed!
        let winnings = RandomPicker.reveal(receipt: <-receipt)

        //Enemies Logic
    
        let numEnemyTypes = QuestManager.RARITY_ENEMY_COUNT[rarity] ?? panic("Unknown rarity")
        let rarityFactor = QuestManager.RARITY_MULTIPLIER[rarity] ?? panic("Unknown rarity multiplier")
        let totalWeight: UFix64 = UFix64(level) * UFix64(rarityFactor) * 100.0
        
        let enemy1 = winnings
        let enemy_1 = QuestManager.ENEMIES[numEnemyTypes[0]]
        let enemy_2 = QuestManager.ENEMIES[numEnemyTypes[1]]

        let weight_enemy1 = QuestManager.ENEMY_WEIGHTS[enemy_1]!

        let enemiesForQuest = [
            QuestManager.ENEMIES[numEnemyTypes[0]],
            QuestManager.ENEMIES[numEnemyTypes[1]]
        ]

        let remainingWeight = totalWeight - (UFix64(weight_enemy1) * UFix64(enemy1))

        //let enemy_2 = enemiesForQuest[1]
        let weight_enemy2 = QuestManager.ENEMY_WEIGHTS[enemy_2]!
        let enemy2: UFix64 = remainingWeight / UFix64(weight_enemy2)

        var finalEnemies: {String: UInt64} = {}
        finalEnemies[enemiesForQuest[0]] = UInt64(enemy1)
        finalEnemies[enemiesForQuest[1]] = UInt64(enemy2)

        //QuestManager

        // Borrow the Manager from QuestManager contract account
        let managerRef = signer.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)
            ?? panic("Could not borrow Manager reference from QuestManager contract")

        let questID: UInt64 = managerRef.createQuest(level: level, rarity: rarity, enemies: finalEnemies)
        let transactionData = QuestTransactionQuestHandler.questinput(questID: questID)
        
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
        if !signer.storage.check<@QuestTransactionQuestHandler.Handler>(from: /storage/QuestTransactionQuestHandler) {
            let handler <- QuestTransactionQuestHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/QuestTransactionQuestHandler)
        }
        
        // Get the capability (try to get existing controllers first)
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/QuestTransactionQuestHandler)
        
        if controllers.length > 0 {
            if let cap = controllers[0].capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                handlerCap = cap
            } else if controllers.length > 1 {
                handlerCap = controllers[1].capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
            }
        }
        
        // If no valid capability found, issue a new one
        if handlerCap == nil || !handlerCap!.check() {
            handlerCap = signer.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/QuestTransactionQuestHandler)
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