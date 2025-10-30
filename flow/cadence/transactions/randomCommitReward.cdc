import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import RandomPicker from 0xf8d6e0586b0a20c7
import QuestManager from 0xf8d6e0586b0a20c7
/// Commits the defined amount of Flow as a bet to the RandomPicker contract, saving the returned Receipt to storage
///
transaction() {

    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        
        let randomRange: [UInt64] = [0, 5, 10, 15, 20]

        //var vrfOutput: UFix64 = UFix64(QuestManager.pickRandomValue(values: randomRange))
        
        if signer.storage.type(at: RandomPicker.ReceiptStoragePath) != nil {
            panic("Storage collision at path=".concat(RandomPicker.ReceiptStoragePath.toString()).concat(" a Receipt is already stored!"))
        }

        let receipt <- RandomPicker.commit(values: randomRange)

        signer.storage.save(<-receipt, to: RandomPicker.ReceiptStoragePath)

    }
}
