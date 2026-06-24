# CryptoRaffle

A decentralized, provably-fair raffle smart contract built with Foundry, using Chainlink VRF v2.5 for tamper-proof random winner selection.

## Overview

CryptoRaffle lets players join a raffle by paying a fixed entrance fee in ETH. Once a set time interval has passed (and at least one player has joined), the contract requests a verifiably random number from Chainlink VRF to pick a winner. The entire prize pool — all accumulated entrance fees — is then transferred to the winner automatically.

Because winner selection relies on Chainlink VRF rather than on-chain pseudo-randomness (like `block.timestamp` or `blockhash`), the result can't be predicted or manipulated by miners, validators, or the contract owner.

## How It Works

1. **Join** — Players call `joinRaffle()` with at least `i_enteranceFee` in ETH. Joining is only allowed while the raffle is `OPEN`.
2. **Check eligibility** — `checkUpkeep()` returns `true` once there's at least one player, the contract holds a balance, and the configured time interval has elapsed since the last round.
3. **Request randomness** — `peformUpkeep()` (intended to be triggered by Chainlink Automation) verifies the upkeep conditions, flips the raffle into `PICKING_WINNER` state, and requests a random word from the Chainlink VRF Coordinator.
4. **Pick & pay the winner** — Once Chainlink's oracle responds, `fulfillRandomWords()` uses the random value to index into the player list, selects the winner, resets the raffle, and transfers the entire contract balance to the winner via a low-level `call`. If the transfer fails (e.g. the winner is a contract that rejects ETH), the transaction reverts with `Raffle__RewardFailed`.

## Built With

- [Solidity](https://soliditylang.org/) `^0.8.19`
- [Foundry](https://book.getfoundry.sh/) (Forge, Cast, Anvil)
- [Chainlink VRF v2.5](https://docs.chain.link/vrf/v2-5/overview) for verifiable randomness
- [Chainlink Automation](https://docs.chain.link/chainlink-automation) for triggering upkeep
- Sepolia Testnet

## Project Structure

```
src/
  Raffle.sol              # Main raffle contract
script/
  DeployRaffle.s.sol      # Deployment script — wires up subscription + consumer
  HelperConfig.s.sol      # Per-network config (Sepolia vs local Anvil + mocks)
  Interaction.s.sol       # CreateSubscription / FundSubscription / AddConsumer
test/
  mocks/                  # LinkToken mock for local testing
```

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- A Sepolia RPC URL (e.g. via Alchemy or Infura), if deploying to a testnet
- A funded Chainlink VRF subscription on Sepolia (or let the deploy script create one for you locally on Anvil)
- An Etherscan API key, for contract verification on deploy

### Installation

```bash
git clone https://github.com/Ralph-Chris/Crypto-Raffle.git
cd CryptoRaffle
forge install
make install
```

### Build

```bash
forge build
```

## Usage

### Test

```bash
forge test
```

### Run a Local Node

```bash
anvil
```

### Deploy Locally (Anvil)

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url http://127.0.0.1:8545 --account <your-anvil-account> --broadcast
```

On a local chain (`chainid 31337`), `HelperConfig.s.sol` automatically deploys a `VRFCoordinatorV2_5Mock` and a mock LINK token, so the full raffle lifecycle — including VRF subscription creation, funding, and consumer registration — can be tested end-to-end without touching a real network.

### Deploy to Sepolia

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $SEPOLIA_RPC_URL --account <your-keystore> --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

On Sepolia, `HelperConfig.s.sol` supplies the real Chainlink VRF Coordinator address, key hash, and LINK token address for the network.

> **Note:** Chainlink Automation's support for triggering upkeep on testnets is being phased out (June 2026). `peformUpkeep()` may need to be called manually for demonstration purposes rather than via live Automation on Sepolia.

## Key Parameters

| Parameter | Description |
|---|---|
| `i_enteranceFee` | Minimum ETH required to join the raffle |
| `i_interval` | Minimum time (seconds) that must pass before a winner can be picked |
| `i_keyHash` | Identifies which Chainlink VRF oracle/gas lane generates the random number |
| `i_subscriptionId` | The funded Chainlink VRF subscription that pays for randomness requests |
| `i_callbackGasLimit` | Gas limit allotted to `fulfillRandomWords()` when the oracle calls back |

## Testing Approach

The contract includes a `BadWinner` helper contract with no `receive()`/`fallback()`, used to test that a failed prize transfer (e.g. to a contract that rejects ETH) correctly reverts with `Raffle__RewardFailed` rather than silently losing funds or leaving the raffle in a broken state.

## License

MIT
