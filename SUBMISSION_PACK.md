# AgentMandate — Hackathon Submission Pack (PREPARED, NOT YET SUBMITTED)

**Contest:** Binance Wallet × BNB Chain — Agent ID Hackathon (60,000 USDC)
**Announcement:** https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf
**Deadline:** 2026-12-09 08:00 UTC (15:00 WIB) — submit during the Submission Period; no registration needed.
**Submission route:** the announcement instructs participants to submit project name, website, contract address(es), Agent ID usage description and other required materials during the submission period. Take the live submission link from the announcement / Binance Wallet campaign page at submission time (the announcement page carries the campaign survey link pattern used by Binance Wallet campaigns). **Do not invent a different route.** All field content is prepared below, ready to paste.
**Team rule:** each team may submit ONE project — this is the one.

---

## Field: Project name
AgentMandate

## Field: One-line description
Scoped payment mandates that only Agent ID holders can create and execute — principals appoint registered agents to pay in BNB or USDT inside hard on-chain limits (per-payment cap, total budget, expiry, optional payee allowlist).

## Field: Website
TBD — parent publishes `frontend/index.html` from this workspace (single static page; contract addresses already filled in). Paste the live URL here before submitting.

## Field: Contract addresses (BNB Chain mainnet, chain 56)
- AgentRegistry: `0x0e69ed84dd472B963Ac1BFdEA43092964e40609d`
  - BscScan: https://bscscan.com/address/0x0e69ed84dd472B963Ac1BFdEA43092964e40609d
  - Sourcify (exact match): https://sourcify.dev/#/lookup/0x0e69ed84dd472B963Ac1BFdEA43092964e40609d
  - Deploy tx: `0x0179ece1fa19b98d9b0ec9398f142d7737b0a69bef18bba356cb89ef8f8c0f2b`
- AgentMandate: `0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5`
  - BscScan: https://bscscan.com/address/0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5
  - Sourcify (exact match): https://sourcify.dev/#/lookup/0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5
  - Deploy tx: `0xbb60960a29001477b0f7fc6cb567875c505b899120391a8bebe1c83c6433345f`
- Agent ID contract used (SPACE ID, provided by the organizers): `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
- Source code: this workspace (`src/`, `test/`, `frontend/`) — publish to a public GitHub repo before submitting and paste the repo URL here: TBD

## Field: Agent ID usage description (how Agent ID is core, not decorative)
AgentMandate is built around Agent ID at three load-bearing points:

1. **Registry gate.** `AgentRegistry.registerAgent()` reverts unless the caller's `balanceOf` on the SPACE ID Agent ID contract (`0x60b9262456de011f7d15a54cdd8c48baaa8b022f`) is greater than zero. Only registered agents exist as far as the payment system is concerned.
2. **Creation gate.** `AgentMandate.createMandate()` reverts unless the principal holds an Agent ID, and unless the appointed agent is currently eligible in the registry (registered AND still holding an Agent ID).
3. **Execution gate.** Every `pay()` call re-checks the agent's live registry eligibility before moving funds. An agent that deregisters or stops holding an Agent ID immediately loses the ability to execute payments under any mandate — while principals always keep the right to revoke and withdraw their own unspent funds.

So Agent ID is the identity, access-control, and ongoing-authorization layer of the product: it decides who may offer agent services, who may delegate money, and whether an agent's authority is still valid at the moment money moves.

## Field: Full project description
AgentMandate lets a wallet holder (the principal) delegate a narrowly-scoped payment ability to an AI agent without handing over wallet access. The principal deposits BNB or USDT into a mandate that names one registered agent and fixes four hard limits in the contract: a per-payment cap, a total budget, an expiry time, and an optional payee allowlist. The agent can pay freely inside those bounds and provably cannot exceed them — over-cap, over-budget, over-balance, expired, and non-allowlisted payments all revert on-chain. Every action emits an event, so the full life of a mandate is a public, verifiable audit trail.

Typical uses: a trading/research agent paying for data or services within a daily budget; a community agent disbursing small approved payments; any automation that needs to spend small amounts without custody of the principal's wallet.

Safety by construction: neither contract has an owner or admin functions; the deployer cannot pause, upgrade, or withdraw user funds; supported assets are restricted to native BNB and BSC USDT; the principal can revoke at any time and reclaim every unspent unit, and expired mandates refund the principal when closed. The product is live on BNB Chain mainnet with verified, open-source contracts (Sourcify exact match) and a working web interface; the deployer wallet (aditya93.ai) is registered as agent #1 and the registry counter is public on-chain.

## Field: Reward receiving address
`0x94aAb8d86DacE5b395056E709d4f14b5460C6E03` (Aditya's Agentic Wallet — the wallet holding Agent ID aditya93.ai; also the deployer of both contracts)

## Field: Team / contact
- Builder: Aditya Pratama — Agent ID: **aditya93.ai**
- Individual entry (solo builder + AI-assisted development)
- X: @KPratama7393

## Assets
- Logo: `logo.svg` in this workspace (shield + checkmark; no Binance/BNB branding, per the red lines).
- Screenshots: take from the live frontend after publishing (connect view + dashboard view).

## Red-line self-check (all pass)
- No QR-code / pairing-code web login — frontend uses the standard injected-wallet connect only. ✅
- No bypassing user confirmation — every frontend action is an explicit wallet-confirmed transaction. ✅
- No unauthorized / scheduled / hidden transfers; no unlimited approvals — USDT funding uses an exact-amount approval initiated by the user; the contract never moves funds outside mandate rules. ✅
- Contracts open-source with owner permissions documented — there is no owner; permissions are documented in the contract NatSpec, the frontend, and this pack. ✅
- No "Binance"/"BNB" in the project name (AgentMandate), token (none), or domain (TBD — keep it clean). ✅
- No credential collection of any kind. ✅
- No promised returns anywhere in copy (payments tool; explicit "no yield/returns" note on the site). ✅
- Not a trading product (no risk-warning requirement triggered); not a wallet-lookup tool. ✅
- No wash volume / mass-registration manipulation — interactions are real Agent ID holders registering voluntarily (see INTERACTION_PLAN.md). ✅

## Pre-submit checklist
- [x] Contracts deployed on BSC mainnet
- [x] Contracts verified (Sourcify exact match; BscScan direct verification pending an API key — see STATUS.md)
- [x] Live self-interaction done (agent #1 registered)
- [ ] Website published + URL pasted above
- [ ] Public GitHub repo published + URL pasted above
- [ ] ≥30 Agent ID addresses interacted (track `agentCount()`; see INTERACTION_PLAN.md)
- [ ] Submission sent before 2026-12-09 08:00 UTC
