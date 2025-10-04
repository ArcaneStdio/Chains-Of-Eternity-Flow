import GuildDAO from 0xf8d6e0586b0a20c7

access(all) contract GuildInterfaces {

    // --- (Previous interfaces: GuildPublic, GuildAdmin) ---

    // Governance interface for a Guild (for guilds with > 5 members)
    access(all) resource interface GuildGovernance {
        // --- PROPOSAL DATA ---
        access(all) let proposals: {UInt64: GuildDAO.Proposal}
        access(all) fun getProposal(proposalID: UInt64): &GuildDAO.Proposal?

        // --- GOVERNANCE ACTIONS ---
        access(all) fun createAddMemberProposal(description: String, memberAddress: Address, ownership: UFix64)
        access(all) fun createKickMemberProposal(description: String, memberAddress: Address)
        access(all) fun createPurchasePerkProposal(description: String, perkID: UInt64, cost: UFix64)
        // ... other proposal creation functions

        access(all) fun vote(proposalID: UInt64, inFavor: Bool)
        access(all) fun executeProposal(proposalID: UInt64)
    }

    // --- DAO Events ---
    access(all) event ProposalCreated(guildID: UInt64, proposalID: UInt64, proposer: Address)
    access(all) event Voted(proposalID: UInt64, voter: Address, inFavor: Bool, voteWeight: UFix64)
    access(all) event ProposalExecuted(proposalID: UInt64)
    access(all) event ProposalDefeated(proposalID: UInt64)
}