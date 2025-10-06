import GuildDAOCallbackHandler from 0xf8d6e0586b0a20c7

// This transaction creates a GuildDAOCallbackHandler.Handler resource
// in the signer's account so they can schedule proposal executions.
transaction {
    prepare(signer: auth(Storage) &Account) {
        // Check if a handler already exists.
        if signer.storage.borrow<&GuildDAOCallbackHandler.Handler>(from: GuildDAOCallbackHandler.HandlerStoragePath) != nil {
            log("Handler already exists in the account.")
            return
        }

        // Create a new Handler and save it to the account's storage.
        signer.storage.save(
            <-GuildDAOCallbackHandler.createHandler(),
            to: GuildDAOCallbackHandler.HandlerStoragePath
        )

        log("Successfully created and stored GuildDAOCallbackHandler.Handler.")
    }
}