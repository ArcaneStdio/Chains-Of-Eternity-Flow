import FungibleToken from 0x9a0766d93b6608b7
import Arcane from 0xf8d6e0586b0a20c7
import Arcane from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7
import RandomPicker from 0xf8d6e0586b0a20c7

access(all) contract QuestManager {

    access(all) event QuestCreated(id: UInt64, level: UInt8, rarity: String, expiresAt: UFix64)
    access(all) event QuestAssigned(id: UInt64, player: Address)
    access(all) event QuestAccepted(id: UInt64, player: Address)
    access(all) event QuestCompleted(id: UInt64, winner: Address, reward: UFix64)
    access(all) event QuestFailed(id: UInt64, reason: String)
    access(all) event QuestRemovedUnclaimed(id: UInt64)
    access(all) event ARCDeposited(amount: UFix64)
    access(all) event ARCWithdrawn(amount: UFix64, to: Address)

  
    access(all) let STATUS_ACTIVE: String
    access(all) let STATUS_COMPLETED: String 
    access(all) let STATUS_FAILED: String 
    //access(all) let STATUS_PENDING: String
    //access(all) let TAKEN = false 

    access(all) let QuestCollectionStoragePath: StoragePath
    access(all) let QuestCollectionPublicPath: PublicPath

    
    access(all) resource Quest {
        access(all) let id: UInt64
        access(all) let level: UInt8                   
        access(all) let rarity: String                 
        access(all) var enemies: [String]             
        access(all) var assignedTo: [Address]          
        access(all) var difficulty: [UInt8]            
        access(all) var expiresAt: UFix64              
        access(all) var status: String                 
        access(all) var createdAt: UFix64
        access(all) var createdBy: Address

        init(
            id: UInt64,
            level: UInt8,
            rarity: String,
            enemies: [String],
            difficulty: [UInt8],
            expiresAt: UFix64,
            createdBy: Address
        ) {
            self.id = id
            self.level = level
            self.rarity = rarity
            self.enemies = enemies
            self.assignedTo = []
            self.difficulty = difficulty
            self.expiresAt = expiresAt
            self.status = QuestManager.STATUS_ACTIVE
            self.createdAt = getCurrentBlock().timestamp
            self.createdBy = createdBy
        }

        access(all) fun accept(player: Address) {
            var exists = false
            for a in self.assignedTo {
                if a == player {
                    exists = true
                    break
                }
            }
            if !exists {
                self.assignedTo.append(player)
            }
        }

        access(all) fun markCompleted() {
            self.status = QuestManager.STATUS_COMPLETED
        }

        access(all) fun markActive() {
            self.status = QuestManager.STATUS_ACTIVE
        }

        access(all) fun markFailed() {
            self.status = QuestManager.STATUS_FAILED
        }

        access(all) fun isExpired(now: UFix64): Bool {
            return now >= self.expiresAt
        }
    }

    
    access(all) resource QuestCollection {
        
        access(all) var ownedQuests: @{UInt64: Quest}

        init() {
            self.ownedQuests <- {}
        }

        access(all) fun deposit(token: @Quest) {
            let id = token.id
            if self.ownedQuests[id] != nil {
                destroy token
                panic("Quest with same ID already exists in collection")
            }
            self.ownedQuests[id] <-! token
        }

        access(all) fun withdraw(id: UInt64): @Quest {
            let q <- self.ownedQuests.remove(key: id) 
                    ?? panic("No Quest with that ID")
            return <- q
        }

        access(all) fun borrowQuest(id: UInt64): &Quest? {
            return &self.ownedQuests[id] as &Quest?
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedQuests.keys
        }

        destroy() {
            destroy self.ownedQuests
        }
    }

  
    access(contract) var nextQuestID: UInt64
    access(all) var activeCountsByLevelAndRarity: {UInt64: {String: UInt64}}

    access(all) let UNCLAIMED_TIMEOUT: UFix64                
    access(all) let RARITY_DURATIONS: {String: UFix64}        
    access(all) let RARITY_DISTRIBUTION: {String: UInt8}      
    access(all) let BASE_REWARD_BY_RARITY: {String: UFix64}   

    access(all) let ARCVaultStoragePath: StoragePath

   
    
    access(all) resource Manager {

        access(all) fun createQuest(
            level: UInt8,
            rarity: String,
            enemies: [String],
            difficulty: [UInt8],
            status: "Active",
            durationIfCreatedNow: UFix64?    
        ): @Quest {

            if !QuestManager.canCreateQuest(level: level, rarity: rarity) {
                panic("No available slot for level ".concat(level.toString()).concat(" rarity ").concat(rarity))
            }

            let now: UFix64 = getCurrentBlock().timestamp
            let duration: UFix64 = durationIfCreatedNow ?? (QuestManager.RARITY_DURATIONS[rarity] ?? panic("No duration"))
            let expiresAt: UFix64 = now + duration

            let id = QuestManager.nextQuestID
            QuestManager.nextQuestID = QuestManager.nextQuestID + 1

            let q <- create Quest(
                id: id,
                level: level,
                rarity: rarity,
                enemies: enemies,
                difficulty: difficulty,
                expiresAt: expiresAt,
                createdBy: self.account.address
            )

            QuestManager.activeCountsByLevelAndRarity[level]![rarity] = (QuestManager.activeCountsByLevelAndRarity[level]![rarity] ?? 0) + 1

            QuestManager.markActive()
            emit QuestCreated(id: id, level: level, rarity: rarity, expiresAt: expiresAt)

            return <- q
        }

        access(all) fun canCreateQuest(level: UInt64, rarity: String): Bool {
            if QuestManager.activeCountsByLevelAndRarity[level] == nil {
                QuestManager.activeCountsByLevelAndRarity[level] = {}
            }

            let currentCount = QuestManager.activeCountsByLevelAndRarity[level]![rarity] ?? 0
            let maxAllowed = QuestManager.RARITY_DISTRIBUTION[rarity] 
                                ?? panic("Unknown rarity ".concat(rarity))

            return currentCount < maxAllowed
        }

        //access(all) fun createAndAssignQuestToCreator(
        //    signer: AuthAccount,
        //    level: UInt8,
        //    rarity: String,
        //    enemies: [String],
        //    difficulty: [UInt8],
        //    durationIfCreatedNow: UFix64?
        //) {
        //    if signer.borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath) == nil {
        //        signer.save(<- QuestManager.createEmptyQuestCollection(), to: QuestManager.QuestCollectionStoragePath)
        //        signer.link<&QuestCollection{PublicQuestCollection}>(QuestManager.QuestCollectionPublicPath, target: QuestManager.QuestCollectionStoragePath)
        //    }
//
        //    let q <- self.createQuest(level: level, rarity: rarity, enemies: enemies, difficulty: difficulty, durationIfCreatedNow: durationIfCreatedNow)
        //    let collectionRef = signer.borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath) 
        //                        ?? panic("Cannot borrow creator's QuestCollection")
        //    collectionRef.deposit(token: <- q)
        //}

        access(all) fun assignQuestToPlayer(quest: @Quest, playerAcct: AuthAccount) {
            if playerAcct.borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath) == nil {
                playerAcct.save(<- QuestManager.createEmptyQuestCollection(), to: QuestManager.QuestCollectionStoragePath)
                playerAcct.link<&QuestCollection{PublicQuestCollection}>(
                    QuestManager.QuestCollectionPublicPath, 
                    target: QuestManager.QuestCollectionStoragePath
                )
            }

            let collectionRef = playerAcct
                .borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath)
                ?? panic("Cannot borrow player's QuestCollection")

            let currentQuestCount = collectionRef.getIDs().length
            if currentQuestCount >= 5 {
                destroy quest  
                panic("Player already has the maximum of 5 quests.")
            }

            let id = quest.id
            collectionRef.deposit(token: <- quest)

            emit QuestAssigned(id: id, player: playerAcct.address)
        }


        //todo -> get the player level from HeroNFT
        access(all) fun acceptQuest(signer: AuthAccount, questID: UInt64, playerLevel: UInt8) {
            let collectionRef = signer.borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath)
                                ?? panic("No QuestCollection for signer")
            let qRef = collectionRef.borrowQuest(questID)
                        ?? panic("Quest not found in collection")

            // level check
            let qLevel = qRef.level
            if qLevel > playerLevel {
                if qLevel - playerLevel > 1 {
                    panic("Player level too low for this quest")
                }
            } else {
                if playerLevel - qLevel > 1 {
                    panic("Player level too high for this quest")
                }
            }

            qRef.accept(signer.address)
            emit QuestAccepted(id: questID, player: signer.address)
        }

        //to be called after 2 days (scheduled transactions)
        access(all) fun destroyQuest<Quest: AnyResource>(quest: @Quest) {
            destroy quest
        }

       
        access(all) fun completeQuest(signer: AuthAccount, questID: UInt64, playerLevel: UInt8) {
            let collectionRef = signer.borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath)
                                ?? panic("No QuestCollection for signer")
            let qRef = collectionRef.borrowQuest(questID)
                        ?? panic("Quest not found in collection")

            let now: UFix64 = getCurrentBlock().timestamp
            if qRef.status != QuestManager.STATUS_ACTIVE {
                panic("Quest not active")
            }
            if qRef.isExpired(now) {
                qRef.markFailed()
                emit QuestFailed(id: questID, reason: "Expired")
                QuestManager.decrementActiveCount(qRef.rarity)
                return
            }

            // ensure signer is in assigned list
            var allowed = false
            for a in qRef.assignedTo {
                if a == signer.address {
                    allowed = true
                    break
                }
            }
            if !allowed {
                panic("Signer has not accepted this quest")
            }

            let baseValue: UFix64 = QuestManager.BASE_REWARD_BY_RARITY[qRef.rarity] 
                ?? panic("No base reward for rarity")

            let randomRange: [UFix64] = [-20.0, -15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0]
            let vrfOutput: UFix64 = QuestManager.pickRandomValue(values: randomRange)

            let variabilityFactor: UFix64 = (vrfOutput * 0.01) + 1.0

            let reward_before_pl: UFix64 = baseValue * UFix64(qRef.level) * UFix64(QuestManager.RARITY_MULTIPLIER[qRef.rarity] ?? 1.0) * variabilityFactor

            let delta: UFix64 = UFix64(qRef.level) - UFix64(playerLevel)

            let reward: UFix64 = 
                if delta = 1.0 {
                    reward_before_pl ** 2.0
                } else if delta == -1.0 {
                    reward_before_pl ** 0.5
                } else {
                    reward_before_pl * 1.0
                }
            let arcVaultRef = self.account.borrow<&Arcane.Vault>(from: QuestManager.ARCVaultStoragePath)
                ?? panic("Contract ARC vault not found or not funded")
            let payout <- arcVaultRef.withdraw(amount: reward)

            
            let playerAccount = getAccount(signer.address)
            let receiverCap = playerAccount.getCapability<&{FungibleToken.Receiver}>(Arcane.ReceiverPublicPath)
            if !receiverCap.check() {
                destroy payout
                panic("Player does not have ARC receiver set up")
            }

            let receiverRef = receiverCap.borrow() ?? panic("Could not borrow player's ARC receiver")
            receiverRef.deposit(from: <- payout)

            qRef.markCompleted()
            QuestManager.decrementActiveCount(qRef.rarity)

            emit QuestCompleted(id: questID, winner: signer.address, reward: reward)
        }

        access(all) fun expireQuestForPlayer(playerAcct: AuthAccount, questID: UInt64) {
            let collectionRef = playerAcct.borrow<&QuestCollection>(from: QuestManager.QuestCollectionStoragePath)
                ?? panic("Player has no QuestCollection")

            let questRef = collectionRef.borrowQuest(questID)
            if questRef == nil { return } 

            let now = getCurrentBlock().timestamp
            if questRef!.isExpired(now) && questRef!.status == QuestManager.STATUS_ACTIVE {
                // Remove quest from just this player
                let quest <- collectionRef.withdraw(withdrawID: questID)

                // Optionally destroy the resource or just mark failed for the user
                quest.markFailed()  // marks as failed for this user
                destroy quest  // completely frees the resource from this player's collection

                emit QuestFailed(id: questID, player: playerAcct.address, reason: "Expired for player")
            }
        }


        // This function is intended to be called via scheduled transactions
       // access(all) fun cleanup(creator: Address) {
       //     let acct = getAccount(creator)
       //     let collectionRef = acct.getCapability(QuestManager.QuestCollectionPublicPath)
       //                         .borrow<&QuestCollection>()
       //     if collectionRef == nil { return }
//
       //     let now = getCurrentBlock().timestamp
//
       //     let ids = collectionRef!.getIDs()
       //     for id in ids {
       //         let qRef = collectionRef!.borrowQuest(id) 
       //         if qRef == nil { continue }
       //         if qRef!.assignedTo.length == 0 && now >= (qRef!.createdAt + QuestManager.UNCLAIMED_TIMEOUT) {
       //             let removed <- collectionRef!.withdraw(id: id)
       //             QuestManager.decrementActiveCount(removed.rarity)
       //             destroy removed
       //             emit QuestRemovedUnclaimed(id: id)
       //         }
       //     }
       // }
//
    } 

    access(all) fun pickRandomValue<T: AnyStruct>(values: [T]): T {
        pre {
            values.length > 0: "Values array cannot be empty"
        }
        let receipt <- RandomPicker.commit(values: values)
        let result: T = RandomPicker.reveal(receipt: <-receipt)

        return result
    }

   
    access(all) resource interface PublicQuestCollection {
        access(all) fun getIDs(): [UInt64]
        access(all) fun borrowQuest(id: UInt64): &Quest?
    }

    
    access(contract) fun decrementActiveCount(rarity: String) {
        let cur = self.activeCountsByRarity[rarity] ?? panic("Unknown rarity")
        if cur == 0 {
            self.activeCountsByRarity[rarity] = 0
        } else {
            self.activeCountsByRarity[rarity] = cur - UInt8(1)
        }
    }

    access(all) fun createEmptyQuestCollection(): @QuestCollection {
        return <- create QuestCollection()
    }

    //self arc deposit function
    access(all) fun depositARC(from: @Arcane.Vault) {
        if self.account.borrow<&Arcane.Vault>(from: self.ARCVaultStoragePath) == nil {
            self.account.save(<- from, to: self.ARCVaultStoragePath)
            emit ARCDeposited(amount: from.balance)
            return
        } else {
            let vaultRef = self.account.borrow<&Arcane.Vault>(from: self.ARCVaultStoragePath) 
                            ?? panic("Contract ARC vault missing after check")
            vaultRef.deposit(from: <- from)
            emit ARCDeposited(amount: from.balance)
        }
    }

    // withdraw ARC by contract owner (for admin)
    access(all) fun withdrawARCAdmin(amount: UFix64, to: Address) {
        let vaultRef = self.account.borrow<&Arcane.Vault>(from: self.ARCVaultStoragePath)
                        ?? panic("Contract ARC vault not found")
        let payout <- vaultRef.withdraw(amount: amount)
        let recipient = getAccount(to)
        let receiverCap = recipient.getCapability<&{FungibleToken.Receiver}>(/public/arcReceiver)
        if !receiverCap.check() { destroy payout; panic("Recipient has no ARC receiver") }
        let recv = receiverCap.borrow() ?? panic("Cannot borrow recipient receiver")
        recv.deposit(from: <- payout)
        emit ARCWithdrawn(amount: amount, to: to)
    }

    access(contract) fun createManager(): @Manager {
        return <- create Manager()
    }

    init() {
        self.STATUS_ACTIVE = "ACTIVE"
        self.STATUS_COMPLETED = "COMPLETED"
        self.STATUS_FAILED = "FAILED"
        //self.STATUS_PENDING = "PENDING"

        self.QuestCollectionStoragePath = /storage/QuestCollection
        self.QuestCollectionPublicPath = /public/QuestCollection

        self.nextQuestID = 1
        self.activeCountsByRarity = {}

        self.TIMEOUT = 172800.0 //2 days    

        
        self.RARITY_DURATIONS = {
            "S": 86400.0,   
            "A": 43200.0,   
            "B": 21600.0,   
            "C": 3600.0     
        }

        self.RARITY_DISTRIBUTION = {
            "S": 1,
            "A": 2,
            "B": 3,
            "C": 4
        }

        self.BASE_REWARD_BY_RARITY = {
            "S": 100.0,
            "A": 40.0,
            "B": 20.0,
            "C": 10.0
        }

        self.ARCVaultStoragePath = /storage/arcVault

        for key in self.RARITY_DISTRIBUTION.keys {
            self.activeCountsByRarity[key] = 0
        }

        let manager <- self.createManager()
        self.account.save(<- manager, to: /storage/QuestManager)
    }
}

//todo:
//VRF implementation for enemy
//Scheduled transactions
//user level
//doubt -> how to start timer per user?