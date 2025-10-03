import MarketPlace2 from 0x3d895199cfc42ff5

access(all) fun main(): {UInt64: {String: AnyStruct}} {
    let out: {UInt64: {String: AnyStruct}} = {}
    for id in MarketPlace2.itemsForSale.keys {
        let l = MarketPlace2.itemsForSale[id]!
        out[id] = {
            "tokenID": l.tokenID,
            "seller": l.seller,
            "price": l.price
        }
    }
    return out
}
