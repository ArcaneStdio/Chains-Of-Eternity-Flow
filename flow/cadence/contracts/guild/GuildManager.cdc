// Import all necessary contracts with their deployed addresses
import NonFungibleToken from 0xf8d6e0586b0a20c7
import GuildNFT from 0xf8d6e0586b0a20c7
import GuildInterfaces from 0xf8d6e0586b0a20c7
import GuildDAO from 0xf8d6e0586b0a20c7

access(all) contract GuildManager {

    // --- Events ---
    access(all) event GuildCreated(guildID: UInt64, guildName: String, owner: Address)

    // --- Contract State Variables ---
    access(all) var nextGuildID: UInt64
    access(self) var guildRegistry: {UInt64: GuildInfo}
    access(self) let guildDAOs: @{UInt64: GuildDAO.DAO}

    // --- Capability Paths ---
    access(all) let ExecutorStoragePath: StoragePath
    access(all) let ExecutorPrivatePath: PrivatePath
    access(all) let ExecutorPublicPath: PublicPath

    // --- Structs and Interfaces ---

    // Holds the dynamic location info for each Guild NFT.
    access(all) struct GuildInfo {
        access(all) let nftID: UInt64
        access(all) var owner: Address

        init(nftID: UInt64, owner: Address) {
            self.nftID = nftID
            self.owner = owner
        }
    }

    // Interface for the DAO to call for executing proposals.
    access(all) resource interface Executor {
        access(all) fun executeDao(guildID: UInt64, proposalType: GuildDAO.ProposalType, parameters: {String: AnyStruct})
    }

    // --- Core Resources ---

    // Private resource to handle the actual logic of executing a proposal.
    // This is kept private to ensure it can only be called through a secure capability.
    access(self) resource ExecutorImpl: Executor {
        access(all) fun executeDao(guildID: UInt64, proposalType: GuildDAO.ProposalType, parameters: {String: AnyStruct}) {
            // Borrow a reference to the Guild NFT using the contract's public function
            let nftRef = GuildManager.borrowGuildNFT(guildID: guildID)

            switch proposalType {
                case GuildDAO.ProposalType.addMember:
                    let memberAddress = parameters["memberAddress"] as! Address
                    let ownership = parameters["ownership"] as! UFix64
                    // Call the new privileged function on the NFT
                    nftRef.addMember(addr: memberAddress, ownership: ownership)
                    log("Executed: Add member ".concat(memberAddress.toString()))

                case GuildDAO.ProposalType.kickMember:
                    let memberAddress = parameters["memberAddress"] as! Address
                    // Call the new privileged function on the NFT
                    nftRef.removeMember(addr: memberAddress)
                    log("Executed: Kick member ".concat(memberAddress.toString()))

                case GuildDAO.ProposalType.purchasePerk:
                    // Here you would add logic to interact with the PerkMarketplace
                    // The guild would need its own FLOW vault, managed by the GuildManager
                    log("Executed: Purchase perk")
                
                // ... handle other proposal types
            }
        }
    }

    // --- Public Functions ---

    access(all) fun createGuild(name: String, owner: auth(Storage, Capabilities) &Account) {
        // Prepare the NFT Minter
        let minter = self.account.storage.borrow<&GuildNFT.Minter>(from: GuildNFT.MinterStoragePath)
            ?? panic("Could not borrow GuildNFT minter")

        let guildID = self.nextGuildID
        
        // Mint the new Guild NFT
        let newNFT <- minter.createGuildNFT(guildID: guildID, guildName: name, owner: owner.address)

        // Register the new guild in our registry
        self.guildRegistry[guildID] = GuildInfo(nftID: newNFT.id, owner: owner.address)

        // Check if the owner has a collection, if not, create one
        if owner.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath) == nil {
            let collection <- GuildNFT.createEmptyCollection(nftType: Type<@GuildNFT.NFT>())
            owner.storage.save(<-collection, to: GuildNFT.CollectionStoragePath)
            owner.capabilities.publish(
                owner.capabilities.storage.issue<&GuildNFT.Collection>(GuildNFT.CollectionStoragePath),
                at: GuildNFT.CollectionPublicPath
            )
        }

        // Deposit the NFT into the owner's collection
        let collectionRef = owner.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath)
            ?? panic("Could not borrow GuildNFT collection reference")
        collectionRef.deposit(token: <-newNFT)

        emit GuildCreated(guildID: guildID, guildName: name, owner: owner.address)
        self.nextGuildID = self.nextGuildID + 1
        
        // Create and store the DAO for the new guild
        let nftRef = self.borrowGuildNFT(guildID: guildID)
        let newDAO <- GuildDAO.createDAO(guildID: guildID, guildNFTRef: nftRef)
        self.guildDAOs[guildID] <-! newDAO
    }

    access(all) fun transferGuild(guildID: UInt64, recipient: auth(Capabilities) &Account) {
        let guildInfo = self.guildRegistry[guildID] ?? panic("Guild not found.")
        let ownerAddress = guildInfo.owner
        let nftID = guildInfo.nftID

        let senderCollectionRef = getAccount(ownerAddress).storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath)
            ?? panic("Could not borrow sender's collection.")

        let guildToken <- senderCollectionRef.withdraw(withdrawID: nftID)

        if recipient.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath) == nil {
            let newCollection <- GuildNFT.createEmptyCollection(nftType: Type<@GuildNFT.NFT>())
            recipient.storage.save(<-newCollection, to: GuildNFT.CollectionStoragePath)
            recipient.capabilities.publish(
                 recipient.capabilities.storage.issue<&GuildNFT.Collection>(GuildNFT.CollectionStoragePath),
                at: GuildNFT.CollectionPublicPath
            )
        }

        let recipientCollectionRef = recipient.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath)!
        recipientCollectionRef.deposit(token: <-guildToken)

        // CRITICAL: Update the owner's address in the registry.
        self.guildRegistry[guildID]!.owner = recipient.address
    }

    // --- Read-Only Helper Functions ---

    access(all) fun borrowGuildDAO(guildID: UInt64): &GuildDAO.DAO? {
        return &self.guildDAOs[guildID] as &GuildDAO.DAO?
    }

    access(all) fun borrowGuildNFT(guildID: UInt64): &GuildNFT.NFT {
        let guildInfo = self.guildRegistry[guildID] ?? panic("Guild with this ID does not exist in the registry.")
        let ownerAddress = guildInfo.owner
        let nftID = guildInfo.nftID

        let ownerCollection = getAccount(ownerAddress).capabilities.borrow<&{NonFungibleToken.CollectionPublic}>(GuildNFT.CollectionPublicPath)
            ?? panic("Could not borrow public collection capability for guild owner.")

        let nftRef = ownerCollection.borrowNFT(id: nftID)
            ?? panic("NFT not found in owner's collection.")

        return nftRef as! &GuildNFT.NFT
    }

    // --- Contract Initialization ---
    init() {
        self.nextGuildID = 1
        self.guildDAOs <- {}
        self.guildRegistry = {} // Correctly initialize the registry

        self.ExecutorStoragePath = /storage/GuildManagerExecutor
        self.ExecutorPrivatePath = /private/GuildManagerExecutor
        self.ExecutorPublicPath = /public/GuildManagerExecutor

        // Save the Executor implementation and link it via a private capability
        self.account.storage.save(<-create ExecutorImpl(), to: self.ExecutorStoragePath)
        
        let cap = self.account.capabilities.storage.issue<&ExecutorImpl>(self.ExecutorStoragePath)
        self.account.capabilities.publish(cap, at: self.ExecutorPublicPath)
    }
}