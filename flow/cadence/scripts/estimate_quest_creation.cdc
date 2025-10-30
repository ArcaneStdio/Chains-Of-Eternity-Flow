import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import "QuestManager"
import "QuestTransactionQuestHandler" 

access(all) fun main(level: UInt8, rarity: String): {String: AnyStruct} {
    let now = getCurrentBlock().timestamp
    let cleanupTimestamp = now + 172800.0 // 2 days
    
    let questInput = QuestTransactionQuestHandler.questinput(questID: 999) // dummy ID for estimation
    
    let estimate = FlowTransactionScheduler.estimate(
        data: questInput,
        timestamp: cleanupTimestamp,
        priority: FlowTransactionScheduler.Priority.Low,
        executionEffort: 500
    )
    
    return {
        "feeRequired": estimate.flowFee,
        "scheduledTimestamp": estimate.timestamp,
        "error": estimate.error,
        "questDuration": QuestManager.RARITY_DURATIONS[rarity],
        "canCreate": QuestManager.account.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)!.canCreateQuest(level: level, rarity: rarity)
    }
}