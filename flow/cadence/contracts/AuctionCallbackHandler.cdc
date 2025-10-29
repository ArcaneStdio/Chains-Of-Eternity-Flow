import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import AuctionHouse from 0xf8d6e0586b0a20c7

access(all) contract AuctionCallbackHandler {

    access(all) struct loradata{
        access(all) let listingId: UInt64

        init(listingId: UInt64) {
            self.listingId = listingId
        }
    }

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {


        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            let data = data as! loradata
            let listingID = data.listingId
            if listingID == nil {
                log("AuctionCallbackHandler.executeCallback: no listingID provided in callback data. callback id: ".concat(id.toString()))
                return
            }

            AuctionHouse.completeAuction(listingID: listingID!)
            log("AuctionCallbackHandler.executeCallback: completed auction for listing ".concat(listingID!.toString()).concat(" callback id: ").concat(id.toString()))
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}
