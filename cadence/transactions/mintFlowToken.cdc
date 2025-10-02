import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

transaction(recipient: Address, amount: UFix64) {
    prepare(signer: auth(Storage, BorrowValue) &Account) {
        // Borrow the minter from the service account (emulator default)
        let minter = signer.storage.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
            ?? panic("Could not borrow FlowToken minter reference")

        // Borrow recipient’s FlowToken receiver capability
        let receiver = getAccount(recipient)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Recipient does not have a FlowToken receiver")

        // Mint tokens: this now RETURNS a Vault!
        let mintedVault <- minter.mintTokens(amount: amount)

        // Deposit into recipient’s vault
        receiver.deposit(from: <-mintedVault)

        log("Minted ".concat(amount.toString()).concat(" FlowTokens to ").concat(recipient.toString()))
    }
}
