# ChillGuy DeFi Platform

> A decentralized fundraising and reward platform built on the Stacks blockchain.

## Overview

ChillGuy DeFi Platform is a blockchain-based solution developed for the Code4Stacks challenge that enables community-driven fundraising campaigns and fitness-based token rewards. The platform introduces ChillGuy Token (CfT), a fungible token that incentivizes donations and fitness activities, creating a positive feedback loop for community engagement.

## Features

- **ChillGuy Token (CfT)**: A fungible token with a capped supply of 1 billion tokens (with 6 decimals)
- **Campaign Creation**: Create customizable fundraising campaigns with specific goals
- **Token-Based Donations**: Support campaigns with token donations
- **Goal-Based Withdrawals**: Campaign creators can withdraw funds once goals are met
- **Fitness Rewards**: Earn tokens by participating in fitness challenges
- **Donation Rewards**: Get token rewards for supporting campaigns
- **Role-Based Access**: Secure system with authorized minters and owner-only functions

## Smart Contracts

### ChillGuy Token (`chill-guy.clar`)

A fungible token contract that manages the ChillGuy Token (CfT) with features for:

```clarity
;; Mint new tokens (only by approved minters)
(define-public (mint (amount uint) (recipient principal))...)

;; Distribute tokens for donations
(define-public (distribute-for-donation (amount uint) (donor principal))...)

;; Distribute tokens for fitness challenges
(define-public (distribute-for-fitness (amount uint) (user principal))...)
```

### Donation Management (`donation-management.clar`)

Manages fundraising campaigns with features for:

```clarity
;; Create a new fundraising campaign
(define-public (create-campaign (name (string-ascii 100)) (description (string-utf8 500)) (goal uint))...)

;; Donate tokens to a campaign
(define-public (donate-to-campaign (token <token-trait>) (campaign-id uint) (amount uint))...)

;; Withdraw funds from a campaign (only by campaign creator and if goal is met)
(define-public (withdraw-campaign-funds (token <token-trait>) (campaign-id uint))...)
```

## Project Structure

```
chillguy-defi/
├── contracts/
│   ├── chill-guy.clar            # ChillGuy Token contract
│   └── donation-management.clar  # Campaign management contract
├── settings/
│   ├── Devnet.toml               # Devnet configuration
│   ├── Mainnet.toml              # Mainnet configuration
│   └── Testnet.toml              # Testnet configuration
├── tests/
│   └── chill-guy.test.ts         # Tests for the token contract
├── .gitattributes                # Git repository files
├── clarinet.toml                 # Clarinet project configuration
├── package.json                  # Node.js package configuration
├── tsconfig.json                 # TypeScript configuration
├── vitest.config.js              # Vitest configuration
└── README.md                     # This readme file
```

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Development toolchain for Clarity smart contracts
- [Node.js](https://nodejs.org/) - For running tests and development tools

### Installation

1. Clone this repository:

```bash
git clone https://github.com/yourusername/chillguy-defi.git
cd chillguy-defi
```

2. Install dependencies:

```bash
npm install
```

3. Run tests:

```bash
npm test
```

### Development Environment

The project uses Clarinet's simulated blockchain environment for development and testing:

```bash
# Start a local development console
clarinet console

# Deploy contracts to devnet
clarinet deploy --devnet
```

## Usage Examples

### Creating a Campaign

```clarity
(contract-call? .donation-management create-campaign
  "Clean Ocean Initiative"
  "Fundraising for ocean cleanup efforts"
  u10000000)
```

### Donating to a Campaign

```clarity
(contract-call? .donation-management donate-to-campaign
  .chill-guy-token
  u1  ;; campaign ID
  u5000000)  ;; donation amount
```

### Earning Tokens for Fitness Activities

```clarity
(contract-call? .chill-guy distribute-for-fitness
  u100000  ;; token amount
  tx-sender)  ;; recipient
```

## Deployment

### Testnet Deployment

1. Update your mnemonic in `settings/Testnet.toml`
2. Deploy using Clarinet:

```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Update your mnemonic in `settings/Mainnet.toml`
2. Deploy using Clarinet:

```bash
clarinet deploy --mainnet
```

## Testing

Run the test suite using Vitest:

```bash
npm test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[MIT License](LICENSE)

## About the Code4Stacks Challenge

This project was developed as part of the Code4Stacks challenge, a hackathon focused on building innovative applications on the Stacks blockchain using Clarity smart contracts.
