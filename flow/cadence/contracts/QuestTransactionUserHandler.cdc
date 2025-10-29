import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import QuestManager from 0xf8d6e0586b0a20c7

access(all) contract QuestTransactionUserHandler {

    access(all) struct playerinput{
        access(all) let questID: UInt64
        access(all) let player: Address
        init(player: Address, questID: UInt64) {
            self.questID = questID
            self.player = player
        }
    }

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler 
    {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            let inputData = data as! QuestTransactionUserHandler.playerinput? 
                ?? panic("Invalid data type for executeTransaction")
            
            let questID: UInt64 = inputData.questID
            let player: Address = inputData.player

            // Borrow the Manager resource from the QuestManager contract account's storage
            let managerRef = QuestTransactionUserHandler.account.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)
                ?? panic("Could not borrow Manager reference from storage")
            
            managerRef.expireParticipantIfNeeded(player: player, questID: questID)
            
            log("QuestTransactionUserHandler.executeCallback: completed expiration of quest for questID: "
                .concat(questID.toString())
                .concat(" callback id: ")
                .concat(id.toString()))
        }
    }
    
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}