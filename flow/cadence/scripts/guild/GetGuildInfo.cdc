import GuildManager from 0xf8d6e0586b0a20c7
import GuildNFT from 0xf8d6e0586b0a20c7

access(all) fun main(guildID: UInt64): &GuildNFT.NFT {
    return GuildManager.borrowGuildNFT(guildID: guildID)
}