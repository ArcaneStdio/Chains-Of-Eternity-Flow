import "FungibleToken"
import "FlowToken"
import "ArcaneToken" 

access(all) contract ArcaneSwapPool: FungibleToken {

    // --- LP Token State ---
    access(all) var totalSupply: UFix64
    access(all) let StoragePath: StoragePath
    access(all) let ReceiverPath: PublicPath
    access(all) let BalancePath: PublicPath

    // --- Pool State ---
    access(all) let PoolStoragePath: StoragePath
    access(all) let PoolPublicPath: PublicPath
    access(all) let Fee: UFix64

    // --- Events ---
    access(all) event LiquidityAdded(flowAmount: UFix64, arcaneAmount: UFix64, lpTokensMinted: UFix64)
    access(all) event LiquidityRemoved(flowAmount: UFix64, arcaneAmount: UFix64, lpTokensBurned: UFix64)
    access(all) event Swap(tokenIn: Type, amountIn: UFix64, tokenOut: Type, amountOut: UFix64)

    // --- LP Token Vault Resource ---
    // This is the vault for the LP tokens this contract issues.
    access(all) resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {
        access(all) var balance: UFix64
        init(balance: UFix64) { self.balance = balance }
        access(all) fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            return <- create Vault(balance: amount)
        }
        access(all) fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @ArcaneSwapPool.Vault
            self.balance = self.balance + vault.balance
            destroy vault
        }
    }

    // --- AMM Pool Resource ---
    // This is the core resource that holds the liquidity and performs the AMM logic.
    access(all) resource Pool {
        access(self) let flowVault: @FlowToken.Vault
        access(self) let arcaneVault: @ArcaneToken.Vault
        access(self) let lpTokenMinter: @FungibleToken.Minter

        // Returns the current reserves of the pool
        access(all) view fun getReserves(): {Type: UFix64} {
            return {
                Type<@FlowToken.Vault>(): self.flowVault.balance,
                Type<@ArcaneToken.Vault>(): self.arcaneVault.balance
            }
        }

        // Calculates the amount of tokenOut you will receive for a given amount of tokenIn
        access(all) view fun quoteSwap(amount: UFix64, inType: Type): UFix64 {
            let reserves = self.getReserves()
            let reserveIn = reserves[inType]!
            let outType = (inType == Type<@FlowToken.Vault>()) ? Type<@ArcaneToken.Vault>() : Type<@FlowToken.Vault>()
            let reserveOut = reserves[outType]!
            
            let amountWithFee = amount * (1.0 - ArcaneSwapPool.Fee)
            // Formula: amountOut = (reserveOut * amountWithFee) / (reserveIn + amountWithFee)
            return (reserveOut * amountWithFee) / (reserveIn + amountWithFee)
        }

        // Adds liquidity to the pool and returns LP tokens to the provider
        access(all) fun addLiquidity(fromFlow: @FlowToken.Vault, fromArcane: @ArcaneToken.Vault): @Vault {
            let flowAmount = fromFlow.balance
            let arcaneAmount = fromArcane.balance
            
            let lpTotalSupply = ArcaneSwapPool.totalSupply
            var lpToMint: UFix64

            if (lpTotalSupply == 0.0) {
                lpToMint = 100.0
            } else {
                let reserves = self.getReserves()
                let flowReserve = reserves[Type<@FlowToken.Vault>()]!
                let arcaneReserve = reserves[Type<@ArcaneToken.Vault>()]!

                // Ensure subsequent deposits maintain the price ratio
                assert(arcaneAmount / flowAmount == arcaneReserve / flowReserve, message: "Deposit ratio does not match pool ratio")

                // Mint LP tokens proportional to the new liquidity share
                lpToMint = (lpTotalSupply * flowAmount) / flowReserve
            }

            self.flowVault.deposit(from: <- fromFlow)
            self.arcaneVault.deposit(from: <- fromArcane)

            let newLPTokens <- self.lpTokenMinter.mintTokens(amount: lpToMint) as! @Vault
            emit LiquidityAdded(flowAmount: flowAmount, arcaneAmount: arcaneAmount, lpTokensMinted: lpToMint)
            return <- newLPTokens
        }

        // Removes liquidity from the pool
        access(all) fun removeLiquidity(lpTokens: @Vault): (@FlowToken.Vault, @ArcaneToken.Vault) {
            let lpAmount = lpTokens.balance
            let lpTotalSupply = ArcaneSwapPool.totalSupply
            
            let reserves = self.getReserves()
            let flowReserve = reserves[Type<@FlowToken.Vault>()]!
            let arcaneReserve = reserves[Type<@ArcaneToken.Vault>()]!

            // Calculate share of pool
            let flowToWithdraw = (flowReserve * lpAmount) / lpTotalSupply
            let arcaneToWithdraw = (arcaneReserve * lpAmount) / lpTotalSupply

            // Burn the LP tokens
            self.lpTokenMinter.burnTokens(from: <- lpTokens)
            
            emit LiquidityRemoved(flowAmount: flowToWithdraw, arcaneAmount: arcaneToWithdraw, lpTokensBurned: lpAmount)
            return (<-self.flowVault.withdraw(amount: flowToWithdraw) as! @FlowToken.Vault, <-self.arcaneVault.withdraw(amount: arcaneToWithdraw) as! @ArcaneToken.Vault)
        }
        
        // Swaps FLOW for Arcane
        access(all) fun swapFlowForArcane(from: @FlowToken.Vault): @ArcaneToken.Vault {
            let amountIn = from.balance
            let amountOut = self.quoteSwap(amount: amountIn, inType: Type<@FlowToken.Vault>())

            self.flowVault.deposit(from: <- from)
            let swappedTokens <- self.arcaneVault.withdraw(amount: amountOut) as! @ArcaneToken.Vault
            
            emit Swap(tokenIn: Type<@FlowToken.Vault>(), amountIn: amountIn, tokenOut: Type<@ArcaneToken.Vault>(), amountOut: amountOut)
            return <- swappedTokens
        }

        // Swaps Arcane for FLOW
        access(all) fun swapArcaneForFlow(from: @ArcaneToken.Vault): @FlowToken.Vault {
            let amountIn = from.balance
            let amountOut = self.quoteSwap(amount: amountIn, inType: Type<@ArcaneToken.Vault>())

            self.arcaneVault.deposit(from: <- from)
            let swappedTokens <- self.flowVault.withdraw(amount: amountOut) as! @FlowToken.Vault

            emit Swap(tokenIn: Type<@ArcaneToken.Vault>(), amountIn: amountIn, tokenOut: Type<@FlowToken.Vault>(), amountOut: amountOut)
            return <- swappedTokens
        }

        init() {
            self.flowVault <- FlowToken.createEmptyVault()
            self.arcaneVault <- ArcaneToken.createEmptyVault() as! @ArcaneToken.Vault
            // The pool resource can't directly create the LP minter, so it will be passed in.
            self.lpTokenMinter <- ArcaneSwapPool.createMinter()
        }
    }

    // --- FungibleToken required functions for LP Tokens ---
    access(all) fun createEmptyVault(): @FungibleToken.Vault {
        return <- create Vault(balance: 0.0)
    }

    access(contract) fun createMinter(): @FungibleToken.Minter {
        return <- create Minter()
    }
    
    access(all) resource Minter: FungibleToken.Minter {
        access(all) fun mintTokens(amount: UFix64): @FungibleToken.Vault {
            ArcaneSwapPool.totalSupply = ArcaneSwapPool.totalSupply + amount
            return <- create Vault(balance: amount)
        }
        access(all) fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @Vault
            ArcaneSwapPool.totalSupply = ArcaneSwapPool.totalSupply - vault.balance
            destroy vault
        }
    }

    init() {
        self.totalSupply = 0.0
        self.StoragePath = /storage/arcaneSwapLpVault
        self.ReceiverPath = /public/arcaneSwapLpReceiver
        self.BalancePath = /public/arcaneSwapLpBalance
        self.PoolStoragePath = /storage/arcaneSwapPool
        self.PoolPublicPath = /public/arcaneSwapPool

        self.Fee = 0.003 // 0.3% trading fee

        // Create the Pool resource and save it to the contract's account
        self.account.storage.save(<- create Pool(), to: self.PoolStoragePath)
        
        // Publish a public capability to the Pool resource so others can interact with it
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&Pool>(self.PoolStoragePath),
            at: self.PoolPublicPath
        )
    }
}