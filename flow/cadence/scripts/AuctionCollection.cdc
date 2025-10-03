// cadence 1.0
import AuctionHouse from 0x0095f13a82f1a835

access(all) fun main(): {UInt64: {String: AnyStruct}} {
    let out: {UInt64: {String: AnyStruct}} = {}

    for id in AuctionHouse.itemsForSale.keys {
        let l = AuctionHouse.itemsForSale[id]!

        out[id] = {
            "tokenID": l.tokenID,
            "seller": l.seller,
            "basePrice": l.basePrice,
            "currentBid": l.currentBid,
            "highestBidder": l.highestBidder, // Address? or nil
            "endTime": l.endTime
        }
    }

    return out
}
