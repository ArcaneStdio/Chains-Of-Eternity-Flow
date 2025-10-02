import HeroNFT from 0x0095f13a82f1a835

transaction {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        // Return early if the account already has a collection
        if signer.storage.borrow<&HeroNFT.Collection>(from: HeroNFT.CollectionStoragePath) != nil {
            return
        }
        // Create a new empty collection
        let collection <- HeroNFT.createEmptyCollection(nftType: Type<@HeroNFT.NFT>())
        // save it to the account
        signer.storage.save(<-collection, to: HeroNFT.CollectionStoragePath)
        let collectionCap = signer.capabilities.storage.issue<&HeroNFT.Collection>(HeroNFT.CollectionStoragePath)
        signer.capabilities.publish(collectionCap, at: HeroNFT.CollectionPublicPath)
    }
}