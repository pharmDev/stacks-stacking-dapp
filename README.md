# Stacks Staking DApp

A decentralized staking application built on the Stacks blockchain that allows users to stake STX tokens and earn rewards.

## Overview

This project implements a staking contract on the Stacks blockchain that enables users to:
- Stake STX tokens for a specified duration
- Earn rewards based on stake amount and duration
- Claim rewards after each reward cycle
- Unstake tokens after the lock period ends

## Contract Features

- **Flexible Staking Periods**: Users can choose staking durations from 1 to 12 cycles
- **Reward Bonuses**: Longer staking periods (6+ cycles) receive bonus rewards
- **Cycle-Based Rewards**: Rewards are calculated and distributed based on reward cycles
- **Emergency Controls**: Contract owner can pause staking and perform emergency withdrawals
- **Pool Limits**: Maximum pool size and minimum staking amount enforced

## Technical Details

### Constants
- Minimum staking amount: 100 STX
- Maximum pool size: 1,000,000 STX
- Reward cycle length: ~1 day (144 blocks)
- Cooldown period: ~12 hours (72 blocks)

### Public Functions

- `stake(amount, duration)`: Stake STX tokens for a specified duration
- `unstake()`: Withdraw staked tokens after lock period
- `claim-rewards()`: Claim accumulated rewards
- `toggle-staking()`: Enable/disable staking (owner only)
- `update-pool-rewards(amount)`: Update rewards per cycle (owner only)
- `emergency-withdraw(staker)`: Force withdraw funds (owner only)

### Read-Only Functions

- `get-staker-info(staker)`: Get staker details
- `get-total-staked()`: Get total STX staked in the contract
- `get-staking-status()`: Check if staking is enabled
- `get-pending-rewards(staker)`: Calculate pending rewards
- `get-unlock-time(staker)`: Get remaining lock time
- `can-unstake(staker)`: Check if staker can unstake

## Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://github.com/blockstack/stacks.js)

### Setup
1. Clone the repository
2. Install dependencies
3. Run tests with `clarinet test`

### Testing
```bash
# Check contract syntax
clarinet check

# Run all tests
clarinet test
```

## Deployment

The contract can be deployed to the Stacks testnet or mainnet using Clarinet:

```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

## License

MIT