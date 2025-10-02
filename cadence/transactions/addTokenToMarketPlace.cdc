import "ItemManager" //from 0x3d895199cfc42ff5
import "MarketPlace2" //from 0x3d895199cfc42ff5
import "FungibleToken" //from 0x631e88ae7f1d7c20

transaction( price: UFix64) {
    let vaultRef: auth(FungibleToken.Withdraw) &{FungibleToken.Vault}
    prepare(signer: auth(Storage , BorrowValue) &Account) {
        self.vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/ArcaneVault)
            ?? panic("Missing FlowToken vault in buyer account. Please create & link one.")

        // Withdraw NFT from seller's collection (this requires signer's withdraw auth)
        let payment <- self.vaultRef.withdraw(amount: price)

        // Pass the NFT resource and signer.address into contract
        MarketPlace2.depositFees(from: <- payment)
    }
}
