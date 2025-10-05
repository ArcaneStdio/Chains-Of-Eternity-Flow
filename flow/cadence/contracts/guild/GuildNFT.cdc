import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import GuildInterfaces from "./GuildInterfaces.cdc"

access(all) contract GuildNFT: NonFungibleToken {

    access(all) var totalSupply: UInt64

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    access(all) event ContractInitialized()
    access(all) event Withdrawn(type: String, id: UInt64, uuid: UInt64, from: Address?, providerUUID: UInt64)
    access(all) event Deposited(type: String, id: UInt64, uuid: UInt64, to: Address?, collectionUUID: UInt64)

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath: self.CollectionPublicPath,
                    publicCollection: Type<&GuildNFT.Collection>(),
                    publicLinkedType: Type<&GuildNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-GuildNFT.createEmptyCollection(nftType: Type<@GuildNFT.NFT>())
                    })
                )
                return collectionData
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "Add your own SVG+XML link here"
                    ),
                    mediaType: "image/svg+xml"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The GuildManager Example Collection",
                    description: "This collection is used as an example for the GuildManager contract.",
                    externalURL: MetadataViews.ExternalURL("Add your own link here"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("Add a link to your project's twitter")
                    }
                )
        }
        return nil
    }

    access(all) resource NFT: NonFungibleToken.NFT, GuildInterfaces.GuildPublic, ViewResolver.Resolver {
        access(all) let guildID: UInt64
        access(all) let guildName: String
        access(all) var members: {Address: UFix64}
        access(all) let id: UInt64

        access(all) event ResourceDestroyed(id: UInt64 = self.id, uuid: UInt64 = self.uuid)

        init(guildID: UInt64, guildName: String, owner: Address) {
            self.id = self.uuid
            self.guildID = guildID
            self.guildName = guildName
            self.members = {owner: 100.0}
        }

        access(all) fun addMember(addr: Address, ownership: UFix64) {
            pre {
                self.members.keys.length <= 5: "Admin actions are disabled for guilds with more than 5 members. Use DAO governance."
                !self.members.containsKey(addr): "Address is already a member."
            }
            self.members[addr] = ownership
        }
        
        access(all) fun removeMember(addr: Address) {
            pre {
                self.members.keys.length <= 5: "Admin actions are disabled for guilds with more than 5 members. Use DAO governance."
                self.members.containsKey(addr): "Address is not a member."
            }
            self.members.remove(key: addr)
        }

        access(all) fun updateOwnership(newOwnership: {Address: UFix64}) {
            pre {
                self.members.keys.length <= 5: "Admin actions are disabled for guilds with more than 5 members. Use DAO governance."
            }
            self.members = newOwnership
        }

        access(contract) fun privilegedAddMember(addr: Address, ownership: UFix64) {
            pre { 
                !self.members.containsKey(addr): "Address is already a member." 
            }
            self.members[addr] = ownership
        }
        access(contract) fun privilegedRemoveMember(addr: Address) {
            pre { self.members.containsKey(addr): "Address is not a member." }
            self.members.remove(key: addr)
        }
        
        access(all) fun getMembers(): [Address] {
            return self.members.keys
        }

        access(all) view fun isMember(addr: Address): Bool {
            return self.members.containsKey(addr)
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Collection()
        }
        
        access(all) view fun getViews(): [Type] {
            return [Type<@GuildNFT.NFT>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            pre {
                emit Deposited(type: token.getType().identifier, id: token.id, uuid: token.uuid, to: self.owner?.address, collectionUUID: self.uuid)
            }
            let token <- token as! @NFT
            let id = token.id
            self.ownedNFTs[id] <-! token
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            return <-token
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
        }

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) fun forEachID(_ f: fun (UInt64): Bool): Void {
            self.ownedNFTs.forEachKey(f)
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@GuildNFT.NFT>(): true}
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@GuildNFT.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Collection()
        }

        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        init() {
            self.ownedNFTs <- {}
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    access(all) resource Minter {
        access(all) fun createGuildNFT(guildID: UInt64, guildName: String, owner: Address): @NFT {
            let newNFT <- create NFT(guildID: guildID, guildName: guildName, owner: owner)
            return <-newNFT
        }
    }

    access(all) resource Admin {
        access(all) fun addMember(ownerAddress: Address, nftID: UInt64, memberAddress: Address, ownership: UFix64) {
            let collectionRef = getAccount(ownerAddress).capabilities
                .borrow<&{NonFungibleToken.CollectionPublic}>(GuildNFT.CollectionPublicPath)
                ?? panic("Could not borrow public collection from owner.")

            let nftRef = collectionRef.borrowNFT(nftID) ?? panic("NFT not found in collection.")
            let guildNFTRef = nftRef as! &GuildNFT.NFT
            guildNFTRef.privilegedAddMember(addr: memberAddress, ownership: ownership)
        }

        access(all) fun removeMember(ownerAddress: Address, nftID: UInt64, memberAddress: Address) {
            let collectionRef = getAccount(ownerAddress).capabilities
                .borrow<&{NonFungibleToken.CollectionPublic}>(GuildNFT.CollectionPublicPath)
                ?? panic("Could not borrow public collection from owner.")
            let nftRef = collectionRef.borrowNFT(nftID) ?? panic("NFT not found in collection.")
            let guildNFTRef = nftRef as! &GuildNFT.NFT
            guildNFTRef.privilegedRemoveMember(addr: memberAddress)
        }
    }

    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/GuildNFTCollection
        self.CollectionPublicPath = /public/GuildNFTCollection
        self.MinterStoragePath = /storage/GuildNFTMinter

        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        
        self.account.storage.save(<-create Admin(), to: /storage/GuildNFTAdmin)
        
        emit ContractInitialized()
    }
}