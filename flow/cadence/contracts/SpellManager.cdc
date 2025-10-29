import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7
import ViewResolver from 0xf8d6e0586b0a20c7
import FungibleToken from 0xee82856bf20e2aa6
import Arcane from 0xf8d6e0586b0a20c7

access(all) contract SpellManager: NonFungibleToken {

    access(all) event Minted(
        id: UInt64,
        uuid: UInt64,
        minter: Address,
        spellName: String,
        element: String,
        manaCost: UFix64,
        cooldown: UFix64,
        attackSubtype: String,
        imgURL: String?,
        arcPaid: UFix64
    )

    access(all) event Refunded(
        recipient: Address,
        amount: UFix64,
        //reason: String
    )

    // ===== Enums =====
    access(all) enum ElementType: UInt8 {
        access(all) case Fire
        access(all) case Water
        access(all) case Lightning
        access(all) case Wind
    }

    access(all) fun elementTypeToString(_ element: ElementType): String {
        switch element {
            case ElementType.Fire: return "Fire"
            case ElementType.Water: return "Water"
            case ElementType.Lightning: return "Lightning"
            case ElementType.Wind: return "Wind"
        }
        return "Unknown"
    }

    access(all) enum AttackSubtype: UInt8 {
        access(all) case Projectile
        access(all) case AoE
    }

    access(all) fun attackSubtypeToString(_ subtype: AttackSubtype): String {
        switch subtype {
            case AttackSubtype.Projectile: return "Projectile"
            case AttackSubtype.AoE: return "AoE"
        }
        return "Unknown"
    }

    access(all) enum ProjectilePath: UInt8 {
        access(all) case Straight
        access(all) case ZigZag
        access(all) case Random
        access(all) case Arc
        access(all) case Homing
        access(all) case Circular
    }

    access(all) fun projectilePathToString(_ path: ProjectilePath): String {
        switch path {
            case ProjectilePath.Straight: return "Straight"
            case ProjectilePath.ZigZag: return "ZigZag"
            case ProjectilePath.Random: return "Random"
            case ProjectilePath.Arc: return "Arc"
            case ProjectilePath.Homing: return "Homing"
            case ProjectilePath.Circular: return "Circular"
        }
        return "Unknown"
    }

    // ===== Structs =====
    access(all) struct ProjectileData {
        // Combat Settings
        access(all) let damage: UInt64
        access(all) let knockbackForce: UFix64

        // Movement Settings
        access(all) let movementPath: ProjectilePath
        access(all) let projectileSpeed: UFix64

        // Spawn Settings
        access(all) let projectileSize: UFix64
        access(all) let numberOfProjectiles: UInt64
        access(all) let delayBetweenProjectiles: UFix64
        access(all) let staggeredLaunchAngle: Fix64

        // ZigZag Settings
        access(all) let zigzagAmplitude: UFix64
        access(all) let zigzagFrequency: UFix64

        // Homing Settings
        access(all) let homingDelay: UFix64
        access(all) let homingRadius: UFix64
        access(all) let homingUpdateRate: UFix64

        // Circular Settings
        access(all) let circularInitialRadius: UFix64
        access(all) let circularSpeed: UFix64
        access(all) let circularRadialSpeed: Fix64

        // Random Settings
        access(all) let randomDirectionOffset: UFix64

        // Arc Settings
        access(all) let arcGravityScale: UFix64

        init(
            damage: UInt64,
            knockbackForce: UFix64,
            movementPath: ProjectilePath,
            projectileSpeed: UFix64,
            projectileSize: UFix64,
            numberOfProjectiles: UInt64,
            delayBetweenProjectiles: UFix64,
            staggeredLaunchAngle: Fix64,
            zigzagAmplitude: UFix64,
            zigzagFrequency: UFix64,
            homingDelay: UFix64,
            homingRadius: UFix64,
            homingUpdateRate: UFix64,
            circularInitialRadius: UFix64,
            circularSpeed: UFix64,
            circularRadialSpeed: Fix64,
            randomDirectionOffset: UFix64,
            arcGravityScale: UFix64
        ) {
            self.damage = damage
            self.knockbackForce = knockbackForce
            self.movementPath = movementPath
            self.projectileSpeed = projectileSpeed
            self.projectileSize = projectileSize
            self.numberOfProjectiles = numberOfProjectiles
            self.delayBetweenProjectiles = delayBetweenProjectiles
            self.staggeredLaunchAngle = staggeredLaunchAngle
            self.zigzagAmplitude = zigzagAmplitude
            self.zigzagFrequency = zigzagFrequency
            self.homingDelay = homingDelay
            self.homingRadius = homingRadius
            self.homingUpdateRate = homingUpdateRate
            self.circularInitialRadius = circularInitialRadius
            self.circularSpeed = circularSpeed
            self.circularRadialSpeed = circularRadialSpeed
            self.randomDirectionOffset = randomDirectionOffset
            self.arcGravityScale = arcGravityScale
        }
    }

    access(all) struct AoEData {
        access(all) let damage: UInt64
        access(all) let radius: UFix64
        access(all) let duration: UFix64
        access(all) let knockbackForce: UFix64

        init(
            damage: UInt64,
            radius: UFix64,
            duration: UFix64,
            knockbackForce: UFix64
        ) {
            self.damage = damage
            self.radius = radius
            self.duration = duration
            self.knockbackForce = knockbackForce
        }
    }

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    /// Gets a list of views for all the NFTs defined by this contract
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
                    publicCollection: Type<&SpellManager.Collection>(),
                    publicLinkedType: Type<&SpellManager.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-SpellManager.createEmptyCollection(nftType: Type<@SpellManager.NFT>())
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
                    name: "The SpellManager Collection",
                    description: "This collection manages spell NFTs for your game.",
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

    // ===== Resource: NFT Spell =====
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {
        access(all) let id: UInt64
        
        // Core Info
        access(all) let spellName: String
        access(all) let element: ElementType
        access(all) let manaCost: UFix64
        access(all) let cooldown: UFix64

        // Attack Type
        access(all) let attackSubtype: AttackSubtype
        access(all) let projectileData: ProjectileData?
        access(all) let aoeData: AoEData?
        
        access(all) let imgURL: String?

        init(
            id: UInt64,
            spellName: String,
            element: ElementType,
            manaCost: UFix64,
            cooldown: UFix64,
            attackSubtype: AttackSubtype,
            projectileData: ProjectileData?,
            aoeData: AoEData?,
            imgURL: String?
        ) {
            self.id = id
            self.spellName = spellName
            self.element = element
            self.manaCost = manaCost
            self.cooldown = cooldown
            self.attackSubtype = attackSubtype
            self.projectileData = projectileData
            self.aoeData = aoeData
            self.imgURL = imgURL
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-SpellManager.createEmptyCollection(nftType: Type<@SpellManager.NFT>())
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.spellName,
                        description: "A ".concat(SpellManager.elementTypeToString(self.element))
                                    .concat(" spell of type ")
                                    .concat(SpellManager.attackSubtypeToString(self.attackSubtype)),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.imgURL ?? "ipfs://bafybeidhmg4d7gsiby2jrsilfkntoiq2aknreeeghmgfgltjqiacecpdey"
                        )
                    )
            }
            return nil
        }
    }

    // ===== Resource: Collection =====
    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.ownedNFTs <- {}
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let nft <- token as! @NFT
            self.ownedNFTs[nft.id] <-! nft
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                    ?? panic("SpellManager.Collection.withdraw: Could not withdraw an NFT with ID "
                            .concat(withdrawID.toString())
                            .concat(". Check the submitted ID to make sure it is one that this collection owns."))

            return <-token
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@SpellManager.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-SpellManager.createEmptyCollection(nftType: Type<@SpellManager.NFT>())
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@SpellManager.NFT>()] = true
            return supportedTypes
        }
    }

    // ===== Admin & Minting Logic =====
    access(all) var totalSupply: UInt64

    // public helper to create an empty collection
    access(all) fun createEmptyCollection(nftType: Type): @Collection {
        return <- create Collection()
    }

    // ===== Refund Function =====
    access(all) fun refund(recipient: Address, amount: UFix64, reason: String) {
        let vault <- self.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
            ?? panic("Could not load the contract's Arcane vault")

        let receiver = getAccount(recipient).capabilities.get<&{FungibleToken.Receiver}>(Arcane.ReceiverPublicPath).borrow()
            ?? panic("Could not borrow receiver reference to the recipient's Vault")

        let sentVault <- vault.withdraw(amount: amount)
        receiver.deposit(from: <-sentVault)
        
        self.account.storage.save(<-vault, to: Arcane.VaultStoragePath)

        emit Refunded(recipient: recipient, amount: amount)
    }

    // Function to deposit Arcane tokens into the contract for future refunds
    access(all) fun depositArc(from: @Arcane.Vault) {
        let vault <- self.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
            ?? panic("Could not load the contract's Arcane vault")
        
        vault.deposit(from: <-from)
        
        self.account.storage.save(<-vault, to: Arcane.VaultStoragePath)
    }

    access(all) resource NFTMinter {
        access(all) fun createNFT(
            spellName: String,
            element: SpellManager.ElementType,
            manaCost: UFix64,
            cooldown: UFix64,
            attackSubtype: SpellManager.AttackSubtype,
            projectileData: SpellManager.ProjectileData?,
            aoeData: SpellManager.AoEData?,
            imgURL: String?,
            arcPaid: UFix64
        ): @NFT {
            let newID = SpellManager.totalSupply
            SpellManager.totalSupply = SpellManager.totalSupply + UInt64(1)

            let nft <- create NFT(
                id: newID,
                spellName: spellName,
                element: element,
                manaCost: manaCost,
                cooldown: cooldown,
                attackSubtype: attackSubtype,
                projectileData: projectileData,
                aoeData: aoeData,
                imgURL: imgURL
            )

            emit SpellManager.Minted(
                id: nft.id,
                uuid: nft.uuid,
                minter: self.owner!.address,
                spellName: nft.spellName,
                element: SpellManager.elementTypeToString(element),
                manaCost: manaCost,
                cooldown: cooldown,
                attackSubtype: SpellManager.attackSubtypeToString(attackSubtype),
                imgURL: nft.imgURL,
                arcPaid: arcPaid
            )

            return <- nft
        }

        init() {}
    }

    access(all) fun mintSpell(
        recipient: &{NonFungibleToken.Receiver},
        spellName: String,
        element: ElementType,
        manaCost: UFix64,
        cooldown: UFix64,
        attackSubtype: AttackSubtype,
        projectileData: ProjectileData?,
        aoeData: AoEData?,
        imgURL: String?,
        arcPaid: UFix64
    ) {
        let minter = self.account.storage.borrow<&NFTMinter>(from: self.MinterStoragePath)
            ?? panic("Could not borrow minter reference")
        
        let nft <- minter.createNFT(
            spellName: spellName,
            element: element,
            manaCost: manaCost,
            cooldown: cooldown,
            attackSubtype: attackSubtype,
            projectileData: projectileData,
            aoeData: aoeData,
            imgURL: imgURL,
            arcPaid: arcPaid
        )

        recipient.deposit(token: <- nft)
    }

    init() {
        // initialize manager state
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/SpellManagerNFTCollection
        self.CollectionPublicPath = /public/SpellManagerNFTCollection
        self.MinterStoragePath = /storage/SpellManagerNFTMinter
        
        self.account.storage.save(<-create NFTMinter(), to: self.MinterStoragePath)
    }
}