import ItemBurner from 0xf8d6e0586b0a20c7

// This transaction calls the burn function in the ItemBurner contract
// to burn an NFT and distribute rewards.

transaction(number: Int, nftId: UInt64, quantity: UFix64) {

    // Corrected the authorization here.
    // The signer is only needed to authorize the transaction,
    // not to access any specific part of their account.
    prepare(signer: auth(Storage) &Account) {
        // Get the ItemBurner contract resource from the contract's account
        let burner = getAccount(0xf8d6e0586b0a20c7).contracts.borrow<&ItemBurner>(name: "ItemBurner")
            ?? panic("Could not borrow a reference to the ItemBurner contract")

        // Call the burn function with the provided parameters
        burner.burn(number: number, nftId: nftId, quantity: quantity)
    }

    execute {
        log("Burn function called successfully")
    }
}