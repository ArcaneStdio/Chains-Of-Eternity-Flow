// Import necessary contracts with their deployed addresses
import GuildInterfaces from 0xf8d6e0586b0a20c7
import GuildNFT from 0xf8d6e0586b0a20c7
import GuildManager from 0xf8d6e0586b0a20c7
access(all) contract GuildDAO {

    // ... (Enums: ProposalType, ProposalStatus remain the same) ...
    access(all) enum ProposalType: UInt8 {
        access(all) case addMember
        access(all) case kickMember
        access(all) case purchasePerk
        access(all) case upgradePerk
        access(all) case investFlow
    }

    access(all) enum ProposalStatus: UInt8 {
        access(all) case pending
        access(all) case active
        access(all) case succeeded
        access(all) case defeated
        access(all) case executed
    }


    access(all) struct Proposal {
        access(all) let proposalID: UInt64
        access(all) let proposer: Address
        access(all) let description: String
        access(all) let type: ProposalType
        access(all) let parameters: {String: AnyStruct}
        access(all) let creationTime: UFix64
        access(all) let votingEndTime: UFix64
        access(self) var votes: {Address: Bool}
        access(all) var votesFor: UFix64
        access(all) var votesAgainst: UFix64
        access(all) var status: ProposalStatus

        init(proposalID: UInt64, proposer: Address, description: String, type: ProposalType, parameters: {String: AnyStruct}, duration: UFix64) {
            self.proposalID = proposalID
            self.proposer = proposer
            self.description = description
            self.type = type
            self.parameters = parameters
            self.creationTime = getCurrentBlock().timestamp
            self.votingEndTime = self.creationTime + duration
            self.votes = {}
            self.votesFor = 0.0
            self.votesAgainst = 0.0
            self.status = ProposalStatus.active
        }

        // FIX: Public function to check if an address has voted.
        access(all) fun hasVoted(voter: Address): Bool {
            return self.votes.containsKey(voter)
        }

        // FIX: Privileged function to add a vote, solving the access control error.
        access(all) fun addVote(voter: Address, inFavor: Bool) {
            pre {
                !self.hasVoted(voter: voter): "Voter has already cast a vote."
            }
            self.votes[voter] = inFavor
        }

        access(all) fun updateStatus() {
            if self.status != ProposalStatus.active { return }
            if getCurrentBlock().timestamp > self.votingEndTime {
                if self.votesFor > self.votesAgainst {
                    self.status = ProposalStatus.succeeded
                } else {
                    self.status = ProposalStatus.defeated
                }
            }
        }
    }

    access(all) resource DAO: GuildInterfaces.GuildGovernance {
        access(all) let guildID: UInt64
        access(self) let guildNFTRef: &GuildNFT.NFT
        access(all) var proposals: {UInt64: Proposal}
        access(self) var nextProposalID: UInt64
        access(all) let votingDuration: UFix64

        init(guildID: UInt64, guildNFTRef: &GuildNFT.NFT) {
            self.guildID = guildID
            self.guildNFTRef = guildNFTRef
            self.proposals = {}
            self.nextProposalID = 1
            self.votingDuration = 259200.0 // 3 days in seconds
        }

        access(all) fun getProposal(proposalID: UInt64): &Proposal? {
            return &self.proposals[proposalID]
        }

        // --- Proposal Creation Functions ---
        access(all) fun createAddMemberProposal(description: String, memberAddress: Address, ownership: UFix64) {
            // FIX: Moved pre-conditions before the function body.
            pre {
                self.guildNFTRef.isMember(self.owner!.address): "Proposer must be a guild member."
                !self.guildNFTRef.isMember(memberAddress): "Address is already a member."
                ownership > 0.0 && ownership <= 1.0: "Invalid ownership percentage. Must be between 0.0 and 1.0."
            }
            let params: {String: AnyStruct} = {"memberAddress": memberAddress, "ownership": ownership}
            self.createProposal(description: description, type: ProposalType.addMember, parameters: params)
        }

        access(all) fun createKickMemberProposal(description: String, memberAddress: Address) {
            pre {
                self.guildNFTRef.isMember(self.owner!.address): "Proposer must be a guild member."
                self.guildNFTRef.isMember(memberAddress): "Address is not a member."
            }
            let params: {String: AnyStruct} = {"memberAddress": memberAddress}
            self.createProposal(description: description, type: ProposalType.kickMember, parameters: params)
        }
        
        // ... other proposal creation functions ...

        access(self) fun createProposal(description: String, type: ProposalType, parameters: {String: AnyStruct}) {
            let proposer = self.owner!.address
            let proposal = Proposal(proposalID: self.nextProposalID, proposer: proposer, description: description, type: type, parameters: parameters, duration: self.votingDuration)
            self.proposals[proposal.proposalID] = proposal
            emit GuildInterfaces.ProposalCreated(guildID: self.guildID, proposalID: self.nextProposalID, proposer: proposer)
            self.nextProposalID = self.nextProposalID + 1
        }

        // --- Voting and Execution ---
        access(all) fun vote(proposalID: UInt64, inFavor: Bool) {
            let voterAddress = self.owner!.address
            let proposalRef = &self.proposals[proposalID] as &Proposal? ?? panic("Proposal not found")
            
            // FIX: Moved pre-conditions before the function body.
            pre {
                self.guildNFTRef.isMember(voterAddress): "Voter must be a guild member.",
                proposalRef.status == ProposalStatus.active: "Proposal is not active for voting.",
                !proposalRef.hasVoted(voter: voterAddress): "Member has already voted.",
                getCurrentBlock().timestamp <= proposalRef.votingEndTime: "Voting period has ended."
            }

            let voteWeight = self.guildNFTRef.members[voterAddress]!
            
            // FIX: Call the new public function to add the vote.
            proposalRef.addVote(voter: voterAddress, inFavor: inFavor)

            if inFavor {
                proposalRef.votesFor = proposalRef.votesFor + voteWeight
            } else {
                proposalRef.votesAgainst = proposalRef.votesAgainst + voteWeight
            }
            
            emit GuildInterfaces.Voted(proposalID: proposalID, voter: voterAddress, inFavor: inFavor, voteWeight: voteWeight)
        }

        access(all) fun executeProposal(proposalID: UInt64) {
            pre {
                proposalRef.status == ProposalStatus.succeeded: "Proposal did not succeed."
            }
            let proposalRef = &self.proposals[proposalID] as &Proposal? ?? panic("Proposal not found")
            proposalRef.updateStatus()

            // FIX: Moved pre-conditions before the function body.
            
            let guildManager = getAccount(self.account.address).capabilities.borrow<&{GuildManager.Executor}>(from: GuildManager.ExecutorPrivatePath)
                ?? panic("Could not borrow GuildManager Executor capability")

            guildManager.executeDao(guildID: self.guildID, proposalType: proposalRef.type, parameters: proposalRef.parameters)
            
            proposalRef.status = ProposalStatus.executed
            emit GuildInterfaces.ProposalExecuted(proposalID: proposalID)
        }
    }

    access(all) fun createDAO(guildID: UInt64, guildNFTRef: &GuildNFT.NFT): @DAO {
        return <- create DAO(guildID: guildID, guildNFTRef: guildNFTRef)
    }
}