import "FungibleToken"
import "Arcane"

transaction () {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        // Return early if the account already stores a Arcane Vault
        if signer.storage.borrow<&Arcane.Vault>(from: Arcane.VaultStoragePath) != nil {
            return
        }

        let vault <- Arcane.createEmptyVault(vaultType: Type<@Arcane.Vault>())

        // Create a new Arcane Vault and put it in storage
        signer.storage.save(<-vault, to: Arcane.VaultStoragePath)

        // Create a public capability to the Vault that exposes the Vault interfaces
        let vaultCap = signer.capabilities.storage.issue<&Arcane.Vault>(
            Arcane.VaultStoragePath
        )
        signer.capabilities.publish(vaultCap, at: Arcane.VaultPublicPath)
    }
}
