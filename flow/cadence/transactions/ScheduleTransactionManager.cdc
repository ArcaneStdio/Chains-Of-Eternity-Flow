import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Create and save the Manager resource
        let manager <- FlowTransactionSchedulerUtils.createManager()
        signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
        
        // Create a capability for the Manager
        let managerCap = signer.capabilities.storage.issue<&FlowTransactionSchedulerUtils.Manager>(FlowTransactionSchedulerUtils.managerStoragePath)

        signer.capabilities.publish(managerCap, at: FlowTransactionSchedulerUtils.managerPublicPath)
    }
}
