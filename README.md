# leRep

A World of Warcraft: Forever addon that finds the cheapest gold path to a
reputation rank and an amount of Merchant's Favor with the trade factions:
the Azeroth Commerce Authority (Alliance) and Durotar Supply and Logistics
(Horde). It tells you which writs to buy, which crates to fill, how many, and
what it all costs, using your auction house prices.

Status: 0.9.0-beta, the first beta; little tried in game yet ([TESTING.md](TESTING.md) is the checklist). Open source under the GNU GPLv3 (`LICENSE`). The agreed design is in
[ROADMAP.md](ROADMAP.md).

## Getting started

Players: unzip the release into `World of Warcraft\_forever_\Interface\AddOns\`, so
there's an `AddOns\leRep` folder, and install Auctionator.

From the repo, on Windows: clone it (`git clone https://github.com/addohm/lerep.git`) and run
`tools\install_forever.cmd`, which copies `leRep` into the game (DEPLOY.md has the details).
The tests run with `.venv/bin/python tests/run_tests.py` (set up with
`python3 -m venv .venv && .venv/bin/pip install lupa`).

## Usage

`/lerep` (or the minimap button) opens the window. It needs Auctionator:
scan the auction house so leRep has writ, crate and material prices.

- **Rank, Favor, Combined:** three plans. Rank reaches a rank, Favor earns
  Merchant's Favor for a reward, Combined does both at once. The top bar sets
  the rank, the Favor goal and how many days to finish in. Each tab shows your
  progress, the current step (what to buy or craft, where to hand it in), and
  the route: every step with the rep or Favor it gives and its cost. Click a
  step to see it in the box; hover for detail. Over several days the route
  splits into Today (do these now) and Later: a forecast of the next days'
  writs (hover it for the writs a day and the day you reach each rank), then
  any receipts, kept for the end in case writs cover more. The plan is worked
  out again each day: scan the auction house and open leRep. A writ's cost is the writ plus
  its item, less the Coin Pouch it pays; when the pouch pays more, the gain
  shows in green with a "+". The totals say what the plan costs (after and
  before Coin Pouches) and how far the gold you carry goes.
- **Rewards:** what Merchant's Favor buys, grouped by the rank it needs
  (unlocked, or how much rep to go), then recipes by profession: your own
  professions' lists are open, and recipes you know are marked and listed
  last. Click a reward to make it your Favor goal; press All on a profession
  to aim for every recipe of it you don't have yet (each drops out as you
  learn it). The plans then work towards it.
- **Shopping:** what today's steps need, for the plan tab you opened last:
  crafted items broken down into materials, less what you hold. Send to
  Auctionator makes a "leRep" shopping list.
- **Options:** the targets, your Legacy perks (Diplomat, Performance Bonus),
  when a writ counts as on sale, the Coin Pouch, step alerts, and what leRep
  has recorded.
- `/lerep status` shows your faction, standing, Favor and price sources;
  `/lerep help` lists the commands.

Writs give rep (each once a day), filled crates give Favor, and a Forged
Delivery Receipt (15 Favor, from Friendly) on an empty crate gives 50 rep.
leRep learns as you play: the recipes you know (open your profession
windows), the receipt's price, and what turn-ins and Coin Pouches really
give.

## Credits

leRep's data (`leRep/Data.lua`) is built from Forever's game data files and
from quest, NPC and vendor data from Efficient Games (https://efficient.games),
licensed under CC BY 4.0
([github.com/JIVESCORP/eg-link-output-wowf](https://github.com/JIVESCORP/eg-link-output-wowf)).

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's deployed
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
