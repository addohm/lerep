# Changelog

All notable changes to leRep. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.9.0-beta] - 2026-11-21

The first beta. It hasn't been tried much in game yet: reports are welcome on the CurseForge
issues page.

### Added

- **Three plans** for your side's trade faction (Azeroth Commerce Authority or Durotar Supply and
  Logistics), each the cheapest gold path to its targets:
  - **Rank:** to a rank, with Craftsman's Writs, the Shipping Label and crate returns with Forged
    Delivery Receipts, cheapest gold per rep first.
  - **Favor:** Merchant's Favor for a reward, by filling Waylaid Crates, cheapest gold per Favor
    first.
  - **Combined:** both at once; receipts are priced at what their Favor costs after your Favor
    goal.
  - Writs are once a day each: a plan finishes within the days you pick (7 by default), with
    receipts for what writs can't cover in that time.
  - Writ items and crafted crate bundles cost the cheaper of buying and crafting them with
    recipes you know.
- **Each plan tab:** your rep and Favor, the current step (what to buy or craft, where to hand it
  in, what it gives), the route with every step's rep, Favor and cost, the whole plan's cost and
  days, and how far the gold you carry goes.
- **Rewards:** what Favor buys, grouped by the rank it needs, then recipes by profession (yours
  open, recipes you know marked); click one to make it your goal, or press All for every recipe
  of a profession you don't have yet.
- **Shopping:** what today's steps need, less what you hold, with Send to Auctionator.
- **Options:** targets, your Legacy perks (Diplomat, Performance Bonus), when a writ counts as on
  sale, the Coin Pouch, step alerts.
- **It learns as you play:** the recipes you know, the receipt's Favor price at the scribe, your
  rep bonus, what each kind of crate pays and what Coin Pouches hold.
- `/lerep`, `/lerep status`, `/lerep help`; a minimap button and the addon menu entry.
- Built-in data from Forever's game files and Efficient Games' player data (CC BY 4.0): 150
  writs, 30 crates, the recipes behind writ items, Favor rewards with their ranks and sellers.
- Open source under the GNU GPLv3.
