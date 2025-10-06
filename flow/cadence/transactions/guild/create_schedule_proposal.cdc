// Required Imports
import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import FlowTransactionSchedulerUtils from 0xf8d6e0586b0a20c7 // Assuming same address

import GuildManager from 0xf8d6e0586b0a20c7
import GuildDAO from 0xf8d6e0586b0a20c7
import GuildNFT from 0xf8d6e0586b0a20c7
import GuildDAOCallbackHandler from 0xf8d6e0586b0a20c7

transaction(
    guildID: UInt64,
    description: String,
    memberAddress: Address,
    ownership: UFix64,
    priority: UInt8, // 0=High, 1=Medium, 2=Low
    executionEffort: UInt64,
    duration: UFix64 // Duration in seconds for voting period
) {
    // --- CORRECTED TYPES to include authorization ---
    let handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
    let manager: auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}

    let data: GuildDAOCallbackHandler.ProposalExecutionData
    let future: UFix64
    let pr: FlowTransactionScheduler.Priority
    let fees: @FlowToken.Vault
    let executionEffort: UInt64

    // --- CORRECTED SIGNER AUTHORIZATION to include Withdraw ---
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // === Step 1: Create the proposal to get its ID and execution time ===
        let guildDAORef = GuildManager.borrowGuildDAO(guildID: guildID)
            ?? panic("Could not borrow GuildDAO")
        let guildNFTRef = GuildManager.borrowGuildNFT(guildID: guildID)
        let proposalID = guildDAORef.createAddMemberProposal(
            description: description, memberAddress: memberAddress, ownership: ownership,
            guildNFTRef: guildNFTRef, proposer: signer.address, duration: duration
        )
        
        // Per your request, using the `duration` parameter to calculate the execution time.
        self.future = getCurrentBlock().timestamp + duration + 1.0

        // === Step 2: Prepare scheduling data and estimate fees ===
        self.data = GuildDAOCallbackHandler.ProposalExecutionData(guildID: guildID, proposalID: proposalID)
        self.pr = priority == 0 ? FlowTransactionScheduler.Priority.High : (priority == 1 ? FlowTransactionScheduler.Priority.Medium : FlowTransactionScheduler.Priority.Low)
        self.executionEffort = executionEffort

        let est = FlowTransactionScheduler.estimate(
            data: self.data, timestamp: self.future, priority: self.pr, executionEffort: self.executionEffort
        )
        assert(est.timestamp != nil || self.pr == FlowTransactionScheduler.Priority.Low, message: est.error ?? "Estimation failed")

        // === Step 3: Withdraw FLOW to pay for scheduling fees ===
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken Vault")
        self.fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        // === Step 4: Ensure a Manager resource exists in the account ===
        if signer.storage.borrow<&{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            signer.storage.save(<-FlowTransactionSchedulerUtils.createManager(), to: FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath), at: FlowTransactionSchedulerUtils.managerPublicPath)
        }

        // === Step 5: Get the an AUTHORIZED capability for the Handler in this account ===
        self.handlerCap = signer.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(
            GuildDAOCallbackHandler.HandlerStoragePath
        )

        // === Step 6: Borrow the an AUTHORIZED reference to the Manager ===
        self.manager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow Manager resource with Owner auth")
    }

    execute {
        // === Step 7: Schedule the transaction execution ===
        self.manager.schedule(
            handlerCap: self.handlerCap,
            data: self.data,
            timestamp: self.future,
            priority: self.pr,
            executionEffort: self.executionEffort,
            fees: <-self.fees
        )
        log("Successfully created proposal and scheduled its execution for timestamp: ".concat(self.future.toString()))
    }
}