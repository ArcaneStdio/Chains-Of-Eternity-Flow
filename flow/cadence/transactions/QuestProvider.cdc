import ItemManager from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

transaction {
    prepare(acct: auth(Storage) &Account) {
        // borrow the signer’s receiver
        let receiver = acct.capabilities.borrow<&{NonFungibleToken.Receiver}>(/public/NFTReceiver)
            ?? panic("Could not borrow receiver capability")

        ItemManager.mintItem(
            recipient: receiver,
            name: "Sword of Testing",
            description: "A test sword",
            itemType: ItemManager.ItemType.Weapon,
            rarity: ItemManager.Rarity.Common,
            stackable: false,
            weapon: ItemManager.WeaponData(
                damage: 10,
                attackSpeed: 1,
                criticalRate: 5,
                criticalDamage: 50
            ),
            armour: nil,
            consumable: nil,
            accessory: nil
        )
    }

    execute {
        log("✅ Minted a Sword of Testing")
    }
}
