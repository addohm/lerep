# Lerep

A World of Warcraft: Forever addon that finds the cheapest gold path to a
reputation rank and an amount of Merchant's Favor with the trade factions:
the Azeroth Commerce Authority (Alliance) and Durotar Supply and Logistics
(Horde). It tells you which writs to buy, which crates to fill, how many, and
what it all costs, using your auction house prices.

Status: 0.1.0, built and not yet tried in game ([TESTING.md](TESTING.md) is the checklist). The agreed design is in
[ROADMAP.md](ROADMAP.md).

## Getting started

Players: unzip the release into `World of Warcraft\_forever_\Interface\AddOns\`, so
there's an `AddOns\Lerep` folder, and install Auctionator.

From the repo, on Windows: clone it (`git clone https://github.com/addohm/lerep.git`) and run
`tools\install_forever.cmd`, which copies `Lerep` into the game (DEPLOY.md has the details).
The tests run with `.venv/bin/python tests/run_tests.py` (set up with
`python3 -m venv .venv && .venv/bin/pip install lupa`).

## Usage

`/lerep` (or the minimap button) opens the window. It needs Auctionator:
scan the auction house so Lerep has writ, crate and material prices.

- **Rank, Favor, Combined:** three plans. Rank reaches a rank, Favor earns
  Merchant's Favor for a reward, Combined does both at once. The top bar sets
  the rank, the Favor goal and how many days to finish in. Each tab shows your
  progress, the current step (what to buy or craft, where to hand it in), and
  the route: every step with the rep or Favor it gives and its cost. Click a
  step to see it in the box; hover for detail.
- **Rewards:** what Merchant's Favor buys, grouped by the rank it needs
  (unlocked, or how much rep to go), then recipes by profession. Click one to
  make it your Favor goal; the plans then work towards it.
- **Shopping:** what today's steps need, for the plan tab you opened last:
  crafted items broken down into materials, less what you hold. Send to
  Auctionator makes a "Lerep" shopping list.
- **Options:** the targets, your Legacy perks (Diplomat, Performance Bonus),
  when a writ counts as on sale, the Coin Pouch, step alerts, and what Lerep
  has recorded.
- `/lerep status` shows your faction, standing, Favor and price sources;
  `/lerep help` lists the commands.

Writs give rep (each once a day), filled crates give Favor, and a Forged
Delivery Receipt (15 Favor, from Friendly) on an empty crate gives 50 rep.
Lerep learns as you play: the recipes you know (open your profession
windows), the receipt's price, and what turn-ins and Coin Pouches really
give.

## Credits

Lerep's data (`Lerep/Data.lua`) is built from Forever's game data files and
from quest, NPC and vendor data from Efficient Games (https://efficient.games),
licensed under CC BY 4.0
([github.com/JIVESCORP/eg-link-output-wowf](https://github.com/JIVESCORP/eg-link-output-wowf)).

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's deployed
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
