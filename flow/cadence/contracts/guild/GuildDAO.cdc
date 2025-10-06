import GuildInterfaces from "./GuildInterfaces.cdc"
import GuildNFT from "./GuildNFT.cdc"

access(all) contract GuildDAO {

    access(all) event ProposalCreated(guildID: UInt64, proposalID: UInt64, proposer: Address)
    access(all) event Voted(proposalID: UInt64, voter: Address, inFavor: Bool, voteWeight: UFix64)
    access(all) event ProposalExecuted(proposalID: UInt64)

     access(all) resource interface GuildGovernance {
        access(all) let proposals: @{UInt64: GuildInterfaces.Proposal} // Dictionary holds resources
        access(all) fun getProposal(proposalID: UInt64): &GuildInterfaces.Proposal?
        access(all) fun createAddMemberProposal(description: String, memberAddress: Address, ownership: UFix64, guildNFTRef: &GuildNFT.NFT, proposer: Address, duration: UFix64): UInt64
        access(all) fun createKickMemberProposal(description: String, memberAddress: Address, guildNFTRef: &GuildNFT.NFT, proposer: Address, duration: UFix64)
        access(all) fun createPurchasePerkProposal(description: String, perkID: UInt64, cost: UFix64, guildNFTRef: &GuildNFT.NFT, proposer: Address, duration: UFix64)
        access(all) fun vote(proposalID: UInt64, inFavor: Bool, guildNFTRef: &GuildNFT.NFT, voter: Address)
        access(all) fun executeProposal(proposalID: UInt64)
    }

    access(all) resource DAO: GuildGovernance {
        access(all) let guildID: UInt64
        access(all) let proposals: @{UInt64: GuildInterfaces.Proposal}
        access(self) var nextProposalID: UInt64
        access(all) let votingDuration: UFix64

        init(guildID: UInt64) {
            self.guildID = guildID
            self.proposals <- {}
            self.nextProposalID = 1
            self.votingDuration = 259200.0 // 3 days in seconds
        }

        access(all) fun getProposal(proposalID: UInt64): &GuildInterfaces.Proposal? {
            return &self.proposals[proposalID] as &GuildInterfaces.Proposal?
        }
        
        // MODIFIED: Functions now accept the NFT ref and proposer address as arguments
        access(all) fun createAddMemberProposal(description: String, memberAddress: Address, ownership: UFix64, guildNFTRef: &GuildNFT.NFT, proposer: Address, duration: UFix64): UInt64 {
            pre {
                guildNFTRef.isMember(addr: proposer): "Proposer must be a guild member."
                !guildNFTRef.isMember(addr: memberAddress): "Address is already a member."
                ownership > 0.0 && ownership <= 1.0: "Invalid ownership percentage."
            }
            let params: {String: AnyStruct} = {"memberAddress": memberAddress, "ownership": ownership}
            log("Created proposal params in GuildDAO:")
            log(params) // <-- ADD THIS
            let proposalID = self.createProposal(description: description, type: GuildInterfaces.ProposalType.addMember, parameters: params, proposer: proposer, duration: duration)
            return proposalID
        }
        
        access(all) fun createKickMemberProposal(description: String, memberAddress: Address, guildNFTRef: &GuildNFT.NFT, proposer: Address, duration: UFix64) {
            pre {
                guildNFTRef.isMember(addr: proposer): "Proposer must be a guild member."
                guildNFTRef.isMember(addr: memberAddress): "Address is not a member."
            }
            let params: {String: AnyStruct} = {"memberAddress": memberAddress}
            self.createProposal(description: description, type: GuildInterfaces.ProposalType.kickMember, parameters: params, proposer: proposer, duration: duration)
        }

        access(all) fun createPurchasePerkProposal(description: String, perkID: UInt64, cost: UFix64, guildNFTRef: &GuildNFT.NFT, proposer: Address, duration: UFix64) {
            pre { guildNFTRef.isMember(addr: proposer): "Proposer must be a guild member." }
            let params: {String: AnyStruct} = {"perkID": perkID, "cost": cost}
            self.createProposal(description: description, type: GuildInterfaces.ProposalType.purchasePerk, parameters: params, proposer: proposer, duration: duration)
        }

        access(self) fun createProposal(description: String, type: GuildInterfaces.ProposalType, parameters: {String: AnyStruct}, proposer: Address, duration: UFix64) : UInt64  {
            let proposal <- GuildInterfaces.createProposal(proposalID: self.nextProposalID, proposer: proposer, description: description, type: type, parameters: parameters, duration: duration)
            let oldProposal <- self.proposals.insert(key: proposal.proposalID, <-proposal)
            destroy oldProposal

            emit ProposalCreated(guildID: self.guildID, proposalID: self.nextProposalID, proposer: proposer)
            let createdProposalID = self.nextProposalID
            self.nextProposalID = self.nextProposalID + 1
            return createdProposalID
        }

        access(all) fun vote(proposalID: UInt64, inFavor: Bool, guildNFTRef: &GuildNFT.NFT, voter: Address) {
            pre {
                guildNFTRef.isMember(addr: voter): "Voter must be a guild member."
            }
            let proposalRef = &self.proposals[proposalID] as &GuildInterfaces.Proposal?
                ?? panic("Proposal not found.")

            assert(proposalRef.status == GuildInterfaces.ProposalStatus.active, message: "Proposal is not active for voting.")
            assert(proposalRef.hasVoted(voter: voter) == false, message: "Member has already voted.")
            assert(getCurrentBlock().timestamp <= proposalRef.votingEndTime, message: "Voting period has ended.")

            let voteWeight = guildNFTRef.members[voter]!
            
            proposalRef.addVote(voter: voter, inFavor: inFavor)
            if inFavor { 
                proposalRef.updateVotesFor(Weight: voteWeight)
            } else { 
                proposalRef.updateVotesAgainst(Weight: voteWeight)
            }
            emit Voted(proposalID: proposalID, voter: voter, inFavor: inFavor, voteWeight: voteWeight)
        }

        access(all) fun executeProposal(proposalID: UInt64) {
            let proposalRef = &self.proposals[proposalID] as &GuildInterfaces.Proposal?
                ?? panic("Proposal not found.")
            log("Updating status")
            proposalRef.updateStatus()
            log("Updated status")
            assert(proposalRef.status == GuildInterfaces.ProposalStatus.succeeded, message: "Proposal has not passed.")
            
            log("trying borrow")
            let guildManager = getAccount(GuildDAO.account.address).capabilities.borrow<&{GuildInterfaces.Executor}>(/public/GuildManagerExecutor)
                ?? panic("Could not borrow GuildManager Executor capability")
            log("borrow successful")

            let paramsRef = proposalRef.parameters
            let paramsCopy: {String: AnyStruct} = {}
            for key in paramsRef.keys {
                paramsCopy[key] = paramsRef[key]!
            }
            log("Executing proposal")
            log(paramsCopy) 
            guildManager.executeDao(guildID: self.guildID, proposalType: proposalRef.type, parameters: proposalRef.getParameters())
            log("Executed proposal")
            proposalRef.markExecuted()
            log("Marked executed")
            emit ProposalExecuted(proposalID: proposalID)
        }
    }

    access(all) fun createDAO(guildID: UInt64): @DAO {
        return <- create DAO(guildID: guildID)
    }
}