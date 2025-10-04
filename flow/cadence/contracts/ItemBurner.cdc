import NonFungibleToken from 0xf8d6e0586b0a20c7
import ItemManager from 0xf8d6e0586b0a20c7
import FungibleToken from 0xee82856bf20e2aa6
import Arcane from 0xf8d6e0586b0a20c7

access(all) contract ItemBurner {

    // Event emitted when an NFT is stored in the burner
    access(all) event Stored(nftId: UInt64)

    // Event emitted when an NFT is burned and a reward is determined
    access(all) event Burnt(nftId: UInt64, rewardType: String, quantity: UFix64, receiver: Address)

    // Path for the contract's NFT collection
    access(all) let CollectionStoragePath: StoragePath

    // Dictionary to store the original owner of each NFT
    access(self) var nftIdToOwner: {UInt64: Address}

    // Stores the NFT Collection in the contract's storage
    init() {
        self.CollectionStoragePath = /storage/BurnerNFTCollection
        self.nftIdToOwner = {}

        // Create a new empty collection and save it to the account's storage
        let collection <- ItemManager.createEmptyCollection(nftType: Type<@ItemManager.NFT>())
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)
    }

    // Function to store an item NFT in the burner contract
    access(all) fun storeItem(item: @ItemManager.NFT, add: Address) {
        let collection <- self.account.storage.load<@ItemManager.Collection>(from: self.CollectionStoragePath)
            ?? panic("Could not load the burner's collection")

        let nftId = item.id
        // We need to get the owner's address before the item is moved.
        self.nftIdToOwner[nftId] = add
        
        collection.deposit(token: <-item)
        
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)
        
        emit Stored(nftId: nftId)
    }

    // Function to burn an NFT and determine the reward
    access(all) fun burn(number: Int, nftId: UInt64, quantity: UFix64) {
        let collection <- self.account.storage.load<@ItemManager.Collection>(from: self.CollectionStoragePath)
            ?? panic("Could not load the burner's collection")

        let item <- collection.withdraw(withdrawID: nftId) as! @ItemManager.NFT
        
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)
        
        destroy item

        let receiverAddress = self.nftIdToOwner[nftId]!
        self.nftIdToOwner.remove(key: nftId)

        var rewardType = "Arc"
        if number == 10 {
            rewardType = "Item"
        }

        if rewardType == "Arc" {
            let vault <- self.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
                ?? panic("Could not load the contract's Arcane vault")

            let receiver = getAccount(receiverAddress).capabilities.get<&{FungibleToken.Receiver}>(Arcane.ReceiverPublicPath)
                .borrow() ?? panic("Could not borrow receiver reference to the recipient's Vault")

            let sentVault <- vault.withdraw(amount: quantity)
            receiver.deposit(from: <-sentVault)
            
            self.account.storage.save(<-vault, to: Arcane.VaultStoragePath)
        }

        emit Burnt(nftId: nftId, rewardType: rewardType, quantity: quantity, receiver: receiverAddress)
    }
    
    // Function to deposit Arcane tokens into the burner contract for rewards
    access(all) fun depositArc(from: @Arcane.Vault) {
        let vault <- self.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
            ?? panic("Could not load the contract's Arcane vault")
        
        vault.deposit(from: <-from)
        
        self.account.storage.save(<-vault, to: Arcane.VaultStoragePath)
    }
}