import RandomConsumer from 0xed24dbe901028c5c

transaction {
    prepare(acct: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability , RandomConsumer.Commit) &Account) {
        // Ensure Consumer exists in storage
        if acct.storage.borrow<&RandomConsumer.Consumer>(from: RandomConsumer.ConsumerStoragePath) == nil {
            let consumer <- RandomConsumer.createConsumer()
            acct.storage.save(<-consumer, to: RandomConsumer.ConsumerStoragePath)
        }

        // Borrow reference
        let consumerRef = acct.storage.borrow<&RandomConsumer.Consumer>(from: RandomConsumer.ConsumerStoragePath)
            ?? panic("Consumer not found in storage")

        // Request randomness
        let number = RandomConsumer.getRevertibleRandomInRange(min :1,max :100)

        log(number.toString())
    }
}
