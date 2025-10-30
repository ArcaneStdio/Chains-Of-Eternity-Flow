import QuestManager from 0xf8d6e0586b0a20c7
import HeroNFT from 0xf8d6e0586b0a20c7
import Arcane from 0xf8d6e0586b0a20c7
import FungibleToken from 0xee82856bf20e2aa6
import RandomPicker from 0xf8d6e0586b0a20c7
transaction(questID: UInt64, enemiesDefeated: {String: UInt64}) {
    
    let playerLevel: UInt8
    let heroName: String
    
    prepare(signer: auth(Storage, Capabilities, SaveValue, BorrowValue) &Account) {

        //VRF        

        let receipt <- signer.storage.load<@RandomPicker.Receipt>(from: RandomPicker.ReceiptStoragePath)
            ?? panic("No Receipt found in storage at path=".concat(RandomPicker.ReceiptStoragePath.toString()))

        // Reveal by redeeming my receipt - fingers crossed!
        let winnings = RandomPicker.reveal(receipt: <-receipt)

        //let vrfsignoutput: UInt64 = QuestManager.pickRandomValue(values: randomSign)
        let factor = winnings
        let variabilityFactor: UFix64 = (UFix64(factor) * 0.01) + 1.0


        // Step 1: Get player's Hero NFT and extract level
        let heroCollectionRef = signer.capabilities
            .borrow<&HeroNFT.Collection>(HeroNFT.CollectionPublicPath)
            ?? panic("Player does not have a Hero NFT collection. Please mint a hero first.")
        
        let heroIDs = heroCollectionRef.getIDs()
        
        if heroIDs.length == 0 {
            panic("Player does not have a Hero NFT. Please mint a hero first.")
        }
        
        // Borrow the Hero NFT
        let heroNFTRef = heroCollectionRef.borrowNFT(heroIDs[0])
            ?? panic("Could not borrow Hero NFT")
        
        let heroRef = heroNFTRef as! &HeroNFT.NFT
        
        // Check if hero is banned
        if heroRef.heroData.isBanned {
            panic("This hero is banned and cannot complete quests")
        }
        
        // Get player level (convert from UInt32 to UInt8)
        let heroLevel = heroRef.heroData.level
        self.playerLevel = UInt8(heroLevel)
        self.heroName = heroRef.heroData.playerName
        
        log("=== Quest Completion Details ===")
        log("Hero: ".concat(self.heroName))
        log("Level: ".concat(heroLevel.toString()))
        log("Race: ".concat(heroRef.heroData.raceName))
        log("Quest ID: ".concat(questID.toString()))
        //log("Enemies Defeated: ".concat(enemiesDefeated.toString()))
        
        
        
        // Step 3: Borrow the Manager from QuestManager contract
       // let managerRef = signer.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)
       //     ?? panic("Could not borrow Manager reference from QuestManager contract")

        
        QuestManager.completeQuest(
            signer: signer,
            questID: questID,
            playerLevel: self.playerLevel,
            enemies_defeated: enemiesDefeated,
            variabilityFactor: variabilityFactor
        )
        
        log("Quest completion transaction prepared successfully")
    }
    
    execute {
        log("=== Quest Completed Successfully ===")
        log("Quest ID: ".concat(questID.toString()))
        log("Completed by: ".concat(self.heroName))
        log("Hero Level: ".concat(self.playerLevel.toString()))
        //log("Enemies Defeated: ".concat(enemiesDefeated.toString()))
        log("Reward has been sent to your account")
    }
}