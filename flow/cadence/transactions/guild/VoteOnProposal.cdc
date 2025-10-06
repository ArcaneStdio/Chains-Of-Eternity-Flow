import GuildManager from 0xf8d6e0586b0a20c7
import GuildDAO from 0xf8d6e0586b0a20c7
import GuildNFT from 0xf8d6e0586b0a20c7

transaction(guildID: UInt64, proposalID: UInt64, inFavor: Bool) {

    let guildDAORef: &GuildDAO.DAO
    let guildNFTRef: &GuildNFT.NFT
    let voter: Address

    prepare(signer: auth(Storage) &Account) {
        self.guildDAORef = GuildManager.borrowGuildDAO(guildID: guildID)
            ?? panic("Could not borrow GuildDAO")
        
        self.guildNFTRef = GuildManager.borrowGuildNFT(guildID: guildID)
        self.voter = signer.address
    }

    execute {
        self.guildDAORef.vote(
            proposalID: proposalID,
            inFavor: inFavor,
            guildNFTRef: self.guildNFTRef,
            voter: self.voter
        )
        
        log("Voted successfully!")
    }
}