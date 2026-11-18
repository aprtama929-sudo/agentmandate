# Interaction Plan — reaching ≥30 real Agent ID holders (honest, no wash)

**Goal:** at least 30 distinct Agent ID addresses interact with the AgentMandate contracts during the submission period (Innovation Award eligibility; also the Ecosystem Award's primary metric). The natural core interaction is `AgentRegistry.registerAgent()` — one transaction per holder, ~95k gas (≈0.000005 BNB at 0.05 gwei — a fraction of a cent), and it is a *real* product action: registered agents become appointable under mandates.
**Public counter:** `agentCount()` on AgentRegistry `0x0e69ed84dd472B963Ac1BFdEA43092964e40609d` (currently 1 — the deployer, aditya93.ai).
**Deadline:** 2026-12-09 15:00 WIB.
**Hard rules:** every interaction must be a real Agent ID holder acting voluntarily from their own wallet. No fake registrations, no Sybil wallets, no paid wash volume, no promised returns or payment-for-interaction offers — the organizers explicitly disqualify manipulation, and a registration drive is only legitimate because registering is the product's genuine first step.

## Channels (per Aditya's approved spread plan, 2026-11-18 18:47 WIB)
1. **Boltbook** — the community is Agent ID holders by definition; Muse posts via the Boltbook API (already an established channel). One launch post + one progress update midway.
2. **X (@KPratama7393)** — Muse prepares copy; **Aditya posts himself** (Muse cannot log into X). Include the campaign hashtags #BinanceWalletHackathon and #AgenticWallet — this also makes the post eligible for the separate Community Promotion Campaign (20 winners share 2,000 USDC; requires submitting the post link via the official campaign survey).
3. **Binance Square** — same arrangement: copy prepared by Muse, posted by Aditya.
4. **Garapan / airdrop community groups (FB/Telegram)** — Aditya shares the prepared copy in groups where Agent ID holders gather. Target groups, not his personal profile (per his standing promotion rule).

## Sequencing
- **Day 0 (website live):** Boltbook launch post + X post + Square post within the same hour; pin the website link everywhere. First milestone check after 24h (`agentCount()`).
- **Day ~5:** progress update ("N agents registered"), repost in groups with a short demo recap (what a mandate is, 3 bullet points). Answer questions factually; never promise rewards.
- **Day ~12:** final call post ("registration still open until 9 Dec") + a worked example: a screenshot of the dashboard and one real mandate flow if a second holder has created one.
- **Daily:** check `agentCount()`; log the number in STATUS.md. If registrations stall below ~15 by day 7, escalate with a demo video/short screen recording of the register flow (30 seconds, phone-friendly) rather than more text posts.

## Draft copy

### Boltbook post (Muse posts via API)
> **AgentMandate is live on BNB Chain — registration open for Agent ID holders**
>
> I built AgentMandate for the Binance Wallet Agent ID Hackathon: scoped payment mandates that only Agent ID holders can use.
>
> How it works:
> • Holders of an Agent ID can register as agents in the AgentRegistry — only registered agents can be appointed.
> • A principal deposits BNB or USDT and sets a per-payment cap, a total budget, and an expiry.
> • The appointed agent pays strictly inside those limits. Over-cap, over-budget, or expired payments revert on-chain. The principal can revoke and reclaim unspent funds anytime.
>
> Agent ID is checked at registration, at mandate creation, and again on every payment — it is the access layer, not a badge.
>
> Contracts (verified, open-source, no admin keys):
> AgentRegistry: 0x0e69ed84dd472B963Ac1BFdEA43092964e40609d
> AgentMandate: 0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5
>
> Try it: [WEBSITE URL] — connect your Agentic Wallet and register as an agent (one small gas-only transaction). Feedback welcome.

### X post (Aditya posts; ≤280 chars with link counted as 23)
> AgentMandate is live on BNB Chain.
>
> Payment mandates only Agent ID holders can use: register as an agent, get appointed, pay inside a hard cap + budget + expiry set by the principal.
>
> Verified & open-source, no admin keys.
> [WEBSITE URL]
> #BinanceWalletHackathon #AgenticWallet

### Binance Square post (Aditya posts; longer form)
> **AgentMandate — scoped payment mandates for Agent ID holders**
>
> Built for the Binance Wallet × BNB Chain Agent ID Hackathon (60,000 USDC).
>
> The problem: giving an AI agent the ability to pay usually means giving it your wallet. AgentMandate replaces that with an on-chain mandate: the principal deposits BNB or USDT and fixes a per-payment cap, a total budget, an expiry, and an optional payee allowlist. The agent pays freely inside the mandate and provably cannot step outside it — every limit is enforced by the contract, and the principal can revoke and reclaim unspent funds at any time.
>
> Agent ID is the access layer at three points: only Agent ID holders can register as agents; only Agent ID holders can create mandates; and an agent's eligibility is re-checked on every single payment.
>
> Live on BNB Chain mainnet, contracts verified (Sourcify exact match) with no admin keys:
> AgentRegistry 0x0e69ed84dd472B963Ac1BFdEA43092964e40609d
> AgentMandate 0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5
>
> If you hold an Agent ID, you can register as an agent right now: [WEBSITE URL]
> #BinanceWalletHackathon #AgenticWallet

## What NOT to do
- Do not offer BOLT/USDT/airdrop promises in exchange for registering.
- Do not register from wallets that are not genuine Agent ID holders (they can't anyway — the contract reverts — and manufacturing holders would be mass-registration manipulation).
- Do not spam the same group repeatedly; one launch post + one update per channel.
- Do not describe registration as an investment or attach any return language.
