# Civicraft

# 🏛️ Civicraft - Civic Reputation NFT System

## 🌟 Overview

Civicraft is a blockchain-based platform that tracks and rewards positive social and political contributions through NFTs. Each civic action becomes a permanent, verifiable record of community engagement, building a decentralized reputation system for active citizens.

## ✨ Features

- 🎖️ **NFT Reputation Tokens**: Each contribution mints a unique NFT representing civic engagement
- 🏆 **Reputation Levels**: Progress from "Newcomer" to "Civic Champion" based on contributions
- ✅ **Verification System**: Trusted verifiers can authenticate high-impact contributions
- 📊 **Impact Scoring**: Different contribution types have varying impact scores
- 🔄 **Transferable Records**: NFTs can be transferred while maintaining contribution history

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd civicraft
clarinet check
```

## 🎯 Usage

### 1. Initialize the Contract
```clarity
(contract-call? .Civicraft initialize-contract)
```

### 2. Submit a Contribution
```clarity
(contract-call? .Civicraft submit-contribution "community-service" u"Organized neighborhood cleanup event")
```

### 3. Verify Contributions (Verifiers Only)
```clarity
(contract-call? .Civicraft verify-contribution u1)
```

### 4. Check Your Reputation
```clarity
(contract-call? .Civicraft get-user-reputation tx-sender)
```

## 🏅 Contribution Types

| Type | Base Score | Verification Required |
|------|------------|----------------------|
| 🌱 Environmental Action | 15 | ✅ |
| 🗳️ Civic Participation | 20 | ❌ |
| 🤝 Community Service | 10 | ✅ |
| 💪 Volunteer Work | 12 | ✅ |
| 📢 Public Advocacy | 18 | ❌ |
| 📚 Education Outreach | 14 | ✅ |

## 🎖️ Reputation Levels

- 🌱 **Newcomer**: Starting level (0-9 points)
- 🌟 **Contributor**: Basic engagement (10+ points)
- 🏃 **Active Citizen**: Regular participation (25+ points, 3+ verified)
- 👑 **Community Leader**: Significant impact (50+ points, 5+ verified)
- 🏆 **Civic Champion**: Maximum recognition (100+ points, 10+ verified)

## 🔧 Contract Functions

### Public Functions
- `submit-contribution`: Create new civic contribution NFT
- `verify-contribution`: Verify contributions (verifiers only)
- `transfer`: Transfer NFT ownership
- `add-verifier`: Add trusted verifiers (owner only)

### Read-Only Functions
- `get-user-reputation`: View user's reputation stats
- `get-contribution-details`: Get specific contribution info
- `get-total-contributions`: Total platform contributions
- `is-verifier`: Check if user is a verifier

## 🛠️ Development

### Testing
```bash
clarinet test
```

### Deploy
```bash
clarinet deploy --testnet
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🌐 Community

Join our mission to build a more engaged civic society through blockchain technology!


