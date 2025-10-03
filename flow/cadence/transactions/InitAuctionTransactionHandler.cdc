import ScheduleCallbackHandler from 0x0095f13a82f1a835
import FlowTransactionScheduler from 0x8c5303eaa26202d6

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
      
        if signer.storage.borrow<&AnyResource>(from: /storage/ScheduleCallbackHandler) == nil {
            let handler <- ScheduleCallbackHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/ScheduleCallbackHandler)
        }
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/ScheduleCallbackHandler)
    }
}