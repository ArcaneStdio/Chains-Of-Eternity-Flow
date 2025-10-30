import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import RandomPicker from 0xf8d6e0586b0a20c7
import RandomPickerCallbackHandler from 0xf8d6e0586b0a20c7


transaction(
    values: [UInt64],
    delaySeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64
) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let handlerStoragePath: StoragePath = /storage/RandomPickerHandler
        let flowTokenVaultPath: StoragePath = /storage/flowTokenVault
        let pickerVaultPath: StoragePath = /storage/RandomPickerVault

        // --- 1. Commit and Deposit Receipt ---
        let receipt <- RandomPicker.commit(values: values)
        let receiptID = receipt.uuid
        let vaultRef = signer.storage.borrow<&{RandomPicker.Vault}>(from: pickerVaultPath)
            ?? panic("Could not borrow a reference to the RandomPicker Vault. Please run the setup transaction.")
        
        vaultRef.deposit(receipt: <-receipt)

        // --- 2. Issue a NEW Vault Capability ---
        // This creates a new, unlinked capability specifically for this transaction.
        // This is the correct pattern.
        let vaultCap = signer.capabilities.storage.issue<&{RandomPicker.Vault}>(pickerVaultPath)
        
        // --- 3. Schedule the Callback ---
        let futureTimestamp = getCurrentBlock().timestamp + delaySeconds
        
        let callbackData = RandomPickerCallbackHandler.CallbackData(
            vaultCapability: vaultCap,
            receiptID: receiptID
        )

        let schedulerPriority = priority == 0 ? FlowTransactionScheduler.Priority.High
            : priority == 1 ? FlowTransactionScheduler.Priority.Medium
            : FlowTransactionScheduler.Priority.Low

        // --- 4. Fee Payment & Scheduling ---
        let estimation = FlowTransactionScheduler.estimate(
            data: callbackData,
            timestamp: futureTimestamp,
            priority: schedulerPriority,
            executionEffort: executionEffort
        )
        assert(estimation.error == nil, message: estimation.error ?? "Scheduler estimation failed")
        
        let ftVaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: flowTokenVaultPath)
            ?? panic("Could not borrow reference to FlowToken vault")
            
        let fees <- ftVaultRef.withdraw(amount: estimation.flowFee ?? 0.0) as! @FlowToken.Vault

        let handlerCap = signer.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(handlerStoragePath)
            
        let schedulerReceipt <- FlowTransactionScheduler.schedule(
            handlerCap: handlerCap,
            data: callbackData,
            timestamp: futureTimestamp,
            priority: schedulerPriority,
            executionEffort: executionEffort,
            fees: <-fees
        )
        log("Reveal callback successfully scheduled with ID: ".concat(schedulerReceipt.id.toString()))
        
        destroy schedulerReceipt
    }
}



