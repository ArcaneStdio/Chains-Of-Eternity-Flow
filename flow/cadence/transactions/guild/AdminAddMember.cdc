import GuildNFT from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

transaction(nftID: UInt64, memberAddress: Address, ownershipPercentage: UFix64) {

    let collectionRef: &GuildNFT.Collection

    prepare(signer: auth(Storage) &Account) {
        self.collectionRef = signer.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath)
            ?? panic("Could not borrow GuildNFT collection")
    }

    execute {
        let nft = self.collectionRef.borrowNFT(nftID)
            ?? panic("Could not borrow NFT")
        
        let guildNFT = nft as! &GuildNFT.NFT
        guildNFT.addMember(addr: memberAddress, ownership: ownershipPercentage)
        
        log("Member added successfully!")
    }
}