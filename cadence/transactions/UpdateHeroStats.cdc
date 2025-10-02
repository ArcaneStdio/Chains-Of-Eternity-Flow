import HeroNFT from 0x0095f13a82f1a835
import NonFungibleToken from 0x631e88ae7f1d7c20

transaction(nftID: UInt64) {
    let nftRef: &HeroNFT.NFT

    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow the signer’s HeroNFT.Collection
        let collectionRef = signer.storage.borrow<&HeroNFT.Collection>(
            from: HeroNFT.CollectionStoragePath
        ) ?? panic("❌ No HeroNFT.Collection found in signer’s account storage")

        // Borrow & downcast the specific NFT reference
        self.nftRef = collectionRef.borrowNFT(nftID) as! &HeroNFT.NFT
    }

    execute {
        // Build new stats
        let newOffensive = HeroNFT.OffensiveStats(
            damage: 20,
            attackSpeed: 2,
            criticalRate: 10,
            criticalDamage: 100
        )
        let newDefensive = HeroNFT.DefensiveStats(
            maxHealth: 200,
            defense: 20,
            healthRegeneration: 10,
            resistances: [4, 5, 6]
        )
        let newSpecial = HeroNFT.SpecialStats(
            maxEnergy: 75,
            energyRegeneration: 10,
            maxMana: 80,
            manaRegeneration: 8
        )
        let newStatPoints = HeroNFT.StatPointsAssigned(
            constitution: 15,
            strength: 20,
            dexterity: 12,
            intelligence: 14,
            stamina: 18,
            agility: 16,
            remainingPoints: 5
        )
        let newStats = HeroNFT.Stats(
            offensiveStats: newOffensive,
            defensiveStats: newDefensive,
            specialStats: newSpecial,
            statPointsAssigned: newStatPoints
        )

        // Update NFT’s hero stats
        self.nftRef.updateHeroStats(newStats: newStats)

        log("✅ Hero stats updated successfully for NFT ".concat(nftID.toString()))
    }
}
