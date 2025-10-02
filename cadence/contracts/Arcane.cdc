import FungibleToken from 0x9a0766d93b6608b7

import MetadataViews from 0x631e88ae7f1d7c20
import FungibleTokenMetadataViews from 0x9a0766d93b6608b7

access(all) contract Arcane: FungibleToken
{
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let ReceiverPublicPath: PublicPath

    access(all) var totalSupply: UFix64

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                        // Change this to your own SVG image
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    // Change these to represent your own token
                    name: "Example Foo Token",
                    symbol: "EFT",
                    description: "This fungible token is used as an example to help you develop your next FT #onFlow.",
                    externalURL: MetadataViews.ExternalURL("https://developers.flow.com/build/cadence/guides/fungible-token"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&Arcane.Vault>(),
                    metadataLinkedType: Type<&Arcane.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-Arcane.createEmptyVault(vaultType: Type<@Arcane.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: Arcane.totalSupply
                )
        }
        return nil
    }

    access(all) resource Vault: FungibleToken.Vault {

        access(all) var balance: UFix64


        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @Arcane.Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @Arcane.Vault
            self.balance = self.balance + vault.balance
            destroy vault
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[self.getType()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(all) fun createEmptyVault(): @Arcane.Vault {
            return <-create Vault(balance: 0.0)
        }

        access(all) view fun getViews(): [Type] {
            return Arcane.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return Arcane.resolveContractView(resourceType: nil, viewType: view)
        }

        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                Arcane.totalSupply = Arcane.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        init(balance: UFix64) {
            self.balance = balance
        }
    }

    access(all) event TokensMinted(amount: UFix64, type: String)
    access(all) resource Minter {
        /// mintTokens
        ///
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        access(all) fun mintTokens(amount: UFix64): @Arcane.Vault {
            Arcane.totalSupply = Arcane.totalSupply + amount
            let vault <-create Vault(balance: amount)
            emit TokensMinted(amount: amount, type: vault.getType().identifier)
            return <-vault
        }
    }

    access(all) fun createEmptyVault(vaultType: Type): @Arcane.Vault {
        return <- create Vault(balance: 0.0)
    }

    init() {
        self.totalSupply = 1000.0 // existed before
        self.VaultStoragePath = /storage/ArcaneVault
        self.VaultPublicPath = /public/ArcaneVault
        self.MinterStoragePath = /storage/ArcaneMinter
        self.ReceiverPublicPath = /public/ArcaneReceiver

        let vault <- create Vault(balance: self.totalSupply)
        emit TokensMinted(amount: vault.balance, type: vault.getType().identifier)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        let ArcaneCap = self.account.capabilities.storage.issue<&Arcane.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(ArcaneCap, at: self.VaultPublicPath)
        let RecieverCap = self.account.capabilities.storage.issue<&Arcane.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(RecieverCap, at: self.ReceiverPublicPath)

        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
}