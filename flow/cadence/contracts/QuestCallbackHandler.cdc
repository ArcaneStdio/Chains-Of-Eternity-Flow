import FlowTransactionScheduler from 0x8c5303eaa26202d6
//import QuestManager from 
access(all) contract QuestCallbackHandler {

    access(all) struct questinput{
        //access(all) let listingId: UInt64
        access(all) let level: UInt8
        access(all) let rarity: String
        init(level: UInt8, rarity: String) {
            //self.listingId = listingId
            self.level = level
            self.rarity = rarity
        }
    }

    access(all) struct playerinput{
        
        init(level: UInt8, rarity: String) {
            //self.listingId = listingId
            self.level = level
            self.rarity = rarity
        }
    }

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {


        access(FlowTransactionScheduler.Execute) fun executeTransactionCreateQuest(id: UInt64, data: AnyStruct?) {
            let data = data as! questinput
            let level = data.level
            let rarity = data.rarity
            if level == nil or data.rarity == nil {
                log("QuestCallbackHandler.executeCallback: no level or rarity provided in callback data. callback id: ".concat(id.toString()))
                return
            }

            //AuctionHouse.completeAuction(listingID: listingID!)

            QuestManager.createQuest(level: level!, rarity: rarity!)
            log("QuestCallbackHandler.executeCallback: completed spell creation: level: ".concat(level!.toString()).concat(" rarity: ").concat(rarity).concat(" callback id: ").concat(id.toString()))
        }


        access(FlowTransactionScheduler.Execute) fun executeTransactionAddPlayer(id: UInt64, data: AnyStruct?) {
            let data = data as! questinput
            let level = data.level
            let rarity = data.rarity
            if level == nil or data.rarity == nil {
                log("QuestCallbackHandler.executeCallback: no level or rarity provided in callback data. callback id: ".concat(id.toString()))
                return
            }

            //AuctionHouse.completeAuction(listingID: listingID!)

            QuestManager.createQuest(level: level!, rarity: rarity!)
            log("QuestCallbackHandler.executeCallback: completed spell creation: level: ".concat(level!.toString()).concat(" rarity: ").concat(rarity).concat(" callback id: ").concat(id.toString()))
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}
