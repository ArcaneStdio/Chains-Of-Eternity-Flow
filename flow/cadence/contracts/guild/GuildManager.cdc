import "NonFungibleToken"
import GuildNFT from "./GuildNFT.cdc"
import GuildInterfaces from "./GuildInterfaces.cdc"
import GuildDAO from "./GuildDAO.cdc"

access(all) contract GuildManager {

    access(all) event GuildCreated(guildID: UInt64, guildName: String, owner: Address)
    access(all) var nextGuildID: UInt64
    access(self) var guildRegistry: {UInt64: GuildInfo}
    access(self) let guildDAOs: @{UInt64: GuildDAO.DAO}

    access(all) let ExecutorStoragePath: StoragePath
    access(all) let ExecutorPublicPath: PublicPath
    access(all) let ExecutorPrivatePath: PrivatePath

    access(all) struct GuildInfo {
        access(all) let nftID: UInt64
        access(all) var owner: Address
        init(nftID: UInt64, owner: Address) { 
            self.nftID = nftID
            self.owner = owner
        }
    }

    access(all) resource ExecutorImpl: GuildInterfaces.Executor {
        access(all) fun executeDao(guildID: UInt64, proposalType: GuildInterfaces.ProposalType, parameters: {String: AnyStruct}) {
            let guildInfo = GuildManager.guildRegistry[guildID] ?? panic("Guild not found")
            
            // CORRECTED: Borrow the admin resource directly from storage.
            // This is secure because only code in this account can access its own storage.
            log("Borrowing GuildNFT Admin resource")
            let nftAdmin = GuildManager.account.storage.borrow<&GuildNFT.Admin>(from: /storage/GuildNFTAdmin)
                ?? panic("Could not borrow GuildNFT Admin resource")
            log("Borrowed GuildNFT Admin resource")
            switch proposalType {
                case GuildInterfaces.ProposalType.addMember:
                    log("Executing: Add member")
                    log(parameters)
                    let memberAddress = parameters["memberAddress"] as! Address
                    log("lmao")
                    let ownership = parameters["ownership"] as! UFix64
                    log("found ownership")
                    nftAdmin.addMember(
                        ownerAddress: guildInfo.owner,
                        nftID: guildInfo.nftID,
                        memberAddress: memberAddress,
                        ownership: ownership
                    )
                    log("Executed: Add member ")
                case GuildInterfaces.ProposalType.kickMember:
                    let memberAddress = parameters["memberAddress"] as! Address
                    nftAdmin.removeMember(
                        ownerAddress: guildInfo.owner,
                        nftID: guildInfo.nftID,
                        memberAddress: memberAddress
                    )
                    log("Executed: Kick member ".concat(memberAddress.toString()))
                case GuildInterfaces.ProposalType.purchasePerk:
                    log("Executed: Purchase perk")
                default:
                    log("Unhandled proposal type")
                    panic("Unhandled proposal type")
            }
            log("executed asdasd ")
        }
    }

    access(all) fun createGuild(name: String, owner: auth(Storage, Capabilities) &Account) {
        let minter = self.account.storage.borrow<&GuildNFT.Minter>(from: GuildNFT.MinterStoragePath) ?? panic("Could not borrow minter")
        let guildID = self.nextGuildID
        let newNFT <- minter.createGuildNFT(guildID: guildID, guildName: name, owner: owner.address)
        self.guildRegistry[guildID] = GuildInfo(nftID: newNFT.id, owner: owner.address)
        if owner.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath) == nil {
            owner.storage.save(<-GuildNFT.createEmptyCollection(nftType: Type<@GuildNFT.NFT>()), to: GuildNFT.CollectionStoragePath)
            owner.capabilities.publish(owner.capabilities.storage.issue<&GuildNFT.Collection>(GuildNFT.CollectionStoragePath), at: GuildNFT.CollectionPublicPath)
        }
        let collection = owner.storage.borrow<&GuildNFT.Collection>(from: GuildNFT.CollectionStoragePath)!
        collection.deposit(token: <-newNFT)
        emit GuildCreated(guildID: guildID, guildName: name, owner: owner.address)
        self.nextGuildID = self.nextGuildID + 1
        let nftRef = self.borrowGuildNFT(guildID: guildID)
        self.guildDAOs[guildID] <-! GuildDAO.createDAO(guildID: guildID)
    }

    access(all) fun transferGuild(guildID: UInt64, recipient: auth(Capabilities) &Account) {
        return 
    }

    access(all) fun borrowGuildDAO(guildID: UInt64): &GuildDAO.DAO? {
        return &self.guildDAOs[guildID] as &GuildDAO.DAO?
    }

    access(all) fun borrowGuildNFT(guildID: UInt64): &GuildNFT.NFT {
        let guildInfo = self.guildRegistry[guildID] ?? panic("Guild not found.")
        let collection = getAccount(guildInfo.owner).capabilities.borrow<&{NonFungibleToken.CollectionPublic}>(GuildNFT.CollectionPublicPath) ?? panic("Could not borrow public collection.")
        let nftRef = collection.borrowNFT(guildInfo.nftID) ?? panic("NFT not found in collection.")
        return nftRef as! &GuildNFT.NFT
    }

    init() {
        self.nextGuildID = 1
        self.guildDAOs <- {}
        self.guildRegistry = {}
        self.ExecutorStoragePath = /storage/GuildManagerExecutor
        self.ExecutorPublicPath = /public/GuildManagerExecutor
        self.ExecutorPrivatePath = /private/GuildManagerExecutor

        // REMOVED the incorrect capability publishing logic.
        // It is not needed.

        self.account.storage.save(<-create ExecutorImpl(), to: self.ExecutorStoragePath)
        let cap = self.account.capabilities.storage.issue<&ExecutorImpl>(self.ExecutorStoragePath)
        self.account.capabilities.publish(cap, at: self.ExecutorPublicPath)
    }
}