// transactions/listItem.cdc
import AuctionPlace3 from 0xf8d6e0586b0a20c7
import ItemManager from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

transaction(tokenID: UInt64, basePrice: UFix64, endTime: UFix64) {
    prepare(signer: AuthAccount) {
        let collectionRef = signer.borrow<&ItemManager.Collection>(from: /storage/ItemManagerCollection)
            ?? panic("Seller has no ItemManager collection at /storage/ItemManagerCollection")

        // Withdraw the NFT from seller collection
        let nft <- collectionRef.withdraw(withdrawID: tokenID)

        // Call the auction contract to list (seller = signer.address)
        AuctionPlace3.listItem(nft: <- nft, basePrice: basePrice, seller: signer.address, endTime: endTime)
    }
}
    