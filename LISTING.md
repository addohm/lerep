# leRep: CurseForge and Wago listing

Copy-paste material for the project pages: it's published on both CurseForge and Wago. Keep the
feature list in step with README.md.

---

## Basics

| Field | Value |
| --- | --- |
| Name | leRep |
| Slug | `lerep` |
| Game version | WoW: Forever (Interface 16001) |
| Author | addohm |
| Release type | Beta (0.9.0-beta) |
| License | GNU GPLv3 (`LICENSE`) |
| Source | https://github.com/addohm/lerep |
| Issues | the CurseForge project's issues page (https://www.curseforge.com/wow/addons/lerep/issues once the project exists) |
| Upload | `release/leRep-<version>.zip` (one `leRep` folder) |

**Images**
- Avatar: `art/lerep-icon-400.png`
- Banner / header: `art/lerep-banner.png` (1600x500)

**Categories**
- CurseForge: Professions (main), Auction & Economy, Quests & Leveling
- Wago: Professions (main), Auction & Economy, Quests

**Summary** (the one-liner under the name; 161 characters)

> The cheapest gold path to Azeroth Commerce Authority or Durotar Supply and Logistics rep and
> Merchant's Favor: which writs, which crates, how many. WoW: Forever.

**Short tagline** (for images or a Discord post)

> The cheapest gold path to rep and Favor.

---

## Description

*(Paste as Markdown. Both sites accept it.)*

### leRep

**The cheapest gold path to trade-faction rep and Merchant's Favor. Built for WoW: Forever.**

leRep plans your way up with your side's trade faction, the Azeroth Commerce Authority or
Durotar Supply and Logistics, using your Auctionator prices. It tells you which Craftsman's Writs
to buy, which Waylaid Crates to fill and with what, when Forged Delivery Receipts are worth it,
how many of each, and what it all costs.

#### How the factions work on Forever

- **Rep** comes from Craftsman's Writs (75, 125 or 200 each, every writ once a day), the one-time
  Shipping Label (2,000), and returning empty crates with a Forged Delivery Receipt (50 each,
  from Friendly).
- **Merchant's Favor** comes from filled Waylaid Crates, which give no rep. A receipt costs 15
  Favor, so Favor and rep are linked: leRep prices each receipt at what its Favor costs to earn.

#### Three plans

- **Rank:** reach a rank (Friendly to Exalted), cheapest gold per rep first.
- **Favor:** earn the Favor for a reward (the Pack Kodo, the Minimule, a Certification, a recipe,
  or every recipe of a profession you don't have yet), cheapest gold per Favor first.
- **Combined:** both at once. When your Favor goal uses up the cheap crates, receipts get dearer
  and the plan leans on writs instead.
- **Finish within** 1, 3, 7, 14 or 30 days, or no limit: writs fill the days and receipts cover
  the rest.
- Writ items and crafted crate bundles (bolts, bars, cloth) cost the cheaper of buying them and
  crafting them with recipes you know.

#### Each plan tab

- **Your progress:** rep towards the rank, Favor towards the goal.
- **The current step:** what to buy or craft (have, buy, cost), where to hand it in, and what it
  gives.
- **Today and Later:** today's steps to do now; then a forecast of the next days' writs (hover
  it for the writs a day and the day you reach each rank), with any receipts kept for the end.
  The plan is worked out again each day from that day's writs and prices.
- **The route:** every step with its rep, Favor and cost; click one to see it, hover for the
  detail (a writ's price, its item, the Coin Pouch, gold per rep). Writs whose Coin Pouch pays
  more than they cost show the gain in green.
- **Totals:** the whole plan's cost and days, and how far the gold you carry goes.

#### Rewards

What Merchant's Favor buys, grouped by the rank it needs (unlocked, or how much rep to go), then
the recipes by profession: your own professions' lists are open, and recipes you know are marked.
Click a reward to make it your goal; press **All** on a profession for every recipe of it you
don't have yet.

#### Shopping

Everything today's steps need, crafted items broken down into their materials, less what you
hold. **Send to Auctionator** makes a shopping list with the right quantities.

#### It learns as you play

The recipes you know (open your profession windows), the receipt's real Favor price at the
scribe, your rep bonus from the Diplomat perk, what each kind of crate really pays, and what Coin
Pouches hold. These replace the built-in guesses.

#### Commands

| Command | |
| --- | --- |
| `/lerep` | Open or close the window (also the minimap button and the addon menu) |
| `/lerep status` | Your faction, standing, Favor and price sources |
| `/lerep help` | All commands |

#### Good to know

- **Needs Auctionator** (or TSM) for prices: scan the auction house and the plans fill in.
- **This is a beta.** Please report what you find on the issues page: what you did, what you
  expected, and the output of `/lerep status` and `/lerep help` (it shows the version).
- **Later days are an estimate:** they assume today's writs are on sale each day at today's
  prices.
- A few numbers come from guides until leRep sees the real ones: the receipt's price and rank,
  Favor from Artisan crates, and what Coin Pouches hold.
- Settings are per character. English game clients only. Nothing is sent to other players.
- Data from Forever's game files and from Efficient Games (https://efficient.games), licensed
  under CC BY 4.0.
- Open source under the GNU GPLv3: [github.com/addohm/lerep](https://github.com/addohm/lerep).

---

## Screenshots to take

1. The Combined tab after an Auctionator scan, with a Favor goal set: both bars, the step box
   on a writ, and the route.
2. A writ's tooltip in the route: the writ's price, its item, the Coin Pouch and gold per rep.
3. The Rank tab below Friendly, showing the Shipping Label step and later days.
4. The Rewards tab with your profession's recipes open and a reward picked as the goal.
5. The Shopping tab, and Auctionator's Shopping tab with the "leRep" list after Send to
   Auctionator.
6. The Options tab.

---

## Release notes

### 0.9.0-beta

The first beta. Three plans for your side's trade faction: Rank (writs, the Shipping Label and
receipts, cheapest gold per rep), Favor (filled crates, cheapest gold per Favor) and Combined
(both, with receipts priced at what their Favor really costs), finishing within the days you
pick. Writ items and crafted bundles at the cheaper of buying and crafting. A Rewards tab to pick
a goal, from one reward to every recipe of a profession. Shopping with Send to Auctionator.
leRep learns the receipt's price, your rep bonus, crate Favor and Coin Pouch values as you play.
