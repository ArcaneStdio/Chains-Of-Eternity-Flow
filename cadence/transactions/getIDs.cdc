import HeroNFT from 0x0095f13a82f1a835
import NonFungibleToken from 0x631e88ae7f1d7c20

// For Cadence 1.0 - updated syntax
access(all) fun main(account: Address): [UInt64] {
    let acct = getAccount(account)

    // Updated capability syntax for Cadence 1.0
    let collectionCap = acct.capabilities.borrow<&{NonFungibleToken.CollectionPublic}>(HeroNFT.CollectionPublicPath)
        ?? panic("Could not borrow capability from public collection")

    return collectionCap.getIDs()
}