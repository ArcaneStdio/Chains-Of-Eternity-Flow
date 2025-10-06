import GuildManager from 0xf8d6e0586b0a20c7
import GuildDAO from 0xf8d6e0586b0a20c7
import GuildInterfaces from 0xf8d6e0586b0a20c7

access(all) fun main(guildID: UInt64, proposalID: UInt64): &GuildInterfaces.Proposal? {
    let guildDAORef = GuildManager.borrowGuildDAO(guildID: guildID)
        ?? panic("Could not borrow GuildDAO")

    return guildDAORef.getProposal(proposalID: proposalID)
}