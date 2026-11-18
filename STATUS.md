# AgentMandate — Binance Wallet × BNB Chain Agent ID Hackathon — STATUS

Last updated: 2026-11-18 ~18:55 WIB (Phase 1 build + deploy complete)

## Contest snapshot
- Total 60,000 USDC. Two project awards × 29,000 USDC over top 10 (1st $10,000 / 2nd $6,000 / 3rd $4,000 / 4th $3,000 / 5th $2,000 / 6th–10th $800): Ecosystem Award (on-chain metrics) + Innovation Award (judged: Agent ID depth 30%, practicality 25%, completion 25%, innovation 20%).
- Innovation eligibility: product live + ≥30 Agent ID addresses interacted during the submission period.
- **Submission deadline: 2026-12-09 08:00 UTC (15:00 WIB).** Reviews to 20 Dec; rewards within 14 business days after public review, to the address given at submission.
- Rules: BNB Chain mainnet, verified + open-source contracts, active Agent ID use. Agent ID contract (SPACE ID): `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`.

## Design (as built)
Fresh BSC code — design lessons reused from the Aevum AgentPay Vault (cap/budget/expiry/allowlist accounting, effects-before-interaction, safe transfers), but Agent ID gating is new and load-bearing at three points:
- **AgentRegistry** (`src/AgentRegistry.sol`): `registerAgent()` reverts unless the caller holds an Agent ID (`balanceOf > 0` on the SPACE ID contract). One registration per address; self-deregistration supported. `isEligibleAgent(a) = registered && still holds Agent ID`. No owner, no admin functions.
- **AgentMandate** (`src/AgentMandate.sol`): `createMandate` reverts unless (1) the principal holds an Agent ID and (2) the appointed agent `isEligibleAgent`. `pay` re-checks the agent's live eligibility on **every** execution, then enforces per-tx cap → total budget → deposited funds → payee allowlist → expiry. Assets: native BNB or BSC USDT only (hardcoded allowlist, so accounting can't be spoofed). Principal can revoke anytime and reclaim unspent funds; anyone can close after expiry (refund to principal). **No owner/admin anywhere** — deployer has zero privileges; Agent ID + registry addresses are immutable.
- **Frontend** (`frontend/index.html`): single static page, standard injected-wallet connect (no QR/pairing login), eligibility pills, register/deregister, create-mandate form, mandate dashboard (fund / pay / allow payee / revoke), permissions & risk documentation section, no return promises anywhere.

## Tests — 32/32 PASS (forge test, solc 0.8.24)
- AgentRegistry suite: 9/9 (non-holder register reverts, double-register reverts, deregister/re-register, eligibility drop when Agent ID balance zeroed, counting).
- AgentMandate suite: 23/23 (non-holder principal reverts, unregistered/no-ID agent appointment reverts, unsupported asset reverts, invalid limits, BNB fund+pay happy path, over-cap / over-budget / over-funded reverts, expiry revert, non-agent pay revert, allowlist enforcement, pay blocked after agent deregisters or loses Agent ID, revoke refunds, closeExpired refunds, full USDT flow incl. over-cap revert — mock ERC-20 etched onto the real USDT address so the asset allowlist behaves exactly as mainnet).

## Deployment — DONE on BSC mainnet (2026-11-18)
Deployer: Agentic Wallet `0x94aAb8d86DacE5b395056E709d4f14b5460C6E03` (aditya93.ai) via `baw contract-call` (preview gate passed for every tx; zero risks flagged), CREATE2 factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`.

| Item | Address / tx | Gas used |
|---|---|---|
| AgentRegistry | `0x0e69ed84dd472B963Ac1BFdEA43092964e40609d` · tx `0x0179ece1fa19b98d9b0ec9398f142d7737b0a69bef18bba356cb89ef8f8c0f2b` | 349,674 |
| AgentMandate | `0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5` · tx `0xbb60960a29001477b0f7fc6cb567875c505b899120391a8bebe1c83c6433345f` | 1,469,781 |
| registerAgent (agent #1 = deployer wallet) | tx `0x633f80336014ae9eb94b635af0ea5bbcad6790c7762fa84490e6f546c5532e43` | 95,364 |

- Measured pre-deploy estimate: 1,953,007 gas total @ 0.05 gwei = **0.0000977 BNB** vs balance 0.000945169 BNB (**9.68× headroom**, above the ≥2× rule, far below the 0.0007 stop threshold). Actual total spent: **0.000132191 BNB** (balance after: 0.000812978 BNB).
- On-chain wiring verified: `registry.agentIdToken` = SPACE ID contract; `mandate.registry` = the registry; `agentCount` = 1; `isEligibleAgent(deployer)` = true. End-to-end flow proven on mainnet.

## Source verification
- **Sourcify: exact_match for BOTH contracts** (registry job `557229f6-adcf-4749-94bd-f5258c119646`; mandate job `3f2cdd8c-672e-42fd-bf4c-a1e9f86b03a4`).
- **BscScan direct verification: BLOCKED — no Etherscan/BscScan API key exists in this VM's environment** (forge's etherscan verifier requires `ETHERSCAN_API_KEY`). Sourcify verification is complete and BscScan surfaces Sourcify-matched sources; if a key is provided later, direct BscScan verification takes minutes with the constructor args recorded in `deploy-plan.json` + this file. Flagged for parent/Aditya decision.

## Remaining steps (parent / Aditya)
1. Publish `frontend/index.html` as the project website; put the URL into `SUBMISSION_PACK.md` + frontend already carries the live addresses.
2. Publish the code to a public GitHub repo (local git repo is initialized and committed; push is an external step — suggested repo name `agentmandate` under aprtama929-sudo). Rules require publicly open-source code.
3. (Optional, closes the BscScan item) Provide a BscScan/Etherscan API key → run direct BscScan verification.
4. Run the interaction campaign per `INTERACTION_PLAN.md` (goal: ≥30 real Agent ID holders registered before 2026-12-09 15:00 WIB). `agentCount()` on the registry is the public counter.
5. Submit the project via the official route (see SUBMISSION_PACK.md) **before 2026-12-09 08:00 UTC** — pack is fully prepared; submission itself is NOT done yet.
6. Optional demo depth: create one small real mandate on mainnet (e.g., deployer as principal appointing a second registered Agent ID holder) once a second holder registers — proves the full mandate loop on mainnet, not just registration.
