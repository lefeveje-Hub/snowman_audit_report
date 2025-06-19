---
title: Snowman Merkle Airdrop Audit Report
author: Joe LeFever (Sicher Height)
date: June 19, 2025
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \vspace*{2cm}
    {\Large\bfseries Joe LeFever - Sicher Height\par}
    \vspace{2cm}
    {\Huge\bfseries Snowman Merkle Airdrop Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Independent Security Audit\par}
    \vfill
    {\large June 19, 2025\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Joe LeFever - Sicher Height](mailto:your-email@example.com)
Lead Auditor: 
- Joe LeFever

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
- [Medium](#medium)
- [Low](#low)

# Protocol Summary

The Snowman Merkle Airdrop protocol is a token distribution system that combines ERC20 tokens (Snow), ERC721 NFTs (Snowman), and Merkle tree-based airdrops. Users can earn or purchase Snow tokens, which can then be staked in the SnowmanAirdrop contract to receive proportional Snowman NFTs. The protocol features a 12-week farming period where users can earn free Snow tokens weekly or purchase them with ETH/WETH. The airdrop system utilizes Merkle proofs for efficient distribution and supports signature-based claiming on behalf of others.

**Key Components:**
- **Snow.sol**: ERC20 token with buy/earn mechanics and fee collection
- **Snowman.sol**: ERC721 NFT with on-chain Base64 encoding
- **SnowmanAirdrop.sol**: Merkle tree-based airdrop system with signature verification

# Disclaimer

The Joe LeFever - Sicher Height team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

**Date:** June 19, 2025  
**Auditor:** Joe LeFever (Sicher Height)  
**Classification:** Competitive Audit  
**Duration:** 2 days  

## Scope 

The following contracts were in scope for this audit:

```
src/
├── Snow.sol
├── Snowman.sol
└── SnowmanAirdrop.sol
```

**Lines of Code:** ~300 total
**Solidity Version:** ^0.8.24

## Roles

- **Owner**: Deployer of Snow contract with administrative privileges
- **Collector**: Address authorized to collect fees from Snow token purchases
- **Users**: Can buy/earn Snow tokens and claim Snowman NFTs
- **Recipients**: Addresses eligible for airdrops via Merkle proofs

# Executive Summary

This audit identified **6 High severity**, **6 Medium severity**, and **3 Low severity** vulnerabilities across the three contracts in the Snowman Merkle Airdrop protocol. The most critical issues involve missing access controls that allow unlimited NFT minting, fund theft through arbitrary token transfers, and broken signature verification due to a typo in the EIP-712 hash.

The protocol's core functionality is severely compromised by these vulnerabilities, particularly the unrestricted minting capability that completely breaks the tokenomics model. Immediate remediation of High severity findings is strongly recommended before any mainnet deployment.

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 6                      |
| Medium   | 6                      |
| Low      | 3                      |
| **Total** | **15**                |

# Findings

# High

### [H-1] Global timer for Snow.earnSnow() prevents multiple users from earning Snow tokens (Access Control + DoS)

**Description:** 
The `earnSnow()` function uses a single global timer `s_earnTimer` that affects all users. When any user calls `earnSnow()`, it prevents all other users from calling the function for one week. This breaks the intended functionality where each user should be able to earn one Snow token per week independently.

**Impact:** 
Only one user per week can earn free Snow tokens across the entire protocol, preventing all other users from accessing this core feature and enabling griefing attacks.

**Proof of Concept:**
```solidity
// Day 0: Alice calls earnSnow()
function earnSnow() external canFarmSnow {
    // s_earnTimer = 0, so check passes
    _mint(msg.sender, 1); // Alice gets 1 token
    s_earnTimer = block.timestamp; // Global timer set
}

// Day 1: Bob calls earnSnow() 
function earnSnow() external canFarmSnow {
    if (s_earnTimer != 0 && block.timestamp < (s_earnTimer + 1 weeks)) {
        revert S__Timer(); // ❌ Bob's call reverts
    }
    // Bob gets nothing, has to wait because of Alice's timer
}
```

**Recommended Mitigation:** 
Replace the global timer with a per-user mapping:
```solidity
mapping(address => uint256) private s_userEarnTimers;

function earnSnow() external canFarmSnow {
    if (s_userEarnTimers[msg.sender] != 0 && 
        block.timestamp < (s_userEarnTimers[msg.sender] + 1 weeks)) {
        revert S__Timer();
    }
    _mint(msg.sender, 1);
    s_userEarnTimers[msg.sender] = block.timestamp;
    
    emit SnowEarned(msg.sender, 1);
}
```

### [H-2] Users can lose ETH when attempting to buy Snow.buySnow() with incorrect payment amounts (Logic Error + Fund Loss)

**Description:** 
The `buySnow()` function has flawed payment logic that can cause users to lose their ETH. If a user sends ETH but not the exact required amount, the function keeps their ETH and then attempts to charge