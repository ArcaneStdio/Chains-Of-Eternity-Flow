import NonFungibleToken from 0x631e88ae7f1d7c20
import ItemManager from 0x0095f13a82f1a835

  transaction(
      recipient: Address
  ) {

      /// local variable for storing the minter reference
      let minter: &ItemManager.NFTMinter

      /// Reference to the receiver's collection
      let recipientCollectionRef: &{NonFungibleToken.Receiver}

      prepare(signer: auth(BorrowValue) &Account) {

          // borrow a reference to the NFTMinter resource in storage
          self.minter = signer.storage.borrow<&ItemManager.NFTMinter>(from: ItemManager.MinterStoragePath)
              ?? panic("The signer does not store a ItemManager Collection object at the path "
                          .concat(ItemManager.CollectionStoragePath.toString())
                          .concat("The signer must initialize their account with this collection first!"))

          // Borrow the recipient's public NFT collection reference
          self.recipientCollectionRef = getAccount(recipient).capabilities.borrow<&{NonFungibleToken.Receiver}>(
                  ItemManager.CollectionPublicPath
          ) ?? panic("The account ".concat(recipient.toString()).concat(" does not have a NonFungibleToken Receiver at ")
                  .concat(ItemManager.CollectionPublicPath.toString())
                  .concat(". The account must initialize their account with this collection first!"))
      }

      execute {

          let id: UInt64 = 1
          // Mint the NFT and deposit it to the recipient's collection
          let mintedNFT <- self.minter.createNFT(
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
          self.recipientCollectionRef.deposit(token: <-mintedNFT)
      }
  }
