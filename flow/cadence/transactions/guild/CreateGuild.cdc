import GuildManager from 0xf8d6e0586b0a20c7
import GuildNFT from 0xf8d6e0586b0a20c7

transaction(guildName: String) {

    prepare(signer: auth(Storage, Capabilities) &Account) {
        // If the user doesn't have a GuildNFT collection, create one
        if signer.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath) == nil {
            signer.storage.save(<-GuildNFT.createEmptyCollection(nftType: Type<@GuildNFT.NFT>()), to: GuildNFT.CollectionStoragePath)
            signer.capabilities.publish(signer.capabilities.storage.issue<&GuildNFT.Collection>(GuildNFT.CollectionStoragePath), at: GuildNFT.CollectionPublicPath)
        }

        GuildManager.createGuild(name: guildName, owner: signer)
    }

    execute {
        log("Guild created successfully!")
    }
}