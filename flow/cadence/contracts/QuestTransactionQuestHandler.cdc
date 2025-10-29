import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import QuestManager from 0xf8d6e0586b0a20c7

access(all) contract QuestTransactionQuestHandler {

    access(all) struct questinput{
        access(all) let questID: UInt64
        init(questID: UInt64) {
            self.questID = questID
        }
    }

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler 
    {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            let inputData = data as! QuestTransactionQuestHandler.questinput? 
                ?? panic("Invalid data type for executeTransaction")
            
            let questID: UInt64 = inputData.questID
            
            // Borrow the Manager resource from the QuestManager contract account's storage
            let managerRef = QuestTransactionQuestHandler.account.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)
                ?? panic("Could not borrow Manager reference from storage")
            
            managerRef.cleanupExpiredQuests(questID: questID)
            
            log("QuestTransactionQuestHandler.executeCallback: completed expiration of quest for questID: "
                .concat(questID.toString())
                .concat(" callback id: ")
                .concat(id.toString()))
        }
    }
    
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}