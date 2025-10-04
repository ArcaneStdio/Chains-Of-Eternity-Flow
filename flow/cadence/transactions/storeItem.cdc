import NonFungibleToken from 0xf8d6e0586b0a20c7
import ItemManager from 0xf8d6e0586b0a20c7
import ItemBurner from 0xf8d6e0586b0a20c7

// This transaction takes an NFT from the user's collection
// and stores it in the Burner contract.

transaction(nftId: UInt64) {

    prepare(signer: auth(Storage) &Account) {
        // Load the signer's ItemManager collection from storage
        let collection <- signer.storage.load<@ItemManager.Collection>(from: ItemManager.CollectionStoragePath)
            ?? panic("Could not load the owner's collection")

        // Withdraw the NFT from the collection
        let nft <- collection.withdraw(withdrawID: nftId)

        // Save the modified collection back to storage
        signer.storage.save(<-collection, to: ItemManager.CollectionStoragePath)

        // Get the ItemBurner contract resource
        let burner = getAccount(0xf8d6e0586b0a20c7).contracts.borrow<&ItemBurner>(name: "ItemBurner")
            ?? panic("Could not borrow a reference to the ItemBurner contract")

        // Store the NFT in the Burner contract
        burner.storeItem(item: <-(nft as! @ItemManager.NFT), add: signer.address)
    }

    execute {
        log("NFT stored in the ItemBurner contract")
    }
}