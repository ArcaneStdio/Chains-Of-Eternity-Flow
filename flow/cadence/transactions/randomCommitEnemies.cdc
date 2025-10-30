import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import RandomPicker from 0xf8d6e0586b0a20c7
import QuestManager from 0xf8d6e0586b0a20c7
/// Commits the defined amount of Flow as a bet to the RandomPicker contract, saving the returned Receipt to storage
///
transaction(level: UInt8, rarity: String) {

    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        // Withdraw my bet amount from my FlowToken vault
        //let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)!
        //let bet <- flowVault.withdraw(amount: betAmount)
        let numEnemyTypes = QuestManager.RARITY_ENEMY_COUNT[rarity] ?? panic("Unknown rarity")
        let rarityFactor = QuestManager.RARITY_MULTIPLIER[rarity] ?? panic("Unknown rarity multiplier")
        let totalWeight: UFix64 = UFix64(level) * UFix64(rarityFactor) * 20.0
        let enemy_1 = QuestManager.ENEMIES[numEnemyTypes[0]]
        let weight_enemy1 = QuestManager.ENEMY_WEIGHTS[enemy_1]!
        var maxCount: UFix64 = 1.0

        maxCount = totalWeight / UFix64(weight_enemy1)

        let range1: [UInt64] = []
        var i: UFix64 = 0.0
        while i <= UFix64(maxCount) {
            range1.append(UInt64(i))
            i = i + 1.0
        }
        //let count1 = UFix64(QuestManager.pickRandomValue(values: range1))

        let receipt <- RandomPicker.commit(values: range1)

        // Check that I don't already have a receipt stored
        if signer.storage.type(at: RandomPicker.ReceiptStoragePath) != nil {
            panic("Storage collision at path=".concat(RandomPicker.ReceiptStoragePath.toString()).concat(" a Receipt is already stored!"))
        }

        // Save that receipt to my storage
        // Note: production systems would consider handling path collisions
        signer.storage.save(<-receipt, to: RandomPicker.ReceiptStoragePath)
    }
}
