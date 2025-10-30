import QuestManager from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

transaction {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {

        // Return early if the account already has a collection
        if signer.storage.borrow<&QuestManager.QuestCollection>(from: QuestManager.QuestCollectionStoragePath) != nil {
            return
        }

        // Create a new empty collection
        let collection <- QuestManager.createEmptyQuestCollection()

        // save it to the account
        signer.storage.save(<-collection, to: QuestManager.QuestCollectionStoragePath)

        let collectionCap = signer.capabilities.storage.issue<&QuestManager.QuestCollection>(QuestManager.QuestCollectionStoragePath)
        signer.capabilities.publish(collectionCap, at: QuestManager.QuestCollectionPublicPath)
    }
}
