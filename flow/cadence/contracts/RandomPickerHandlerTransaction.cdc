import RandomPickerCallbackHandler from 0xf8d6e0586b0a20c7

transaction {

    prepare(signer: auth(Storage) &Account) {
        // Only proceed if the Handler resource has not been stored yet
        if signer.storage.borrow<&RandomPickerCallbackHandler.Handler>(from: /storage/RandomPickerHandler) == nil {
            // Create the Handler resource and save it to a specific storage path.
            // This resource is what the scheduler will reference to execute the callback logic.
            signer.storage.save(
                <- RandomPickerCallbackHandler.createHandler(),
                to: /storage/RandomPickerHandler
            )
            log("RandomPickerCallbackHandler Handler initialized and stored.")
        } else {
            log("RandomPickerCallbackHandler Handler already initialized.")
        }
    }
}