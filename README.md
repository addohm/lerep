# LeRep

A World of Warcraft: Forever addon that finds the cheapest gold path to a
reputation rank and an amount of Merchant's Favor with the trade factions:
the Azeroth Commerce Authority (Alliance) and Durotar Supply and Logistics
(Horde). It tells you which writs to buy, which crates to fill, how many, and
what it all costs, using your auction house prices.

Status: being built (0.1.0); the data is in, the addon isn't yet. The agreed design is in
[ROADMAP.md](ROADMAP.md).

## Getting started

```sh
git clone git@github.com:addohm/LeRep.git
```

TODO: installing and running it in game, once there's code.

## Usage

TODO: once it's built. The plan: `/lerep` opens a window with Rank, Favor
and Combined plans (each with its current step and route), a Shopping list
with Send to Auctionator, and Options.

## Credits

LeRep's data (`LeRep/Data.lua`) is built from Forever's game data files and
from quest, NPC and vendor data from Efficient Games (https://efficient.games),
licensed under CC BY 4.0
([github.com/JIVESCORP/eg-link-output-wowf](https://github.com/JIVESCORP/eg-link-output-wowf)).

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's deployed
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
