access(all) contract GuildInterfaces {
    // --- DAO Events ---
    
    
    access(all) event ProposalDefeated(proposalID: UInt64)

    // --- (Previous interfaces: GuildPublic, GuildAdmin) ---

    access(all) resource interface GuildPublic {
        access(all) let guildID: UInt64
        access(all) let guildName: String
        access(all) var members: {Address: UFix64}

        access(all) fun getMembers(): [Address]
        access(all) fun isMember(addr: Address): Bool
    }

    // Admin interface for a Guild (for guilds with <= 5 members)
    access(all) resource interface GuildAdmin {
        access(all) fun addMember(addr: Address, ownershipPercentage: UFix64)
        access(all) fun removeMember(addr: Address)
        access(all) fun updateOwnership(newOwnership: {Address: UFix64})
        access(all) fun purchasePerk(perkID: UInt64)
        access(all) fun upgradePerk(perkID: UInt64)
    }

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

    access(all) resource Proposal {
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
        
        access(all) view fun hasVoted(voter: Address): Bool {
            return self.votes.containsKey(voter)
        }
        access(all) fun updateVotesFor(Weight: UFix64) {
            self.votesFor = self.votesFor + Weight
        }
        access(all) fun updateVotesAgainst(Weight: UFix64) {
            self.votesAgainst = self.votesAgainst + Weight
        }
        access(all) fun addVote(voter: Address, inFavor: Bool) {
            pre { !(self.votes.containsKey(voter)): "Voter has already cast a vote." }
            self.votes[voter] = inFavor
        }

        access(all) fun updateStatus() {
            // Do nothing if the proposal is already decided
            if self.status != ProposalStatus.active {
                log("Proposal is already decided")
                return
            }

            // --- ADD THIS CHECK ---
            // Only update the status if the voting period has actually ended.
            if getCurrentBlock().timestamp > self.votingEndTime {
                if self.votesFor > self.votesAgainst {
                    self.status = ProposalStatus.succeeded
                    log("Proposal succeeded")
                } else {
                    self.status = ProposalStatus.defeated
                    log("Proposal defeated")
                }
            }else {
                log("Voting period is still active; cannot update status yet.")
            }
        }

        access(all) fun markExecuted() {
            log("marking executed")
            self.status = ProposalStatus.executed
            return
        }

        access(all) fun getParameters(): {String: AnyStruct} {
            return self.parameters
        }
    }
    access(all) resource interface Executor { access(all) fun executeDao(guildID: UInt64, proposalType: ProposalType, parameters: {String: AnyStruct}) }
    // --- Governance interface now uses the Proposal resource ---
   

    access(all) fun createProposal(proposalID: UInt64, proposer: Address, description: String, type: ProposalType, parameters: {String: AnyStruct}, duration: UFix64): @Proposal {
        return <- create Proposal(proposalID: proposalID, proposer: proposer, description: description, type: type, parameters: parameters, duration: duration)
    }

}