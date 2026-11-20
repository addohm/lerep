# Changelog

All notable changes to leRep. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Standard docs: README, CLAUDE, CHANGELOG, DEPLOY, SECURITY and ROADMAP (2026-11-19).
- Docs filled in with what's known so far, with TODO questions (2026-11-19).
- The agreed design in ROADMAP.md: Rank, Favor and Combined plans (2026-11-19).
- The data: `tools/fetch_sources.py` and `tools/gen_data.py` build
  `leRep/Data.lua` from Forever's game data and Efficient Games' player data:
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
- Rewards: your own professions' recipe lists open by themselves; recipes you
  know (or hold the pattern for) are marked and listed last; "All" on a
  profession makes every recipe of it you don't have yet the Favor goal,
  shrinking as you learn them.
- Each plan's totals say how far your gold goes: the whole plan, or the rep
  (and Favor) it gets you to and how much you're short.
- The Rewards tab: what Merchant's Favor buys, grouped by the rank each
  reward needs (marked "?" where only guides give the rank), then any rank,
  then recipes by profession; who sells each. Clicking a reward makes it your
  Favor goal and raises the target rank when it needs more.
- The addon is called leRep (folder, title, saved settings `leRepDB` and
  `leRepCharDB`); the repo is `addohm/lerep`. The install script removes an
  installed `LeRep` or `Lerep` folder from earlier builds.
- Tools: `tools/install_forever.cmd` (Windows install) and
  `tools/make_release.py` (the release zip); `TESTING.md`, the in-game
  checklist.
