# Liquidity Pool Smart Contract

## Overview

This Clarity smart contract implements a decentralized exchange (DEX) liquidity pool. It allows users to add and remove liquidity, swap tokens, and includes features like fee collection and slippage protection. The contract is designed to work with two fungible tokens, referred to as token-a and token-b.

## Features

- Add and remove liquidity
- Token swapping with constant product formula (x * y = k)
- Automatic fee collection (0.3% by default)
- Slippage protection for liquidity operations and swaps
- Pool token minting and burning to represent liquidity shares
- Read-only functions for querying pool state and calculating expected outputs

## Contract Functions

### Read-Only Functions

1. `get-balance`: Get the balance of a specified token for a given address.
2. `get-total-liquidity`: Get the total liquidity in the pool.
3. `calculate-tokens-to-add`: Calculate the amount of tokens to add based on the current pool ratio.
4. `calculate-tokens-to-remove`: Calculate the amount of tokens to receive when removing liquidity.
5. `get-swap-amount`: Calculate the expected output amount for a token swap.

### Public Functions

1. `add-liquidity`: Add liquidity to the pool and receive pool tokens.
2. `remove-liquidity`: Remove liquidity from the pool by burning pool tokens.
3. `swap`: Swap one token for another.
4. `collect-fees`: Allow the contract owner to collect accumulated fees.

## Usage

### Adding Liquidity

To add liquidity to the pool, call the `add-liquidity` function with the following parameters:

- `amount-a`: The amount of token-a to add
- `amount-b`: The amount of token-b to add
- `min-pool-tokens`: The minimum number of pool tokens to receive (slippage protection)

Example:
```clarity
(contract-call? .liquidity-pool add-liquidity u1000000 u1000000 u990000)
```

### Removing Liquidity

To remove liquidity from the pool, call the `remove-liquidity` function with the following parameters:

- `amount-pool`: The amount of pool tokens to burn
- `min-a`: The minimum amount of token-a to receive (slippage protection)
- `min-b`: The minimum amount of token-b to receive (slippage protection)

Example:
```clarity
(contract-call? .liquidity-pool remove-liquidity u100000 u95000 u95000)
```

### Swapping Tokens

To swap tokens, call the `swap` function with the following parameters:

- `token-in`: The token to swap from ("a" or "b")
- `amount-in`: The amount of input token to swap
- `min-amount-out`: The minimum amount of output token to receive (slippage protection)

Example:
```clarity
(contract-call? .liquidity-pool swap "a" u100000 u95000)
```

## Deployment and Testing

1. Deploy the contract to a Stacks blockchain (testnet or mainnet).
2. Initialize the pool by adding initial liquidity.
3. Test all functions thoroughly, including edge cases and potential attack vectors.
4. Monitor the pool's performance and collect fees periodically.

## Security Considerations

- The contract uses `as-contract` for token transfers from the contract itself to prevent unauthorized withdrawals.
- Slippage protection is implemented to protect users from front-running and unexpected price movements.
- The square root function (`sqrti`) is an approximation and may have some precision loss for very large numbers.
- Consider implementing additional security measures like flash loan protection or multi-hop swap limits for production use.

## Limitations and Future Improvements

- The contract currently supports only two tokens. Multi-token pools could be implemented in the future.
- The fee percentage is fixed. An upgradable fee structure could be considered.
- Implement more advanced features like flash loans, multi-hop swaps, or liquidity mining rewards.
