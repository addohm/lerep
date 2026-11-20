# Testing in game

What to check on WoW: Forever before a release. The automated tests (`tests/run_tests.py`) run the
plans and the window against a fake client; these need the real one. Tick each item off with the
build you tried (`/lerep help` shows it).

## Loading

- [ ] Lerep is in the AddOns list with its notes, and isn't "out of date".
- [ ] `/lerep help` shows the version and build; no Lua errors on login (`/console scriptErrors 1`).
- [ ] `/lerep status` names your side's faction, your standing and rep, your Merchant's Favor, and
      whether the Shipping Label is handed in. Check them against the game's reputation pane and
      currency tab.
- [ ] The minimap button opens the window (left-click: the plan you opened last; right-click:
      Options) and can be dragged; the addon menu entry by the minimap does the same.

## Plans

Scan the auction house with Auctionator first.

- [ ] **Rank:** the bar shows your standing and rep against the target; the top bar's rank and day
      dropdowns change the plan. Steps: the Shipping Label (if not done), today's writs cheapest
      first, crate fills for receipts' Favor, receipts (only from Friendly), and later days.
- [ ] **Favor:** pick a reward in the goal dropdown (only your side's tabard and sign are listed);
      the plan fills crates cheapest per Favor first. "No Favor goal" asks for one.
- [ ] **Combined:** both bars; with a Favor goal set, receipts get dearer than in the Rank plan when
      the goal uses up the cheap crates.
- [ ] Clicking a route row shows it in the step box; hovering shows its detail (for a writ: the
      writ's price, the item's, the Coin Pouch, gold per rep). Shift-click puts its link in chat.
- [ ] The step box's item rows show have, buy and cost; hovering shows the item's tooltip.
- [ ] Writs you've done today drop out of today's steps after the hand-in.
- [ ] A writ you hold in your bags is planned without buying it.
- [ ] Holding a Sealed Writ adds an "Open" step; an unread Waylaid Crate adds a "Read the label" step.
- [ ] Below Friendly, no receipts are planned; the totals line explains a shortfall.

## Rewards

- [ ] Rewards are grouped Friendly, Honored, Revered, Exalted, Any rank, then Recipes; each rank
      heading says unlocked or how much rep to go. Only your side's tabard and sign are listed.
- [ ] A "?" after a rank: its tooltip says the rank is from guides. Hovering any reward shows the
      item's own tooltip with its Favor price.
- [ ] A profession line opens and closes its recipes.
- [ ] Clicking a reward makes it the Favor goal (the goal dropdown shows it) and raises the target
      rank if it needs more; the box says "Your goal" and the Combined plan's cost.
- [ ] The box names who sells it and where (or your camp, where no seller is recorded).

## Shopping

- [ ] The heading names the plan tab you opened last.
- [ ] Crafted items you know the recipe for are broken into materials (when cheaper); what you hold
      is taken off once.
- [ ] Send to Auctionator makes a "Lerep" list in Auctionator's Shopping tab with the right
      quantities; vendor items are left out and named in chat.

## Recording

- [ ] At the scribe (Dianne Softstep / Kurvelk Shadowhoof), opening the vendor records the Forged
      Delivery Receipt's Favor price (chat line; Options > What Lerep has seen).
- [ ] Handing in a writ with the Diplomat perk sets "More rep per turn-in" to your bonus.
- [ ] Handing in a filled crate records its Favor (chat line; Options).
- [ ] Opening a Coin Pouch records what it held (Options).
- [ ] Opening a profession window reads the recipes you know (`/lerep status` counts them).
- [ ] Step alerts: with "Say in chat when a step is done" on, handing in the first step's writ says
      "step done" and names the next step.

## Options

- [ ] Every row changes what it says; Defaults puts them back (the Favor goal too).
- [ ] The Favor amount box takes a number and Enter; 0 clears the goal.
