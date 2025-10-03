import "FlowTransactionScheduler"
import "MarketPlace2"
import "NonFungibleToken"

access(all) contract RentItemHandler {

    access(all) struct Loradata1 {
        access(all) let listingID: UInt64
        access(all) let paymentAmount: UFix64

        init(
            listingID: UInt64,
            paymentAmount: UFix64,
            withdrawref: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}
        ) {
            self.listingID = listingID
            self.paymentAmount = paymentAmount
        }
    }

    access(all) struct interface Loradata {
        access(all) let listingID: UInt64
        access(all) let paymentAmount: UFix64
        access(all) let withdrawref: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}
    }

    /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?, withdrawref: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}) {
            let data = data as! Loradata1
            MarketPlace2.returnItem(listingID: data.listingID, withdrawRef: withdrawref)
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}


