import RandomConsumer from 0xed24dbe901028c5c  // Emulator service account address

access(all) contract RandomPicker {

    access(self) let consumer: @RandomConsumer.Consumer
    access(all) let ReceiptStoragePath: StoragePath

    access(all) event Committed(values: [UInt64], commitBlock: UInt64, receiptID: UInt64)
    access(all) event Revealed(winningResult: UInt64, values: [UInt64], commitBlock: UInt64, receiptID: UInt64)

    // The Receipt resource correctly conforms to the RequestWrapper interface.
    // This interface provides the getRequestBlock() and popRequest() functions.
    access(all) resource Receipt: RandomConsumer.RequestWrapper {
        access(all) let values: [UInt64]
        access(all) var request: @RandomConsumer.Request?

        init(values: [UInt64], request: @RandomConsumer.Request) {
            self.values = values
            self.request <- request
        }
    }

    // --- Vault Interface and Resource ---
    // This is the correct pattern for storing multiple pending requests.
    access(all) resource interface Vault {
        access(all) fun deposit(receipt: @Receipt)
        access(all) fun withdraw(receiptID: UInt64): @Receipt
        access(all) fun getIDs(): [UInt64]
    }

    access(all) resource VaultImpl: Vault {
        access(self) var receipts: @{UInt64: Receipt}

        init() {
            self.receipts <- {}
        }

        access(all) fun deposit(receipt: @Receipt) {
            let id = receipt.uuid
            let oldReceipt <- self.receipts[id] <- receipt
            destroy oldReceipt
        }

        access(all) fun withdraw(receiptID: UInt64): @Receipt {
            let receipt <- self.receipts.remove(key: receiptID)
            if receipt == nil {
                panic("Receipt with the specified ID not found in the Vault.")
            }
            return <- receipt!
        }

        access(all) fun getIDs(): [UInt64] {
            return self.receipts.keys
        }

    }

    access(all) fun createVault(): @VaultImpl {
        return <- create VaultImpl()
    }

    // --- Contract Functions ---

    access(all) fun commit(values: [UInt64]): @Receipt {
        pre {
            values.length > 0: "Array of values cannot be empty"
        }

        let request: @RandomConsumer.Request <- self.consumer.requestRandomness()
        let receipt: @Receipt <- create Receipt(values: values, request: <- request)
        
        emit Committed(
            values: values, 
            // The getRequestBlock() function will now be resolved correctly.
            commitBlock: receipt.getRequestBlock()!, 
            receiptID: receipt.uuid
        )

        return <-receipt
    }

    access(all) fun reveal(receipt: @Receipt): UInt64 {
        pre {
            receipt.getRequestBlock()! < getCurrentBlock().height: "Must wait at least 1 block to reveal"
            receipt.request != nil: "Already revealed"
        }

        let values = receipt.values
        let commitBlock = receipt.getRequestBlock()!
        let receiptID = receipt.uuid
        let request <- receipt.popRequest()

        let index = self.consumer.fulfillRandomInRange(request: <-request, min: 0, max: UInt64(values.length - 1))
        let winningResult = values[index]

        emit Revealed(
            winningResult: winningResult, 
            values: values, 
            commitBlock: commitBlock, 
            receiptID: receiptID
        )

        destroy receipt
        return winningResult
    }

    init() {
        self.consumer <- RandomConsumer.createConsumer()
        self.ReceiptStoragePath = /storage/FlowRandomPickerVault
    }
}