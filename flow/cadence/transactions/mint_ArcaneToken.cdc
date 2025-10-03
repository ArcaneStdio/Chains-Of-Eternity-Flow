import "FungibleToken"
import "Arcane"

transaction(recipient: Address, amount: UFix64) {

    /// Reference to the Example Token Minter Resource object
    let tokenMinter: &Arcane.Minter

    /// Reference to the Fungible Token Receiver of the recipient
    let tokenReceiver: &{FungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {

        // Borrow a reference to the admin object
        self.tokenMinter = signer.storage.borrow<&Arcane.Minter>(from: Arcane.MinterStoragePath)
            ?? panic("Cannot mint: Signer does not store the Arcane Minter in their account!")

        self.tokenReceiver = getAccount(recipient).capabilities.borrow<&{FungibleToken.Receiver}>(Arcane.VaultPublicPath)
            ?? panic("Could not borrow a Receiver reference to the FungibleToken Vault in account "
                .concat(recipient.toString()).concat(" at path ").concat(Arcane.VaultPublicPath.toString())
                .concat(". Make sure you are sending to an address that has ")
                .concat("a FungibleToken Vault set up properly at the specified path."))
    }

    execute {

        // Create mint tokens
        let mintedVault <- self.tokenMinter.mintTokens(amount: amount)

        // Deposit them to the receiever
        self.tokenReceiver.deposit(from: <-mintedVault)
    }
}
