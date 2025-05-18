# SupplyVerify

SupplyVerify is a decentralized supply chain verification platform built on Clarity smart contracts where product authenticity is verified on-chain and manufacturers earn tokens based on scans and quality ratings.

## Overview

This smart contract enables a supply chain verification platform with the following features:

- **Product Registration**: Manufacturers can register products with cryptographic hashing for integrity
- **On-chain Verification**: Supply chain entities verify product authenticity
- **Scan Tracking**: System tracks product scans throughout the supply chain
- **Quality Ratings**: Entities rate product quality on a scale of 1-5
- **Token Rewards**: Manufacturers earn tokens based on scans and quality ratings
- **Reputation System**: Entities build reputation through positive contributions

## Contract Functions

### Entity Management
- `register-entity`: Register as a new entity with a name
- `update-entity-name`: Update your entity name
- `get-entity-info`: Get information about an entity

### Product Management
- `register-product`: Register a new product with description and product hash
- `get-product`: Get information about a product
- `get-total-products`: Get the total number of products on the platform

### Verification System
- `verify-product`: Verify the authenticity of a product
- `get-product-verification`: Check if an entity has verified a product

### Scan System
- `scan-product`: Record a product scan with location data
- `get-product-scan`: Check an entity's scan record for a product

### Rating System
- `rate-product-quality`: Rate the quality of a product (1-5)
- `get-product-rating`: Get an entity's rating for a product

## Reward Mechanisms

The contract includes several token reward mechanisms:

1. **Verification Rewards**:
   - Entities who verify products receive 5 tokens and 1 reputation point
   - Manufacturers receive 50 tokens and 10 reputation points when their product is verified by 3+ entities

2. **Scan Rewards**:
   - Manufacturers receive 10 tokens for each product scan in the supply chain

3. **Quality Rewards**:
   - Entities who rate products receive 2 tokens and 1 reputation point
   - Manufacturers receive 20 tokens and 5 reputation points for highly rated products (4-5 stars)

## Development

This contract is designed to be deployed on the Stacks blockchain and can be tested using Clarinet.