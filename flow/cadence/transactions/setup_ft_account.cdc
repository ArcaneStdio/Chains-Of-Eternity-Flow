import FungibleToken from 0xee82856bf20e2aa6
import Arcane from 0xf8d6e0586b0a20c7

// This transaction sets up an account to receive Arcane tokens
// using the correct Cadence 1.0+ syntax for interface-based capabilities.

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {

        // 1. Create a Vault if it doesn't exist.
        if signer.storage.borrow<&Arcane.Vault>(from: Arcane.VaultStoragePath) == nil {
            let vault <- Arcane.createEmptyVault(vaultType: Type<@Arcane.Vault>())
            signer.storage.save(<-vault, to: Arcane.VaultStoragePath)
            log("Created a new Arcane Vault.")
        }

        let receiverPath = Arcane.ReceiverPublicPath

        // 2. Unpublish any old or incorrect capability at the target path.
        if signer.capabilities.exists(receiverPath) {
            signer.capabilities.unpublish(receiverPath)
        }

        // 3. CORRECT WAY to issue a capability restricted to an interface in Cadence 1.0+.
        //    The generic type is a reference to the INTERFACE TYPE ITSELF, not the concrete type.
        let receiverCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(Arcane.VaultStoragePath)

        // 4. Publish the new, secure capability to the public path.
        signer.capabilities.publish(receiverCapability, at: receiverPath)

        log("Published Arcane Receiver capability using correct Cadence 1.0+ syntax.")
    }

    execute {
        log("Arcane Vault setup complete.")
    }
}