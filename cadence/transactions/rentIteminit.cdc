import "FlowTransactionScheduler"
import "RentItemHandler"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/RentItemHandler) == nil {
            let handler <- RentItemHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/RentItemHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowTransactionScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/RentItemHandler)
    }
}