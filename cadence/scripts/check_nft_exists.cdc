// cadence 1.0
import NonFungibleToken from 0xf8d6e0586b0a20c7
import ItemManager from 0xf8d6e0586b0a20c7


access(all) fun main(account: Address, id: UInt64): [UInt64] {
    let acct = getAccount(account)

    // replace this with your collection's public path
    let cap = acct.capabilities.borrow<&ItemManager.Collection>(ItemManager.CollectionPublicPath)
        
    if cap == nil {
        return []
    }

    let ids: [UInt64] = cap!.getIDs()
    return ids
}
