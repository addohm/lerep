# Changelog

All notable changes to LeRep. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Standard docs: README, CLAUDE, CHANGELOG, DEPLOY, SECURITY and ROADMAP (2026-11-19).
- Docs filled in with what's known so far, with TODO questions (2026-11-19).
- The agreed design in ROADMAP.md: Rank, Favor and Combined plans (2026-11-19).
- The data: `tools/fetch_sources.py` and `tools/gen_data.py` build
  `LeRep/Data.lua` from Forever's game data and Efficient Games' player data:
  150 writs, 30 crates with their bundles, 218 recipes behind writ items and
  crafted bundles, vendor prices, Favor rewards and goals, the camps.
- The core: settings, Auctionator/TSM and vendor prices (from leprofit),
  your standing, Favor, Shipping Label and today's writs, and a recorder
  that learns the receipt's price, your rep bonus, what each kind of crate
  pays and what Coin Pouches hold. `/lerep status`. Tests with a fake game
  client.
- The planner: Rank, Favor and Combined plans, cheapest gold per rep and per
  Favor, finishing within a number of days (7 by default); writ items and
  crafted bundles at the cheaper of buying and crafting; the steps and
  today's shopping list.
- The window: Rank, Favor and Combined tabs (targets, progress, the current
  step and the route), Shopping with Send to Auctionator, Options; a minimap
  button and the addon menu entry; step alerts in chat.
