import HeroNFT from 0x350ca9f549f3afd6
import NonFungibleToken from 0x631e88ae7f1d7c20

transaction(
    recipient: Address
)
{
    /// local variable for storing the minter reference
    let minter: &HeroNFT.NFTMinter
    /// Reference to the receiver's collection
    let recipientCollectionRef: &{NonFungibleToken.Receiver}
    prepare(signer: auth(BorrowValue) &Account) 
    {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.storage.borrow<&HeroNFT.NFTMinter>(from: HeroNFT.MinterStoragePath)
        ?? panic("The signer does not store a HeroNFT Collection object at the path "
        .concat(HeroNFT.CollectionStoragePath.toString())
        .concat("The signer must initialize their account with this collection first!"))

        // Borrow the recipient's public NFT collection reference
        self.recipientCollectionRef = getAccount(recipient).capabilities.borrow<&{NonFungibleToken.Receiver}>(
            HeroNFT.CollectionPublicPath
        ) ?? panic("The account ".concat(recipient.toString()).concat(" does not have a NonFungibleToken Receiver at ")
        .concat(HeroNFT.CollectionPublicPath.toString())
        .concat(". The account must initialize their account with this collection first!"))
    }
    execute 
    {
        let id = HeroNFT.totalSupply
        // Mint the NFT and deposit it to the recipient's collection
        let offensiveStats = HeroNFT.OffensiveStats(
            damage: 10,
            attackSpeed: 1,
            criticalRate: 5,
            criticalDamage: 50
        )
        let defensiveStats = HeroNFT.DefensiveStats(
            maxHealth: 100,
            defense: 10,
            healthRegeneration: 5,
            resistances: [1, 2, 3]
        )
        let specialStats = HeroNFT.SpecialStats(
            maxEnergy: 50,
            energyRegeneration: 5,
            maxMana: 50,
            manaRegeneration: 5
        )
        let statPointsAssigned = HeroNFT.StatPointsAssigned(
            constitution: 10,
            strength: 10,
            dexterity: 10,
            intelligence: 10,
            stamina: 10,
            agility: 10,
            remainingPoints: 0
        )
        let stats = HeroNFT.Stats(
            offensiveStats: offensiveStats,
            defensiveStats: defensiveStats,
            specialStats: specialStats,
            statPointsAssigned: statPointsAssigned
        )
        let mintedNFT <- self.minter.createNFT(
            id: id,
            playerName: "Test Hero",
            playerID: "test123",
            level: 1,
            isBanned: false,
            raceName: "Human",
            equippedItems: [],
            stats: stats,
            imgURL: nil
        )
        self.recipientCollectionRef.deposit(token: <-mintedNFT)
    }
}