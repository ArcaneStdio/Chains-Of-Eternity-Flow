import NonFungibleToken from 0xf8d6e0586b0a20c7
import GuildInterfaces from 0xf8d6e0586b0a20c7

access(all) contract GuildNFT: NonFungibleToken {

    access(all) var totalSupply: UInt64

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)

    access(all) resource NFT: NonFungibleToken.NFT, GuildInterfaces.GuildPublic {
        access(all) let id: UInt64
        access(all) let guildID: UInt64
        access(all) var guildName: String
        access(all) var members: {Address: UFix64}

        init(guildID: UInt64, guildName: String, owner: Address) {
            self.id = self.uuid
            self.guildID = guildID
            self.guildName = guildName
            self.members = {owner: 100.0}
        }

        access(all) fun getMembers(): [Address] {
            return self.members.keys
        }

        access(all) fun isMember(addr: Address): Bool {
            return self.members.containsKey(addr)
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @NFT
            let id = token.id
            self.ownedNFTs[id] <-! token
        }

        access(all) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            return <-token
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
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

    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/GuildNFTCollection
        self.CollectionPublicPath = /public/GuildNFTCollection
        self.MinterStoragePath = /storage/GuildNFTMinter

        self.account.storage.save(<-create Minter(), to: self.MinterStoragePath)
        emit ContractInitialized()
    }
}