# Safora

A blockchain-powered product provenance and authenticity verification platform that ensures goods — from luxury items to pharmaceuticals — can be trusted at every step of their journey. Built for transparency, trust, and safety.

---

## Overview

Safora consists of four main smart contracts that together form a decentralized, tamper-proof tracking ecosystem for manufacturers, distributors, retailers, and end consumers:

1. **Product Registry Contract** – Mints unique product tokens tied to physical items.
2. **Transfer & Custody Contract** – Logs every ownership change across the supply chain.
3. **Verification & Audit Contract** – Provides trustless product history checks for consumers.
4. **Dispute Resolution Contract** – Handles conflicts between stakeholders via DAO governance.

---

## Features

- **Unique digital identity** for every physical product (NFT-based)  
- **Immutable product history** recorded on-chain from creation to retail sale  
- **Tamper-proof transfer records** between supply chain participants  
- **Public verification portal** for scanning and checking product authenticity  
- **On-chain dispute resolution** for counterfeit or delivery issues  
- **Integration-ready** for QR codes, NFC tags, and IoT sensors  

---

## Smart Contracts

### Product Registry Contract
- Mint product NFTs (ERC-721 equivalent in Clarity)
- Store manufacturing metadata (batch ID, serial number, date, location)
- Link to off-chain data stored on IPFS/Arweave
- Only authorized manufacturers can mint

### Transfer & Custody Contract
- Transfer product custody between authorized supply chain actors
- Confirm receipt of goods via dual signatures
- Optionally integrate IoT data for automatic transfer logging

### Verification & Audit Contract
- Retrieve complete on-chain product history
- Verify authenticity against original minting records
- Public functions for consumer-facing verification apps

### Dispute Resolution Contract
- Initiate disputes over counterfeit or damaged goods
- DAO voting for resolution outcomes
- Escrow and fund release logic based on decision

---

## Installation

1. Install [Clarinet CLI](https://docs.hiro.so/clarinet/getting-started)  
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/safora.git
   ```
3. Run tests:
    ```bash
    npm test
    ```
4. Deploy contracts:
    ```bash
    clarinet deploy
    ```

---

## Usage

Manufacturers register new products on-chain and attach secure identifiers (QR, NFC).

Distributors & Retailers update custody records when receiving and sending goods.

Consumers scan the product’s identifier to instantly verify its origin and history.

Dispute resolution occurs transparently on-chain when issues arise.

---

## License

MIT License