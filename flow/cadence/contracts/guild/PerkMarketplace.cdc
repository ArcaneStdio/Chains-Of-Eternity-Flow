import FungibleToken from "FungibleToken.cdc"
import FlowToken from "FlowToken.cdc"

access(all) contract PerkMarketplace {

    access(all) var nextPerkID: UInt64
    access(all) let perks: {UInt64: Perk}

    access(all) event PerkPurchased(guildID: UInt64, perkID: UInt64)
    access(all) event PerkUpgraded(guildID: UInt64, perkID: UInt64, newLevel: UInt64)

    access(all) struct Perk {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let basePrice: UFix64
        access(all) let upgradeMultiplier: UFix64

        init(id: UInt64, name: String, basePrice: UFix64, upgradeMultiplier: UFix64) {
            self.id = id
            self.name = name
            self.basePrice = basePrice
            self.upgradeMultiplier = upgradeMultiplier
        }
    }

    access(all) resource Buyer {
        access(all) fun purchase(perkID: UInt64, payment: @{FungibleToken.Vault}): @{FungibleToken.Vault} {
            let perk = PerkMarketplace.perks[perkID] ?? panic("Perk does not exist")
            assert(payment.balance >= perk.basePrice, message: "Insufficient payment")
            // Logic for purchasing a perk
            // Return change
            return <- payment
        }

        access(all) fun upgrade(perkID: UInt64, currentLevel: UInt64, payment: @{FungibleToken.Vault}): @{FungibleToken.Vault} {
            let perk = PerkMarketplace.perks[perkID] ?? panic("Perk does not exist")
            let upgradeCost = perk.basePrice * (perk.upgradeMultiplier ** UFix64(currentLevel))
            assert(payment.balance >= upgradeCost, message: "Insufficient payment for upgrade")
            // Logic for upgrading a perk
            // Return change
            return <- payment
        }
    }

    access(all) fun createBuyer(): @Buyer {
        return <- create Buyer()
    }

    init() {
        self.nextPerkID = 1
        self.perks = {}
        // You can add some initial perks here
    }
}