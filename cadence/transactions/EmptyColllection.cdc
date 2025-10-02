import ItemManager from 0x0095f13a82f1a835
import NonFungibleToken from 0x631e88ae7f1d7c20

transaction {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {

        // Return early if the account already has a collection
        if signer.storage.borrow<&ItemManager.Collection>(from: ItemManager.CollectionStoragePath) != nil {
            return
        }

        // Create a new empty collection
        let collection <- ItemManager.createEmptyCollection(nftType: Type<@ItemManager.NFT>())

        // save it to the account
        signer.storage.save(<-collection, to: ItemManager.CollectionStoragePath)

        let collectionCap = signer.capabilities.storage.issue<&ItemManager.Collection>(ItemManager.CollectionStoragePath)
        signer.capabilities.publish(collectionCap, at: ItemManager.CollectionPublicPath)
    }
}
