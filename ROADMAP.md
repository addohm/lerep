# Roadmap

What's done for Lerep, and what's next. Update it in the same commit as the
change.

## Done

- Standard docs (2026-11-19).
- Design agreed (2026-11-19, below).
- 0.1.0 step 1, the data (2026-11-19): 150 writs and 30 crates, matching an
  independent list exactly. Only 3 writ customers are recorded so far; the
  game marks the customer on your map anyway.
- 0.1.0 step 2, the core (2026-11-19): settings, prices, standing and Favor,
  the recorder, tests.
- 0.1.0 step 3, the planner (2026-11-19): the three plans, steps and
  shopping list, with make-vs-buy; tests for each plan.
- 0.1.0 step 4, the window (2026-11-19): the three plan tabs, Shopping,
  Options, minimap button, step alerts. A stock icon until the release
  kit's art.
- The Rewards tab (2026-11-20).
- "How far your gold goes" in each plan's totals (2026-11-20): it was in the
  design but missed from 0.1.0.
- 0.1.0 step 5, tools (2026-11-19): install and release scripts,
  `TESTING.md`. 0.1.0 is built; not yet tried in game.

## Next

1. In-game test of 0.1.0 (`TESTING.md`).
2. The release kit: icon and banner art, `LISTING.md`, a tagged zip; publish
   on CurseForge and Wago.

## Ideas

- Map pins or a waypoint arrow to the camps and to each writ's customer.
- Lerep's lines in ordinary item tooltips (gold per rep, "the plan needs N").
- Materials on your alts.
- Other reputations that have turn-ins.

## Design (agreed 2026-11-19)

**What it is.** A WoW: Forever addon that finds the cheapest gold path to a
reputation rank and an amount of Merchant's Favor with the trade factions:
Azeroth Commerce Authority (Alliance, faction 2586) and Durotar Supply and
Logistics (Horde, 2587). It plans your own side's faction, since writs only
give rep to it. It works the way a profession-levelling planner does (current
step, route, shopping list), with leprofit's look.

**How the factions work on Forever** (checked 2026-11-19 against the game's
data files, players' recorded turn-ins and guides):

- **Rep** comes from:
  - Craftsman's Writs: 75 / 125 / 200 rep (Journeyman / Expert / Artisan),
    150 of them, each once a day. Buy the named writ on the AH and deliver
    it with the item it asks for to its customer; each pays a Coin Pouch.
  - The Shipping Label: 2,000 rep and 50 Favor, once per character.
  - Crate Return: a Forged Delivery Receipt (15 Favor, needs Friendly) on
    an empty Waylaid Crate, handed in for 50 rep. No daily limit.
- **Favor** comes from filled Waylaid Crates (5 to 40 each by tier and
  white/green), which give no rep. The Performance Bonus Legacy perk gives a
  chance of double Favor.
- The Diplomat Legacy perk adds up to 10% rep. The Human racial is gone.
- No turn-in stops giving rep before Exalted (42,000 from Neutral).
- Guesses to correct in game: the receipt's price and rank gate (guides
  only), Favor from Artisan crates (player reports), Coin Pouch values.

**Plans.** Three tabs, each a plan to the shared targets:

- **Rank:** to the target rank. Writs, the Label and receipts, cheapest gold
  per rep first, plus only the crates its receipts need.
- **Favor:** to the Favor goal. Crates only, cheapest gold per Favor first.
- **Combined:** both targets at once. Receipts are priced with the Favor
  they actually use, so if the Favor goal has used up the cheap crates,
  receipts get dearer and the plan leans on writs.

**Targets:** a rank (To Friendly / Honored / Revered / Exalted, Exalted by
default) and an optional Favor goal: pick a reward (Pack Kodo 6,000,
Minimule 1,500, a Certification 1,000...) or type an amount. None by default.
Saved per character.

**Costs:**

- A writ: its AH price + its item - the Coin Pouch.
- A receipt: an empty crate + 15 Favor at its cost to earn (Favor you
  already hold counts at that cost too).
- A filled crate: the crate + the cheapest bundle it accepts - the silver it
  pays.
- Items and bundles cost the cheaper of buying and crafting them (crafting
  only with recipes this character knows), as in leprofit.
- Writs are once a day each. A plan finishes within a number of days (1, 3,
  7, 14, 30 or no limit; 7 by default; the owner's pick, 2026-11-19): today's
  steps use the writs on sale at your last scan (each once), later days
  assume the same writs at today's prices (an estimate), and receipts cover
  what writs can't in that time.
- Crates on sale: Auctionator's count at the last scan when it has one,
  else as many as needed at today's price. Receipts use the cheapest empty
  crate.
- Sealed writs (random) are never bought; ones in your bags get a step to
  open them, and the writ inside joins the plan.

**Window** (leprofit's style): Rank | Favor | Combined | Rewards | Shopping |
Options.

- Each plan tab: the current step on top (what to buy or craft: have, buy,
  cost; where to hand it in; what it gives, e.g. "+125 rep" or "+20 Favor"),
  the route below, with gold and days totals and "your gold runs out at...".
- Shopping: one combined list for the plan tab you opened last (named on the
  tab), with Send to Auctionator.
- Step-done alerts follow that same plan.
- Rewards (added 2026-11-20, the owner's idea): laid out like the Combined
  tab without the days dropdown. What Favor buys, grouped by the rank it
  needs (the game data's gate, else the guides', marked "?"), then any rank,
  then recipes (one line per profession, opened with a click). Each row:
  rank, Favor, gold; the box shows the picked reward (cost, unlocked or rep
  to go, your Favor, who sells it). Clicking a reward makes it the Favor
  goal and raises the target rank if it needs more.
- Opened with `/lerep`, the minimap button and the addon menu.

**Data:** generated by `tools/gen_data.py` from Forever's game data files
(wago.tools, product wowf) and the EG Link dataset (CC BY 4.0, credited in
the README), plus what you record playing: standing, Favor, the scribe's
receipt price and what each turn-in really gave.

**Packaging:** one addon, `Lerep`, settings per character; leprofit's
install, release and test tools. Published on CurseForge and Wago.
