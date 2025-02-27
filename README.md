# ChillGuy DeFi Platform

> A decentralized platform for fundraising campaigns and token rewards built on the Stacks blockchain.

## Overview

ChillGuy DeFi Platform is a blockchain-based solution that enables fundraising campaigns for charitable causes and community initiatives. The platform introduces ChillGuy Token (CfT), a fungible token that can be earned through donations and fitness challenges, creating a positive incentive loop for community involvement.

## Features

- **Fungible Token**: ChillGuy Token (CfT) with 6 decimals and a capped supply of 1 billion tokens
- **Campaign Creation**: Users can create fundraising campaigns with customizable goals
- **Token-Based Donations**: Support campaigns by donating tokens
- **Goal-Based Withdrawals**: Campaign creators can withdraw funds only when goals are met
- **Token Rewards**: Earn ChillGuy tokens by participating in donations and fitness challenges
- **Authorized Minting**: Secure token minting through an approved minters system

## Smart Contracts

The platform consists of two main Clarity smart contracts:

### ChillGuy Token Contract (`chill-guy.clar`)

A fungible token contract that manages the ChillGuy Token (CfT). It handles token minting, distribution, and transfers with features for:

- Token minting by approved minters
- Special distribution for donations and fitness challenges
- Administration of approved minters
- Token information and metadata management

### Donation Management Contract (`donation-management.clar`)

A contract that manages fundraising campaigns with features for:

- Campaign creation with customizable goals
- Token-based donations to campaigns
- Secure withdrawal of funds when campaign goals are met
- Administrative controls for campaign management
- Detailed reporting of campaign metrics and donation history

## Getting Started

### Prerequisites

- A Stacks wallet (like Hiro Wallet)
- Stacks testnet or mainnet tokens for transaction fees

### Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/chillguy-defi.git
   cd chillguy-defi
   ```

2. Deploy the contracts using Clarinet or the Stacks Explorer:
   - Deploy `chill-guy.clar` first to establish the token
   - Deploy `donation-management.clar` second for the campaign functionality

### Usage

#### Creating a Campaign

```clarity
(contract-call? .donation-management create-campaign "Clean Ocean Initiative" "Fundraising for ocean cleanup efforts" u10000000)
```

#### Donating to a Campaign

```clarity
(contract-call? .donation-management donate-to-campaign .chill-guy-token u1 u5000000)
```

#### Withdrawing Campaign Funds (for campaign creators)

```clarity
(contract-call? .donation-management withdraw-campaign-funds .chill-guy-token u1)
```

## Project Structure

```
chillguy-defi/
├── contracts/
│   ├── chill-guy.clar         # ChillGuy Token contract
│   └── donation-management.clar # Campaign management contract
├── tests/                     # Contract test files
├── README.md                  # This readme file
└── LICENSE                    # Project license
```

## Development

This project was built as part of the Code4Stacks challenge, utilizing the Clarity language for Stacks blockchain development.

### Testing

To run tests locally, you can use Clarinet:

```
clarinet test
```

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.