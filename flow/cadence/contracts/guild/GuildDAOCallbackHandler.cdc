import FlowTransactionScheduler from 0xf8d6e0586b0a20c7
import GuildManager from 0xf8d6e0586b0a20c7
import GuildDAO from 0xf8d6e0586b0a20c7

access(all) contract GuildDAOCallbackHandler {

    // Paths for storing and publishing the handler resource
    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath

    // A clearer data structure for the callback
    access(all) struct ProposalExecutionData {
        access(all) let guildID: UInt64
        access(all) let proposalID: UInt64

        init(guildID: UInt64, proposalID: UInt64) {
            self.guildID = guildID
            self.proposalID = proposalID
        }
    }

    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            // Safely cast the data to our struct type
            log("executing the scheduled transaction 2")
            let executionData = data as! ProposalExecutionData?
                ?? panic("Invalid data provided to GuildDAOCallbackHandler")
            // Use the guildID from the data to borrow the correct DAO resource
            log("executing the scheduled transaction 1")
            let guildDAORef = GuildManager.borrowGuildDAO(guildID: executionData.guildID)
                ?? panic("Could not borrow GuildDAO for guild ".concat(executionData.guildID.toString()))

            // Now, execute the proposal on the specific DAO instance
            log("executing the scheduled transaction")
            guildDAORef.executeProposal(proposalID: executionData.proposalID)

            log("GuildDAOCallbackHandler executed proposal ".concat(executionData.proposalID.toString()).concat(" for guild ").concat(executionData.guildID.toString()))
        }
    }

    // --- ADD THIS FUNCTION ---
    // This public function allows anyone to create a new Handler resource.
    // It will be used by the setup transaction to place a Handler in a user's account.
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    // Standard init function to create and publish a handler for the contract's account.
    init() {
        self.HandlerStoragePath = /storage/GuildDAOCallbackHandler
        self.HandlerPublicPath = /public/GuildDAOCallbackHandler

        // Save a handler resource to the contract account's storage
        self.account.storage.save(<- create Handler(), to: self.HandlerStoragePath)

        // Publish a public capability to the handler
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&Handler>(self.HandlerStoragePath),
            at: self.HandlerPublicPath
        )
    }
}