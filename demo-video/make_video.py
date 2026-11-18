#!/usr/bin/env python3
"""AgentMandate demo video — captioned slides from verified on-chain data (~60s)."""
from PIL import Image, ImageDraw, ImageFont
import textwrap, os, subprocess

OUT = os.path.dirname(os.path.abspath(__file__))
W, H = 1280, 720
BG = (10, 14, 24)
GOLD = (240, 185, 11)
WHITE = (240, 244, 250)
DIM = (160, 172, 190)
GREEN = (46, 204, 113)
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANSB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def F(path, size): return ImageFont.truetype(path, size)

def slide(title, lines, accent=GOLD, footer="AgentMandate — BNB Chain mainnet (56)"):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 10], fill=accent)
    d.text((60, 48), title, font=F(SANSB, 44), fill=WHITE)
    y = 140
    for text, kind in lines:
        if kind == "body":
            for wline in textwrap.wrap(text, 58):
                d.text((60, y), wline, font=F(SANS, 30), fill=WHITE); y += 42
            y += 14
        elif kind == "mono":
            for wline in textwrap.wrap(text, 62):
                d.text((60, y), wline, font=F(MONO, 24), fill=GREEN); y += 34
            y += 12
        elif kind == "dim":
            for wline in textwrap.wrap(text, 66):
                d.text((60, y), wline, font=F(SANS, 24), fill=DIM); y += 34
            y += 10
    d.text((60, H - 52), footer, font=F(SANS, 22), fill=DIM)
    return img

REG = "0x0e69ed84dd472B963Ac1BFdEA43092964e40609d"
MAN = "0xB7ACAaDd11718d3f1D2A1829ef4dC53Df7efd3d5"
slides = [
    (8, slide("AgentMandate", [
        ("Scoped payment mandates that only Agent ID holders can create and execute.", "body"),
        ("Built for the Binance Wallet x BNB Chain Agent ID Hackathon.", "body"),
        ("Live on BNB Chain mainnet. Every claim in this video is verifiable on-chain.", "dim"),
    ])),
    (8, slide("The problem", [
        ("AI agents need to spend money to be useful — paying for data, services, and fees.", "body"),
        ("But handing an agent your wallet means unlimited power over your funds. One bug or one bad prompt can drain everything.", "body"),
    ])),
    (9, slide("The mandate", [
        ("A principal deposits BNB or USDT and appoints one registered agent.", "body"),
        ("Four hard limits are fixed in the contract itself: a per-payment cap, a total budget, an expiry time, and an optional payee allowlist.", "body"),
        ("The agent pays freely inside those bounds — and provably cannot exceed them.", "body"),
    ])),
    (10, slide("Agent ID at three gates", [
        ("1. Register: AgentRegistry.registerAgent() reverts unless the caller holds an Agent ID.", "body"),
        ("2. Create: createMandate() reverts unless the principal holds an Agent ID and the agent is registered and eligible.", "body"),
        ("3. Pay: every pay() call re-checks the agent's live eligibility before any funds move.", "body"),
    ])),
    (9, slide("Live on mainnet", [
        ("AgentRegistry: " + REG, "mono"),
        ("AgentMandate: " + MAN, "mono"),
        ("Both contracts verified — Sourcify exact match, source open on GitHub.", "body"),
        ("First agent registered on-chain: aditya93.ai (agent #1).", "body"),
    ])),
    (7, slide("Safety by construction", [
        ("Neither contract has an owner or admin functions. The deployer cannot pause, upgrade, or withdraw user funds.", "body"),
        ("Principals can revoke at any time and reclaim every unspent unit. Expired mandates refund the principal when closed.", "body"),
    ])),
    (5, slide("Try it", [
        ("Website: aprtama929-sudo.github.io/agentmandate", "mono"),
        ("Code: github.com/aprtama929-sudo/agentmandate", "mono"),
        ("Connect a wallet holding an Agent ID, register as an agent, and create your first mandate.", "body"),
    ])),
]

frames = []
for i, (dur, img) in enumerate(slides):
    p = os.path.join(OUT, f"slide{i}.png")
    img.save(p)
    frames.append((p, dur))

concat = os.path.join(OUT, "concat.txt")
with open(concat, "w") as f:
    for p, dur in frames:
        f.write(f"file '{p}'\nduration {dur}\n")
    f.write(f"file '{frames[-1][0]}'\n")

mp4 = os.path.join(OUT, "agentmandate-demo.mp4")
subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", concat,
                "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-shortest",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", "30",
                "-c:a", "aac", "-movflags", "+faststart", mp4],
               check=True, capture_output=True)
total = sum(d for d, _ in slides)
print("OK", mp4, os.path.getsize(mp4), "bytes, slides total", total, "s")
