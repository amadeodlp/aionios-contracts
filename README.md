# AIONIOS Smart Contracts

Solidity smart contracts for the AIONIOS blockchain time capsule project.

## Overview

This directory contains the smart contracts that power the AIONIOS decentralized time capsule platform. These contracts handle the core functionality of creating time capsules, storing digital assets, and managing conditional release mechanisms.

## Features

- Core time capsule creation and management
- Time-based and condition-based unlocking mechanisms
- Oracle integration for external condition verification
- Digital asset storage (ETH, ERC-20, NFTs)
- Access control through digital keys (NFTs)

## Tech Stack

- **Solidity** - Smart contract language
- **Hardhat** - Development environment
- **Chainlink** - Oracle services
- **OpenZeppelin** - Contract standards and security

## Contract Architecture

### Core Contracts

1. **AioniosCapsule.sol**
   - Main contract for capsule functionality
   - Handles creation, locking, and opening of capsules
   - Manages content and asset storage

2. **AioniosOracle.sol**
   - Integrates with external data sources
   - Verifies off-chain conditions
   - Uses Chainlink for reliable data feeds

3. **AioniosAccess.sol**
   - Manages capsule access control
   - Implements NFT-based digital keys
   - Handles access delegation and inheritance

### Supporting Contracts

- **AioniosStorage.sol** - Data structures and storage patterns
- **AioniosEvents.sol** - Event definitions
- **AioniosUtils.sol** - Utility functions

## Development

### Prerequisites

- Node.js (v14 or later)
- npm or yarn
- Hardhat

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd AIONIOS/smart-contracts
```

2. Install dependencies
```bash
npm install
# or
yarn install
```

3. Compile contracts
```bash
npx hardhat compile
```

4. Run tests
```bash
npx hardhat test
```

### Deployment

1. Configure network in `hardhat.config.js`

2. Create `.env` file with required variables
```
PRIVATE_KEY=your_private_key
INFURA_API_KEY=your_infura_key
ETHERSCAN_API_KEY=your_etherscan_key
```

3. Deploy to testnet
```bash
npx hardhat run scripts/deploy.js --network rinkeby
```

4. Verify contracts
```bash
npx hardhat verify --network rinkeby DEPLOYED_CONTRACT_ADDRESS
```

## Contract Functionality

### Time Capsule Creation
```solidity
function createCapsule(
    bytes32 contentHash,
    uint256 unlockTime,
    address[] memory recipients,
    uint256[] memory amounts,
    address[] memory tokens
) external payable returns (uint256 capsuleId);
```

### Condition Management
```solidity
function addCondition(
    uint256 capsuleId,
    enum ConditionType conditionType,
    bytes memory conditionData
) external onlyCapsuleOwner(capsuleId);
```

### Capsule Opening
```solidity
function openCapsule(uint256 capsuleId) external returns (bool success);
```

### Digital Asset Management
```solidity
function depositAsset(
    uint256 capsuleId,
    address token,
    uint256 amount
) external payable onlyCapsuleOwner(capsuleId);
```

## Security Considerations

- All contracts use OpenZeppelin's secure implementations where possible
- Access control is enforced for sensitive operations
- Re-entrancy guards are implemented for all functions that transfer assets
- Integer overflow protection through SafeMath
- All external calls follow checks-effects-interactions pattern

## Contributing

Please read the [CONTRIBUTING.md](../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
