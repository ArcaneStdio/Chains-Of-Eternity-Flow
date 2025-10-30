import FungibleToken from 0xee82856bf20e2aa6
import Arcane from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7
import RandomPicker from 0xf8d6e0586b0a20c7


access(all) contract QuestManager {

    access(all) event QuestCreated(id: UInt64, level: UInt8, rarity: String, enemies: {String: UInt64} , expiresAt: UFix64)
    access(all) event QuestAssigned(id: UInt64, player: Address)
    access(all) event QuestAccepted(id: UInt64, player: Address)
    access(all) event QuestCompleted(id: UInt64, winner: Address, reward: UFix64)
    access(all) event QuestFailed(id: UInt64, reason: String)
    access(all) event QuestRemoved(id: UInt64)
    access(all) event ARCDeposited(amount: UFix64)
    access(all) event ARCWithdrawn(amount: UFix64, to: Address)

    access(contract) var quests: @{UInt64: Quest}   // contract-owned pool of quest resources
  
    access(all) let ENEMIES: [String]

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
        access(all) var enemies: {String: UInt64}             
        access(all) var assignedTo: [Address]          
        access(all) var expiresAt: UFix64              
        access(all) var status: String                 
        access(all) var createdAt: UFix64
        access(all) var createdBy: Address

        init(
            id: UInt64,
            level: UInt8,
            rarity: String,
            enemies: {String: UInt64},
            expiresAt: UFix64,
            createdBy: Address
        ) {
            self.id = id
            self.level = level
            self.rarity = rarity
            self.enemies = enemies
            self.assignedTo = []
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

        access(all) fun deposit(quest: @Quest) {
            let id = quest.id
            if self.ownedQuests[id] != nil {
                destroy quest
                panic("Quest with same ID already exists in collection")
            }else {
                self.ownedQuests[id] <-! quest
            }
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

    }

  
    access(contract) var nextQuestID: UInt64
    access(all) var activeCountsByLevelAndRarity: {UInt8: {String: UInt64}}

    access(all) let UNCLAIMED_TIMEOUT: UFix64                
    access(all) let RARITY_DURATIONS: {String: UFix64}        
    access(all) let RARITY_DISTRIBUTION: {String: UInt8}
    access(all) let RARITY_MULTIPLIER: {String: UInt8}      
    access(all) let ENEMY_WEIGHTS: {String: UInt64}
    access(all) let RARITY_ENEMY_COUNT: {String: [UInt8]}
    access(all) let BASE_REWARD_BY_RARITY: {String: UFix64}   

    access(all) let ARCVaultStoragePath: StoragePath

   // per-player participation record stored in player's account
    access(all) resource QuestParticipation: QuestParticipationManagerAccess {
        access(all) let questID: UInt64
        access(all) var status: String        // "ACTIVE" | "COMPLETED" | "FAILED" | "EXPIRED"
        access(all) let joinedAt: UFix64
        access(all) var expiresAt: UFix64
    
        init(questID: UInt64, joinedAt: UFix64, expiresAt: UFix64) {
            self.questID = questID
            self.status = "ACTIVE"
            self.joinedAt = joinedAt
            self.expiresAt = expiresAt
        }
    
        // called by manager via capability
        access(all) fun markCompleted() {
            self.status = "COMPLETED"
        }
    
        access(all) fun markFailed() {
            self.status = "FAILED"
        }
    
        access(all) fun markExpired() {
            self.status = "EXPIRED"
        }

        access(all) fun getStatus(): String {
            return self.status
        }
        access(all) fun getExpiry(): UFix64{
            return self.expiresAt
        }

        
    }
    
    // interface player links publicly/private for manager to borrow
    access(all) resource interface QuestParticipationManagerAccess {
        access(all) fun markCompleted()
        access(all) fun markFailed()
        access(all) fun markExpired()
        
        access(all) fun getStatus(): String
        access(all) fun getExpiry(): UFix64
    }

    
    access(all) resource Manager {
        //access(self) var questCollection: @QuestCollection
        
        access(all) fun createQuest(level: UInt8, rarity: String, enemies:{String: UInt64}): UInt64{

            let mgrRef = QuestManager.account.storage.borrow<&QuestManager.Manager>(from: /storage/QuestManager)
                ?? panic("Manager resource not found")
            
            // now call the method on the Manager resource reference
            let canCreateQuest = mgrRef.canCreateQuest(level: level, rarity: rarity)
            if !canCreateQuest {
                panic("No available slot for level ".concat(level.toString()).concat(" rarity ").concat(rarity))
            }

            let now: UFix64 = getCurrentBlock().timestamp
            let duration: UFix64 = QuestManager.RARITY_DURATIONS[rarity] ?? panic("No duration")
            let expiresAt: UFix64 = now + duration
           // let enemies: {String: UInt64} = QuestManager.generateEnemies(level: level, rarity: rarity)

            let id = QuestManager.nextQuestID
            QuestManager.nextQuestID = QuestManager.nextQuestID + 1

            let q <- create Quest(
                id: id,
                level: level,
                rarity: rarity,
                enemies: enemies,
                expiresAt: expiresAt,
                createdBy: QuestManager.account.address
            )

            let innerDict: {String: UInt64} = QuestManager.activeCountsByLevelAndRarity[level]!
            //let triallist = QuestManager.activeCountsByLevelAndRarity[level]
            if innerDict == nil {
                QuestManager.activeCountsByLevelAndRarity[level] = {}
            } else {
                innerDict[rarity] = (innerDict[rarity] ?? 0) + 1 
            }

            QuestManager.activeCountsByLevelAndRarity[level] = innerDict
            
            q.markActive()
            //let q <- create Quest( ... )
            QuestManager.quests[id] <-! q  // store the resource in contract pool
            //self.questCollection.deposit(quest: <-q)
            emit QuestCreated(id: id, level: level, rarity: rarity, enemies: enemies ,expiresAt: expiresAt)
            return id
        }

        access(all) fun canCreateQuest(level: UInt8, rarity: String): Bool {
            if QuestManager.activeCountsByLevelAndRarity[level] == nil {
                QuestManager.activeCountsByLevelAndRarity[level] = {}
            }

            let currentCount = QuestManager.activeCountsByLevelAndRarity[level]![rarity] ?? 0
            let maxAllowed = QuestManager.RARITY_DISTRIBUTION[rarity] 
                                ?? panic("Unknown rarity ".concat(rarity))

            return currentCount < UInt64(maxAllowed)
        }
        


        
        access(all) fun expireParticipantIfNeeded(player: Address, questID: UInt64) {
            let pathStr = "/public/QuestParticipation_".concat(questID.toString())
            let partRef = getAccount(player).capabilities.borrow<&{QuestManager.QuestParticipationManagerAccess}>(PublicPath(identifier: pathStr)!)!
            
            if partRef.getStatus() != nil {
                let status: String = partRef.getStatus()
                if partRef.getStatus() == "ACTIVE" && getCurrentBlock().timestamp >= partRef.getExpiry() {
                    partRef.markExpired()
                    //let playerAcct = getAccount(player)
                    //playerAcct.capabilities.storage.getController(byCapabilityID: questID)

                    //playerAcct.capabilities.unpublish(PublicPath(identifier: pathStr))
                    //let storage_path = "/storage/QuestParticipation_".concat(questID.toString())
                    //let participation <- playerAcct.Capabilities.borrow(&<QuestManager.QuestParticipation>(from: StoragePath(identifier: storage_path)))
                    //    ?? panic("Cannot load participation to expire")
                    //destroy participation

                    emit QuestFailed(id: questID, reason: "Expired for player")
                }
            }
        }

        // This function is intended to be called via scheduled transactions
        access(all) fun cleanupExpiredQuests(questID: UInt64) {
            let now = getCurrentBlock().timestamp

            //for questID in QuestManager.quests.keys {
            let q1: @QuestManager.Quest? <- QuestManager.quests.remove(key: questID)
            if(q1 != nil)
            {
                let q: @QuestManager.Quest <- q1!
                for playerAddr in q.assignedTo {
                    let playerAcct = getAccount(playerAddr)
                    let storagePath = "/storage/QuestParticipation_".concat(questID.toString())
                    let privatePath = "/public/QuestParticipation_".concat(questID.toString())
                    let pathStr = "/public/QuestParticipation_".concat(questID.toString())
                    //let partCap = getAccount(signer.address).capabilities.borrow<&{QuestParticipation.QuestParticipationManagerAccess}>(PublicPath(identifier: pathStr)!)
                    let partRef = playerAcct.capabilities.borrow<&{QuestManager.QuestParticipationManagerAccess}>(PublicPath(identifier: pathStr)!)!
                    partRef.markExpired()
                    //destroy partRef
                   
                    // playerAcct.unlink(privatePath)
                }
                
                QuestManager.decrementActiveCount(level: q.level, rarity: q.rarity)
                destroy q
                emit QuestRemoved(id: questID)
                
            } else {
                destroy q1
            }
        }

        
        //init() {
        //    self.questCollection <- create QuestCollection()
        //}
        


    } 


    access(all) fun completeQuest(signer: auth(SaveValue, BorrowValue) &Account, questID: UInt64, playerLevel: UInt8, enemies_defeated: {String: UInt64}, variabilityFactor: UFix64) {
            //let collectionRef = signer.capabilities.borrow<&QuestCollection>(QuestManager.QuestCollectionPublicPath)
            //                    ?? panic("No QuestCollection for signer")
            //let qRef = collectionRef.borrowQuest(id: questID)
            //            ?? panic("Quest not found in collection")

            let qRef: @QuestManager.Quest <- QuestManager.quests.remove(key: questID)
                ?? panic("Quest not found")

            let now: UFix64 = getCurrentBlock().timestamp
            if qRef.status != QuestManager.STATUS_ACTIVE {
                QuestManager.quests[questID] <-! qRef 
                panic("Quest not active")
            } else if qRef.isExpired(now: now) {
                qRef.markFailed()
                emit QuestFailed(id: questID, reason: "Expired")
                QuestManager.decrementActiveCount(level: qRef.level, rarity: qRef.rarity)
                QuestManager.quests[questID] <-! qRef
                return
            }
            //{"slime": 5, "goblin": 3}
            else if qRef.enemies != enemies_defeated {
                QuestManager.quests[questID] <-! qRef
                panic("Not all enemies defeated")
            } else {

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
    
                //mark for player's reference
                let pathStr = "/public/QuestParticipation_".concat(questID.toString())
                let partCap = signer.capabilities.borrow<&{QuestManager.QuestParticipationManagerAccess}>(PublicPath(identifier: pathStr)!)
                if partCap != nil {
                    let notNullCap: &{QuestManager.QuestParticipationManagerAccess} = partCap!
                    notNullCap.markCompleted()
                    } else {
                    panic("Could not borrow participation reference to mark completed")
                }
    
    
                let baseValue: UFix64 = QuestManager.BASE_REWARD_BY_RARITY[qRef.rarity] 
                    ?? panic("No base reward for rarity")
                let receiverAddress: Address = signer.address
                let randomRange: [UInt64] = [0, 5, 10, 15, 20]
                let randomSign: [UInt64] = [0, 1]
                // var vrfOutput: UFix64 = UFix64(QuestManager.pickRandomValue(values: randomRange))
                // let vrfsignoutput: UInt64 = QuestManager.pickRandomValue(values: randomSign)
                // var factor: Int = 1
                // if vrfsignoutput == 0 {
                //     factor = Int(vrfOutput) * -1
                // }
                // let variabilityFactor: UFix64 = (UFix64(factor) * 0.01) + 1.0
    
                var reward: UFix64 = baseValue * UFix64(qRef.level) * UFix64(QuestManager.RARITY_MULTIPLIER[qRef.rarity] ?? 1.0) * variabilityFactor
    
                let delta: UFix64 = UFix64(qRef.level) - UFix64(playerLevel)
    
    
                if delta == 1.0{
                    reward = reward * 1.2
                } else if delta < 0.0 {
                    reward = reward * 0.7
                } else {
                    reward = reward * 1.0
                }
                
    
                let vault <- QuestManager.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
                    ?? panic("Could not load the contract's Arcane vault")
    
                let receiver = getAccount(signer.address).capabilities.get<&{FungibleToken.Receiver}>(Arcane.ReceiverPublicPath).borrow()
                    ?? panic("Could not borrow receiver reference to the recipient's Vault")
    
                let sentVault <- vault.withdraw(amount: reward)
                receiver.deposit(from: <-sentVault)
                
                QuestManager.account.storage.save(<-vault, to: Arcane.VaultStoragePath)
            
    
                qRef.markCompleted()
                
    
                QuestManager.decrementActiveCount(level: qRef.level, rarity: qRef.rarity)
                QuestManager.quests[questID] <-! qRef 
                emit QuestCompleted(id: questID, winner: signer.address, reward: reward)
            }
            
        }


    access(all) fun joinQuest(playerAcct: auth(Storage, Capabilities, SaveValue)&Account, questID: UInt64, playerLevel: UInt8) {
            let qRef <- QuestManager.quests.remove(key: questID)
                ?? panic("Quest not found")

            let qLevel = qRef.level
            if qLevel > playerLevel {
                if qLevel - playerLevel >= 2 { panic("Too low level") }
            } else {
                if playerLevel - qLevel >= 2 { panic("Too high level") }
            }

            var exists = false
            for a in qRef.assignedTo {
                if a == playerAcct.address { exists = true; break }
            }
            if !exists {
                qRef.assignedTo.append(playerAcct.address)
            }

            let now = getCurrentBlock().timestamp
            let expiresAt = now + (qRef.expiresAt - qRef.createdAt) 
            let participation <- create QuestParticipation(questID: questID, joinedAt: now, expiresAt: expiresAt)

            // save to player's /storage/ path (unique per quest)
            let storagePath: StoragePath = StoragePath(identifier: "/storage/QuestParticipation_".concat(questID.toString()))!
            playerAcct.storage.save(<- participation, to: storagePath)



            // link a private capability so manager & scheduler can borrow it later:
            let linkPath: PublicPath = PublicPath(identifier: "/public/QuestParticipation_".concat(questID.toString()))!
            // playerAcct.capabilities.storage.issue<&{QuestParticipation.QuestParticipationManagerAccess}>(linkPath)
            let cap = playerAcct.capabilities.storage.issue<&{QuestManager.QuestParticipationManagerAccess}>(storagePath)
            playerAcct.capabilities.publish(cap, at: linkPath)
            QuestManager.quests[questID] <-! qRef  // return quest back to contract pool
            emit QuestAssigned(id: questID, player: playerAcct.address)
        }

    //access(all) fun generateEnemies(level: UInt8, rarity: String): {String: UInt64} {
    //    let numEnemyTypes = self.RARITY_ENEMY_COUNT[rarity] ?? panic("Unknown rarity")
    //    let rarityFactor = self.RARITY_MULTIPLIER[rarity] ?? panic("Unknown rarity multiplier")
    //    let totalWeight: UFix64 = UFix64(level) * UFix64(rarityFactor) * 100.0
//
    //    
    //    let enemiesForQuest = [
    //        self.ENEMIES[numEnemyTypes[0]],
    //        self.ENEMIES[numEnemyTypes[1]]
    //    ]
//
    //    var remainingWeight: UFix64 = totalWeight
    //    var finalEnemies: {String: UInt64} = {}
//
    //    //initially number on enemies calculated will be in UFix64 we will somehow have to convert them to UInt64
    //    let enemy_1 = enemiesForQuest[0]
    //    let weight_enemy1 = self.ENEMY_WEIGHTS[enemy_1]!
    //    var maxCount: UFix64 = 1.0
//
    //    maxCount = remainingWeight / UFix64(weight_enemy1)
//
    //    let range1: [UInt64] = []
    //    var i: UFix64 = 0.0
    //    while i <= UFix64(maxCount) {
    //        range1.append(UInt64(i))
    //        i = i + 1.0
    //    }
    //    let count1 = UFix64(QuestManager.pickRandomValue(values: range1))
//
//
    //    //let count1 = UInt64(QuestManager.pickRandomValue(values: Array(0...Int(maxCount))))
//
    //    remainingWeight = remainingWeight - (UFix64(weight_enemy1) * UFix64(count1))
    //    
    //    
    //    let enemy_2 = enemiesForQuest[1]
    //    let weight_enemy2 = self.ENEMY_WEIGHTS[enemy_2]!
    //    maxCount = remainingWeight / UFix64(weight_enemy2)
//
    //    let range2: [UInt64] = []
    //    i = 0.0
    //    while i <= UFix64(maxCount) {
    //        range2.append(UInt64(i))
    //        i = i + 1.0
    //    }
    //    let count2 = QuestManager.pickRandomValue(values: range2)
//
    //    //let count2 = UInt64(QuestManager.pickRandomValue(values: Array(0...Int(maxCount))))
    //    finalEnemies[enemy_1] = UInt64(count1)
    //    finalEnemies[enemy_2] = UInt64(count2)
    //    //remainingWeight = remainingWeight - (weight * count)
//
    //    return finalEnemies
    //}


    //access(all) fun pickRandomValue(values: [UInt64]): {
    //    pre { values.length > 0: "Values array cannot be empty" }
    //    let receipt <- RandomPicker.commit(values: values)
//
    //    let result: UInt64 = RandomPicker.reveal(receipt: <-receipt)
    //    return result
    //}
//
    //access(all) fun returnRandomValue(){
    //    
    //}

    //access(all) fun pickRandomString(values: [String]): String {
    //    pre { values.length > 0: "Values array cannot be empty" }
    //    let receipt <- RandomPicker.commit(values: values)
    //    let result: String = RandomPicker.reveal(receipt: <-receipt)
    //    return result
    //}

   
    access(all) resource interface PublicQuestCollection {
        access(all) fun getIDs(): [UInt64]
        access(all) fun borrowQuest(id: UInt64): &Quest?
    }

    access(all) resource interface QuestCollectionManagerAccess {
      access(all) fun expireQuestForPlayer(player: Address, questID: UInt64)
    }
    
    access(contract) fun decrementActiveCount(level: UInt8, rarity: String) {

        var tempDict: {UInt8: {String: UInt64}} = self.activeCountsByLevelAndRarity

        if self.activeCountsByLevelAndRarity[level] == nil {
            panic("Unknown level: ".concat(level.toString()))
        }

        let cur = self.activeCountsByLevelAndRarity[level]![rarity] ?? panic(
            "Unknown rarity ".concat(rarity).concat(" for level ").concat(level.toString())
        )

        if cur > 0 {
            let new: UInt64 = cur - 1
            // Create a mutable reference to the inner dictionary
            let innerDict: {String: UInt64} = self.activeCountsByLevelAndRarity[level]!
            innerDict[rarity] = new
            self.activeCountsByLevelAndRarity[level] = innerDict
        } else {
            // Create a mutable reference to the inner dictionary
            let innerDict: {String: UInt64} = self.activeCountsByLevelAndRarity[level]!
            innerDict[rarity] = 0
            log("Tried to decrement below zero for level ".concat(level.toString()).concat(" rarity ").concat(rarity))
            self.activeCountsByLevelAndRarity[level] = innerDict
        }

    }


    //access(all) fun createEmptyQuestCollection(): @QuestCollection {
    //    return <- create QuestCollection()
    //}

    //self arc deposit function
    access(all) fun depositArc(from: @Arcane.Vault) {
        let vault <- QuestManager.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
            ?? panic("Could not load the contract's Arcane vault")
        
        vault.deposit(from: <-from)
        
        self.account.storage.save(<-vault, to: Arcane.VaultStoragePath)
    }

    // withdraw ARC by contract owner (for admin)
    access(all) fun withdrawARCAdmin(amount: UFix64, to: Address) {
        let vaultRef <- QuestManager.account.storage.load<@Arcane.Vault>(from: Arcane.VaultStoragePath)
                        ?? panic("Contract ARC vault not found")
        let payout <- vaultRef.withdraw(amount: amount)
        self.account.storage.save(<-vaultRef, to: Arcane.VaultStoragePath)
        let recipient = getAccount(to)
        let receiverCap = recipient.capabilities.get<&{FungibleToken.Receiver}>(Arcane.ReceiverPublicPath)
        if receiverCap == nil { destroy payout; panic("Recipient has no ARC receiver") }
        else {
            let recv = receiverCap.borrow() ?? panic("Cannot borrow recipient receiver")
            recv.deposit(from: <- payout)
            emit ARCWithdrawn(amount: amount, to: to)
        }
    }

    access(contract) fun createManager(): @Manager {
        return <- create Manager()
    }

    init() {
        self.STATUS_ACTIVE = "ACTIVE"
        self.STATUS_COMPLETED = "COMPLETED"
        self.STATUS_FAILED = "FAILED"
        //self.STATUS_PENDING = "PENDING"

        self.ENEMIES = ["Slime", "FireWorm", "Wizard", "BringerOfDeath", "Gorgon"]

        self.ENEMY_WEIGHTS = {
            "Slime": 10,
            "FireWorm": 20,
            "Wizard": 30,
            "BringerOfDeath": 40,
            "Gorgon": 50
        }

        self.RARITY_ENEMY_COUNT = {
            "C": [0, 1],
            "B": [1, 2],
            "A": [2, 3],
            "S": [3, 4]
        }
        self.QuestCollectionStoragePath = /storage/QuestCollection
        self.QuestCollectionPublicPath = /public/QuestCollection
//
        self.nextQuestID = 1
        self.activeCountsByLevelAndRarity = {}

        self.UNCLAIMED_TIMEOUT = 172800.0 //2 days    

        self.quests <- {}

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

        self.RARITY_MULTIPLIER = {
            "S": 10,
            "A": 6,
            "B": 3,
            "C": 1
        }

        self.BASE_REWARD_BY_RARITY = {
            "S": 100.0,
            "A": 40.0,
            "B": 20.0,
            "C": 10.0
        }

        self.ARCVaultStoragePath = /storage/arcVault

        //if self.activeCountsByLevelAndRarity[level] == nil {
        //    self.activeCountsByLevelAndRarity[level] = {}
        //    for rarity in self.RARITY_DISTRIBUTION.keys {
        //        self.activeCountsByLevelAndRarity[level]![rarity] = 0
        //    }
        //}

       
        
        let manager <- QuestManager.createManager()
        self.account.storage.save(<- manager, to: /storage/QuestManager)
    }
}

