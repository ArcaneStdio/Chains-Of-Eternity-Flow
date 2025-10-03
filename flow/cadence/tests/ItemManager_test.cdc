import Test
import "ItemManager" from 

access(all)
fun setUp() {
    let acct = Test.createAccount()

    let err = Test.deployContract(
        name: "ItemManager",
        path: "cadence/contracts/ItemManager.cdc",
        arguments: []
    )

}

// access(all)
// let blockchain = Test.newEmulatorBlockchain()

// access(all)
// let account = blockchain.createAccount()

// access(all)
// fun testExample() {
//     log(account.address)
// }

access(all)
fun testMintItem() {
    let acct = Test.getAccount(0x01)

    //
    // Step 1: Setup storage and capabilities for the admin if not already done
    //

    //
    // Step 3: Mint
    //
    ItemManager.mintItem(
        recipient: recipient,
        name: "Sword of Testing",
        description: "A test sword",
        itemType: ItemManager.ItemType.weapon,
        rarity: ItemManager.Rarity.common,
        stackable: false,
        weapon: ItemManager.WeaponData(damage: 10, durability: 100),
        armour: nil,
        consumable: nil,
        accessory: nil
    )

    //
    // Step 4: Assert totalSupply increment
    //
    Test.assertEqual(
        ItemManager.totalSupply,
        1,
        message: "Total supply should be 1 after minting"
    )

    //
    // Step 5: Verify NFT in collection
    //
    let fullCollection = acct.capabilities.borrow<&ItemManager.Collection>(
        /public/ItemCollection
    ) ?? panic("Could not borrow full collection")

    let nft = fullCollection.borrowNFT(id: 0)
        ?? panic("NFT not found in collection")

    Test.assertEqual(
        nft.name,
        "Sword of Testing",
        message: "NFT name mismatch"
    )
}
