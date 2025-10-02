import "FungibleToken"
import "Arcane"
import FungibleTokenMetadataViews from 0xee82856bf20e2aa6

access(all) fun main(address: Address): UFix64 {
    let vaultData = Arcane.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get FTVaultData view for the Arcane contract")

    return getAccount(address).capabilities.borrow<&{FungibleToken.Balance}>(
            vaultData.metadataPath
        )?.balance
        ?? panic("Could not borrow a reference to the Arcane Vault in account "
            .concat(address.toString()).concat(" at path ").concat(vaultData.metadataPath.toString())
            .concat(". Make sure you are querying an address that has an Arcane Vault set up properly."))
}
