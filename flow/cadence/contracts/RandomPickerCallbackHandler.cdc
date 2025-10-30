import FlowTransactionScheduler from 0x8c5303eaa26202d6 // Placeholder: Replace with actual address
import RandomPicker from 0x926945503d279080 // Placeholder: Replace with actual address

access(all) contract RandomPickerCallbackHandler {

    // The data now contains the owner's address and the path to their vault.
    // The data now holds a direct capability to the Vault, which is secure.
    access(all) struct CallbackData {
        access(all) let vaultCapability: Capability<&{RandomPicker.Vault}>
        access(all) let receiptID: UInt64

        init(vaultCapability: Capability<&{RandomPicker.Vault}>, receiptID: UInt64) {
            self.vaultCapability = vaultCapability
            self.receiptID = receiptID
        }
    }

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            let callbackData = data as! CallbackData

            // Borrow a reference directly from the provided capability.
            // This is authorized and does not require getAccount().
            let vaultRef = callbackData.vaultCapability.borrow()
                ?? panic("Could not borrow reference from the provided RandomPicker.Vault capability.")

            // The rest of the logic is the same.
            let receipt <- vaultRef.withdraw(receiptID: callbackData.receiptID)
            let winningResult = RandomPicker.reveal(receipt: <-receipt)
            
            log("Callback ".concat(id.toString()).concat(": RandomPicker.reveal completed for receipt ").concat(callbackData.receiptID.toString()).concat(", winning result: ").concat(winningResult.toString()))
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}