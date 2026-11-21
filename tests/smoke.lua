-- leRep's scenarios, run by run_tests.py against the fake client (WM). Each block sets the game up,
-- does something, and checks what leRep made of it.
local D = ns.data

local function eq(a, b, what)
	if a ~= b then error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2) end
end
local function ok(v, what)
	if not v then error(what, 2) end
end
local function printed(pattern)
	for _, line in ipairs(WM.printed) do
		if line:find(pattern) then return true end
	end
	return false
end

-- The data loaded: writs, crates and recipes.
do
	local n = 0
	for _ in pairs(D.writs) do n = n + 1 end
	eq(n, 150, "writs")
	n = 0
	for _ in pairs(D.crates) do n = n + 1 end
	eq(n, 30, "crates")
	eq(D.writs[264014].item, 6048, "Shadow Protection Potion writ wants the potion")
	eq(D.writs[264014].rep, 75, "a Journeyman writ gives 75")
end

-- Your faction, standing and Favor.
do
	WM.faction, WM.standing, WM.rep, WM.favor = "Alliance", 5, 4500, 120
	eq(ns.Faction.Camp().faction, 2586, "Alliance plans the Azeroth Commerce Authority")
	local standing, value = ns.Faction.Standing()
	eq(standing, 5, "Friendly")
	eq(value, 4500, "rep")
	eq(ns.Faction.RepToGo(6), 4500, "rep to Honored")
	eq(ns.Faction.RepToGo(8), 37500, "rep to Exalted")
	eq(ns.Faction.Favor(), 120, "Favor")
	ok(ns.Faction.CanBuyReceipts(), "Friendly can buy receipts")
	eq(ns.Faction.LabelDone(), false, "label not done")
	WM.questsDone[98247] = true
	eq(ns.Faction.LabelDone(), true, "label done")
	WM.faction = "Horde"
	eq(ns.Faction.Camp().faction, 2587, "Horde plans Durotar Supply and Logistics")
	WM.faction = "Alliance"
end

-- Turn-in values: the data's guesses until leRep has seen the real ones.
do
	local crate = D.crates[248702] -- Apprentice Fabrics, green
	eq(ns.Faction.CrateFavor(crate), 10, "green Apprentice crate, from the data")
	ns.db.favorBonus = 10
	eq(ns.Faction.CrateFavor(crate), 11, "with a 10% chance of double")
	ns.db.favorBonus = 0
	eq(ns.Faction.ReceiptFavor(), 15, "receipt from the data")
	eq(ns.Faction.PouchValue("Expert"), D.coinPouch.Expert, "pouch from the data")
	ns.db.repBonus = 10
	eq(ns.Faction.Rep(75), 83, "75 rep with 10% more")
	ns.db.repBonus = 0
end

-- The recorder: the receipt's price at the scribe, and material prices.
do
	WM.merchant = {
		{ itemID = 262902, name = "Forged Delivery Receipt", price = 0, extended = true },
		{ itemID = 2321, name = "Fine Thread", price = 100 },
	}
	WM.costs = { [1] = { { 12, "|cff|Hcurrency:3402|h[Merchant's Favor]|h|r", "Merchant's Favor" } } }
	WM.Fire("MERCHANT_SHOW")
	eq(ns.adb.seen.receiptFavor, 12, "receipt price recorded")
	eq(ns.Faction.ReceiptFavor(), 12, "receipt price used")
	eq(ns.adb.vendorPrices[2321], 100, "Fine Thread recorded")
	ok(printed("Forged Delivery Receipt's price: 12"), "said so in chat")
	ns.adb.seen.receiptFavor = nil
	WM.merchant, WM.costs = {}, {}
end

-- The recorder: a writ's rep shows your rep bonus; a filled crate's Favor.
do
	WM.rep, WM.favor = 4500, 120
	WM.Fire("QUEST_COMPLETE")
	WM.rep = 4500 + 83 -- 75 with the Diplomat perk at 10%
	WM.Fire("QUEST_TURNED_IN", 94214)
	WM.RunTimers()
	eq(ns.db.repBonus, 10, "rep bonus learned from a writ")
	ns.db.repBonus = 0
	WM.Fire("QUEST_COMPLETE")
	WM.favor = 120 + 20
	WM.Fire("QUEST_TURNED_IN", 91905) -- a green Journeyman crate
	WM.RunTimers()
	eq(ns.adb.seen.crateFavor.JourneymanGreen, 20, "crate Favor recorded")
	eq(ns.Faction.CrateFavor(D.crates[248705]), 20, "and used")
end

-- The recorder: a Coin Pouch opened.
do
	WM.items[284585] = { name = "Coin Pouch", count = 1 }
	WM.money, WM.clock = 10000, 1000
	WM.Fire("BAG_UPDATE_DELAYED") -- money from earlier (not the pouch's)
	WM.clock = 1010
	WM.items[284585].count = 0
	WM.Fire("BAG_UPDATE_DELAYED")
	WM.money = 10000 + 7500
	WM.Fire("PLAYER_MONEY")
	local seen = ns.adb.seen.pouch[284585]
	ok(seen and seen.n == 1 and seen.total == 7500, "pouch value recorded")
	eq(ns.Faction.PouchValue("Expert"), 7500, "and used")
	ns.db.usePouch = false
	eq(ns.Faction.PouchValue("Expert"), 0, "pouches can be left out")
	ns.db.usePouch = true
end

-- Recipes this character knows: the profession window's list.
do
	WM.profession = "Alchemy"
	WM.recipes = { { id = 7256, name = "Shadow Protection Potion", learned = true, product = 6048, reagents = {} } }
	WM.Fire("TRADE_SKILL_LIST_UPDATE")
	WM.RunTimers()
	ok(ns.Recorder.Knows(7256), "knows Shadow Protection Potion")
	ok(not ns.Recorder.Knows(3171), "doesn't know Elixir of Wisdom")
	WM.spells[3171] = true
	ok(ns.Recorder.Knows(3171), "the game's spell check counts too")
	WM.spells[3171] = nil
	WM.profession, WM.recipes = nil, {}
end


-- The planner ------------------------------------------------------------------------------------

local function bump() ns.Changed() WM.RunTimers() end
local function step(plan, key)
	for _, s in ipairs(plan.steps) do if s.key == key then return s end end
end

-- Neutral, to Friendly: the Shipping Label (one filled crate brings it), then writs only, since
-- receipts need Friendly.
do
	WM.faction, WM.standing, WM.rep, WM.favor = "Alliance", 4, 0, 0
	WM.questsDone = {}
	ns.db.targetStanding, ns.db.favorGoal, ns.db.days = 5, 0, 7
	WM.auctionator = {
		[248682] = 5000, [2447] = 20,   -- Apprentice Herbs crate; Peacebloom (20 fill it: 400)
		[264014] = 10000, [6048] = 20000, -- Shadow Protection Potion writ and potion: 26,500 after the pouch, 75 rep
		[264013] = 5000, [3385] = 3000, -- Lesser Mana Potion writ and potion: 4,500 after the pouch
	}
	WM.items[264014] = { name = "Craftsman's Writ: Shadow Protection Potion" }
	bump()
	local plan = ns.Planner.Get("rank")
	eq(plan.needRep, 3000, "Neutral to Friendly")
	ok(plan.label and plan.label.rep == 2000, "the Shipping Label is in the plan")
	ok(step(plan, "labelfill"), "a crate is filled for the label")
	eq(step(plan, "labelfill").item, 248682, "the cheapest crate fill")
	eq(#plan.writsToday, 2, "both writs today")
	eq(plan.writsToday[1].id, 264013, "the cheaper writ first")
	eq(plan.receipts, 0, "no receipts before Friendly")
	eq(plan.days, 7, "takes the week")
	eq(plan.rep, 2000 + 75 * 2 + 75 * 12, "label + 2 writs a day for 7 days... until 3,000")
	ok(not plan.shortRep, "reaches Friendly")
	ok(step(plan, "later"), "later days are one step")
	-- No day limit: the cheaper writ alone, for longer.
	ns.db.days = 0
	bump()
	plan = ns.Planner.Get("rank")
	eq(#plan.writsToday, 1, "just the cheaper writ")
	eq(plan.days, 14, "1,000 rep at 75 a day")
	-- One day: not enough writs, and no receipts before Friendly.
	ns.db.days = 1
	bump()
	plan = ns.Planner.Get("rank")
	eq(plan.shortRep, 3000 - 2000 - 150, "short of Friendly in a day")
	ns.db.days = 7
end

-- Friendly, to Honored with a 100 Favor goal (combined): the goal takes the cheap ore crates, so
-- receipts' Favor comes from the herb crates.
do
	WM.standing, WM.rep = 5, 3000
	WM.questsDone[98247] = true -- label done
	ns.db.targetStanding, ns.db.favorGoal = 6, 100
	WM.auctionator[248683], WM.auctionator[2770] = 2000, 50 -- Apprentice Ore crate; 20 Copper Ore = 1,000
	WM.history[248683] = { { rawDay = WM.today, minSeen = 2000, available = 10 } } -- 10 on sale
	bump()
	local plan = ns.Planner.Get("combined")
	eq(plan.needRep, 6000, "Friendly to Honored")
	eq(plan.goal, 100, "the Favor goal")
	local ore, herbs
	for _, f in ipairs(plan.fills) do
		if f.item == 248683 then ore = f elseif f.item == 248682 then herbs = f end
	end
	ok(ore and ore.units == 10, "all 10 ore crates filled first (cheapest Favor)")
	eq(plan.receipts, 99, "receipts for the rest: (6,000 - 1,050) / 50")
	ok(herbs and herbs.units == 10 + 99 * 3, "herb crates for the rest of the goal and every receipt's 15 Favor")
	eq(plan.containers[248682], 99, "receipts go on herb crates (the ore crates are used)")
	eq(plan.days, 7, "a week of writs")
	ok(step(plan, "receipts"), "a receipts step")
	-- The Rank plan ignores the goal: receipts then get the cheap ore crates' Favor.
	plan = ns.Planner.Get("rank")
	eq(plan.goal, 0, "no goal in the Rank plan")
	-- The Favor plan: crates only.
	plan = ns.Planner.Get("favor")
	eq(plan.needRep, 0, "no rep in the Favor plan")
	eq(#plan.writsToday, 0, "no writs")
	eq(plan.receipts, 0, "no receipts")
	-- Favor you hold covers the goal first.
	WM.favor = 100
	bump()
	plan = ns.Planner.Get("favor")
	eq(#plan.fills, 0, "nothing to fill")
	WM.favor = 0
end

-- Shopping: today's items, less what you hold; crafted ones broken down when you know the recipe.
do
	ns.db.targetStanding, ns.db.favorGoal = 5, 0
	WM.standing, WM.rep = 4, 2500
	bump()
	local plan = ns.Planner.Get("rank")
	local rows = {}
	for _, r in ipairs(plan.shopping) do rows[r.itemID] = r end
	ok(rows[264013] and rows[264013].buy == 1, "buy the writ")
	ok(rows[3385] and rows[3385].each == 3000, "and the potion")
	-- Knowing the recipe and it being cheaper: the herbs instead of the potion.
	WM.spells[3173] = true -- Lesser Mana Potion
	WM.auctionator[785], WM.auctionator[3820], WM.auctionator[3371] = 100, 200, 4 -- Mageroyal, Stranglekelp, Empty Vial
	bump()
	plan = ns.Planner.Get("rank")
	rows = {}
	for _, r in ipairs(plan.shopping) do rows[r.itemID] = r end
	ok(not rows[3385], "the potion is crafted")
	ok(rows[785] and rows[3820], "its herbs are bought")
	WM.spells[3173] = nil
end


-- The window ---------------------------------------------------------------------------------------

-- Each plan tab draws its progress, step box and route; opening one makes it the followed plan.
do
	WM.faction, WM.standing, WM.rep, WM.favor = "Alliance", 5, 3000, 0
	WM.questsDone = { [98247] = true }
	ns.db.targetStanding, ns.db.favorGoal, ns.db.favorGoalItem, ns.db.days = 6, 0, nil, 7
	bump()
	SlashCmdList.LEREP("")
	for _, kind in ipairs({ "rank", "favor", "combined" }) do
		ns.Window.Select(kind)
		WM.RunTimers()
		eq(ns.db.lastPlan, kind, kind .. " is followed")
		local panel = ns.Window.CurrentPanel()
		ok(panel.box, kind .. " has a step box")
	end
	ns.Window.Select("rank")
	WM.RunTimers()
	local panel = ns.Window.CurrentPanel()
	ok(panel.repBar.text.text:find("Friendly, 3,000 of 9,000 for Honored"), "rep progress: " .. tostring(panel.repBar.text.text))
	local plan = ns.Planner.Get("rank")
	ok(#plan.steps >= 2, "rank plan has steps")
	ok(panel.box.title.text == plan.steps[1].title, "the box shows the first step")
	ok(panel.totalText.text:find("Whole plan"), "totals line")
	-- The Favor tab without a goal asks for one.
	ns.Window.Select("favor")
	WM.RunTimers()
	ok(ns.Window.CurrentPanel().emptyText.text:find("Pick a Favor goal"), "favor tab asks for a goal")
	-- The goal menu lists your side's rewards: the Alliance sign, not the Horde one.
	local root = WM.MenuRoot()
	ns.Window.CurrentPanel().goalDrop.menuGenerator(nil, root)
	local names = {}
	for _, r in ipairs(root.radios) do names[#names + 1] = r.text end
	local all = table.concat(names, "|")
	ok(all:find("Pack Kodo mount %(6000%)"), "the kodo is a goal: " .. all)
	local signs = 0
	for _, n in ipairs(names) do if n:find("Tradeskill Sign") then signs = signs + 1 end end
	eq(signs, 1, "one side's sign")
	for _, r in ipairs(root.radios) do
		if r.text:find("Minimule") then r.setSelected() end
	end
	eq(ns.db.favorGoal, 1500, "Minimule goal picked")
	WM.RunTimers()
	ok(#ns.Planner.Get("favor").steps > 0, "the Favor plan fills crates now")
	ns.Choices.SetGoal(0)
end

-- How far your gold goes: the whole plan, or the rep (and Favor) it gets you to.
do
	ns.Window.Select("rank")
	local plan = ns.Planner.Get("rank")
	local full = ns.Planner.GoldReach(plan, 1e9)
	ok(full.all and full.short == 0, "a fortune covers it all")
	eq(full.rep, plan.value + plan.rep, "and reaches the plan's rep")
	local none = ns.Planner.GoldReach(plan, 0)
	ok(not none.all and none.short > 0, "no gold: short")
	ok(none.rep < full.rep, "no gold gets less rep")
	WM.money = 0
	bump()
	local text = ns.Window.CurrentPanel().totalText.text
	ok(text:find("Your 0 gets you to") and text:find("short of the rest"), "totals say how far gold goes: " .. text)
	WM.money = 1e9
	bump()
	ok(ns.Window.CurrentPanel().totalText.text:find("covers the whole plan"), "and when it covers it all")
	WM.money = 0
end

-- Shopping follows the last plan tab; Send to Auctionator makes the list.
do
	ns.Window.Select("rank")
	WM.RunTimers()
	ns.Window.Select("shopping")
	WM.RunTimers()
	local panel = ns.Window.CurrentPanel()
	ok(panel.heading.text:find("Rank plan"), "shopping names the plan: " .. tostring(panel.heading.text))
	ok(panel.totalText.text:find("To buy"), "shopping total")
	WM.lists = {}
	local n = ns.Shopping.SendToAuctionator()
	ok(n and n > 0 and WM.lists.leRep, "sent to Auctionator")
end

-- Options builds and its Defaults button works.
do
	ns.Window.Select("options")
	WM.RunTimers()
	ns.db.days = 30
	ns.ResetOptions()
	eq(ns.db.days, 7, "defaults put the day limit back")
end

-- Step alerts: the followed plan's first writ is done.
do
	ns.Window.Select("rank")
	WM.RunTimers()
	local plan = ns.Planner.Get("rank")
	local first = plan.steps[1]
	ok(first.kind == "writ", "first step is a writ: " .. tostring(first.kind))
	ns.Planner.WatchSteps()
	WM.printed = {}
	WM.questsDone[first.writ.writ.quest] = true
	bump()
	ok(printed("step done: " .. first.title:gsub("%p", "%%%0")), "step done announced")
	WM.questsDone[first.writ.writ.quest] = nil
end

-- The Rewards tab: rewards grouped by rank, your side's only; clicking one makes it the goal and
-- raises the target rank; a profession line opens its recipes.
do
	WM.faction, WM.standing, WM.rep, WM.favor = "Alliance", 5, 3000, 300
	ns.db.targetStanding = 6
	ns.Choices.SetGoal(0)
	bump()
	ns.Window.Select("rewards")
	WM.RunTimers()
	local panel = ns.Window.CurrentPanel()
	ok(panel.box, "rewards has a box")
	local entries = ns.RewardEntries()
	local heads, kodo, hordeTabard, receipt = {}, nil, nil, nil
	for _, e in ipairs(entries) do
		if e.kind == "head" then heads[#heads + 1] = e.text .. (e.status and (" " .. e.status) or "") end
		if e.item == 262766 then kodo = e end
		if e.item == 262764 then hordeTabard = e end
		if e.item == 262902 then receipt = e end
	end
	local h = table.concat(heads, "|")
	ok(h:find("^Friendly |cff1eff00unlocked"), "Friendly unlocked: " .. h)
	ok(h:find("Honored |cffff99336,000 rep to go"), "Honored to go: " .. h)
	ok(h:find("Exalted") and h:find("Any rank") and h:find("Recipes"), "all groups: " .. h)
	ok(kodo and receipt, "kodo and receipt listed")
	ok(not hordeTabard, "the Horde tabard isn't listed for the Alliance")
	-- Recipes are collapsed per profession; a click opens one.
	local lw
	for _, e in ipairs(entries) do if e.kind == "prof" and e.profession == "Leatherworking" then lw = e end end
	ok(lw and lw.count > 50 and not lw.open, "Leatherworking collapsed")
	ns.db.rewardsOpen.Leatherworking = true
	local open = 0
	for _, e in ipairs(ns.RewardEntries()) do if e.indent then open = open + 1 end end
	eq(open, lw.count, "its recipes listed when open")
	ns.db.rewardsOpen.Leatherworking = nil
	-- Picking the kodo: the goal, and Exalted.
	ns.PickReward(262766)
	WM.RunTimers()
	eq(ns.db.favorGoal, 6000, "kodo is the goal")
	eq(ns.db.favorGoalItem, 262766, "the goal's item")
	eq(ns.db.targetStanding, 8, "target raised to Exalted")
	ok(panel.box.lines[5].text:find("Your goal"), "the box says it's the goal")
	ok(panel.box.lines[4].text:find("Sold at"), "where it's sold: " .. tostring(panel.box.lines[4].text))
	-- A recipe can be the goal too, and shows in the goal dropdown.
	ns.PickReward(252765)
	WM.RunTimers()
	eq(ns.db.favorGoal, 30, "a recipe as the goal")
	local root = WM.MenuRoot()
	panel.goalDrop.menuGenerator(nil, root)
	local found = false
	for _, r in ipairs(root.radios) do if r.isSelected() then found = true end end
	ok(found, "the goal dropdown shows the recipe as picked")
	ns.Choices.SetGoal(0)
	ns.db.targetStanding = 6
	WM.favor = 0
end

-- Your own professions' recipes are open on the Rewards tab; recipes you know are marked and last;
-- "All" makes a profession's recipes you don't have yet the goal.
do
	local D = ns.data
	WM.skills = { Blacksmithing = 150 }
	WM.standing, WM.rep, WM.favor = 5, 3000, 0
	bump()
	local function Find(kind, prof)
		for _, e in ipairs(ns.RewardEntries()) do
			if e.kind == kind and e.profession == prof then return e end
		end
	end
	ok(Find("prof", "Blacksmithing").open, "Blacksmithing opens by itself for a Blacksmith")
	ok(not Find("prof", "Tailoring").open, "Tailoring stays shut")
	ns.db.rewardsOpen.Blacksmithing = false
	ok(not Find("prof", "Blacksmithing").open, "closing it is remembered")
	ns.db.rewardsOpen.Blacksmithing = nil
	-- Know one Blacksmithing recipe, hold the pattern of another.
	local bs = {}
	for item, r in pairs(D.rewards) do
		if r.profession == "Blacksmithing" then bs[#bs + 1] = item end
	end
	table.sort(bs)
	local all = ns.Choices.ProfessionRecipes("Blacksmithing")
	eq(#all.left, #bs, "none known yet")
	WM.spells[D.rewards[bs[1]].teaches] = true
	WM.items[bs[2]] = { name = "a pattern", count = 1 }
	bump()
	local t = ns.Choices.ProfessionRecipes("Blacksmithing")
	eq(#t.left, #bs - 2, "known and in-bags recipes drop out")
	eq(t.favor, all.favor - D.rewards[bs[1]].favor - D.rewards[bs[2]].favor, "and their Favor")
	local list, lastHave, firstHaveAt, lastNotAt = ns.RewardEntries(), false, nil, nil
	for i, e in ipairs(list) do
		if e.kind == "reward" and e.r.profession == "Blacksmithing" then
			if e.have then firstHaveAt = firstHaveAt or i else lastNotAt = i end
		end
	end
	ok(firstHaveAt and lastNotAt and firstHaveAt > lastNotAt, "recipes you have come last")
	-- All Blacksmithing as the goal.
	ns.Window.Select("rewards")
	WM.RunTimers()
	ns.PickReward("prof:Blacksmithing")
	WM.RunTimers()
	eq(ns.db.favorGoalProf, "Blacksmithing", "the profession is the goal")
	eq(ns.Choices.FavorGoal(), t.favor, "the goal is what's left")
	eq(ns.Planner.Get("favor").goal, t.favor, "the plans aim for it")
	local panel = ns.Window.CurrentPanel()
	ok(panel.box.lines[1].text == "All Blacksmithing recipes", "the box shows it: " .. tostring(panel.box.lines[1].text))
	ok(panel.box.lines[5].text:find("Your goal"), "as the goal")
	local root = WM.MenuRoot()
	panel.goalDrop.menuGenerator(nil, root)
	local shown
	for _, r in ipairs(root.radios) do if r.isSelected() then shown = r.text end end
	ok(shown and shown:find("All Blacksmithing recipes %(" .. #t.left .. " left"), "the dropdown shows it: " .. tostring(shown))
	-- Learning one more shrinks the goal.
	WM.Fire("NEW_RECIPE_LEARNED", D.rewards[bs[3]].teaches)
	WM.RunTimers()
	eq(ns.Choices.FavorGoal(), t.favor - D.rewards[bs[3]].favor, "learning one shrinks the goal")
	-- Typing an amount replaces it.
	ns.db.favorGoal, ns.db.favorGoalItem, ns.db.favorGoalProf = 500, nil, nil
	eq(ns.Choices.FavorGoal(), 500, "an amount instead")
	ns.Choices.SetGoal(0)
	WM.skills, WM.spells, WM.items[bs[2]] = {}, {}, nil
	ns.db.known = {}
	ns.db.targetStanding = 6
end

-- A writ whose Coin Pouch pays more than the writ and its item: a gain, in green, done first.
do
	WM.faction, WM.standing, WM.rep, WM.favor = "Alliance", 5, 3000, 0
	WM.questsDone = { [98247] = true }
	ns.db.targetStanding, ns.db.days = 6, 1
	local old1, old2 = WM.auctionator[264014], WM.auctionator[6048]
	WM.auctionator[264014], WM.auctionator[6048] = 1000, 500 -- 1,500 against a 3,500 pouch (the guess)
	bump()
	local plan = ns.Planner.Get("rank")
	local first = plan.writsToday[1]
	eq(first.id, 264014, "the paying writ comes first")
	eq(first.cost, 1000 + 500 - D.coinPouch.Journeyman, "its cost is below zero, not 0")
	ok(plan.pouches > 0, "the plan adds up its pouches")
	ns.Window.Select("rank")
	WM.RunTimers()
	local panel = ns.Window.CurrentPanel()
	local stepRow
	for _, r in ipairs(panel.rows) do
		if r.step and r.step.key == "writ264014" then stepRow = r end
	end
	ok(stepRow and stepRow.cols[3].text:find("^|cff1eff00%+"), "the route shows it in green: " .. tostring(stepRow and stepRow.cols[3].text))
	ok(panel.totalText.text:find("after Coin Pouches %("), "the totals say before and after pouches: " .. panel.totalText.text)
	ns.StepTooltip(UIParent, plan.steps[1].kind == "writ" and plan.steps[1] or stepRow.step)
	local tip = table.concat(GameTooltip.lines, "\n")
	ok(tip:find("After the Coin Pouch | |cff1eff00%+"), "the tooltip's sum ends in a gain: " .. tip)
	ok(tip:find("a guess until you've opened some"), "and says the pouch is a guess")
	eq(ns.CostText(0), "|cff9d9d9d-|r", "nothing is a grey dash")
	ok(not ns.CostText(2500):find("|c"), "a cost stays plain")
	WM.auctionator[264014], WM.auctionator[6048] = old1, old2
	ns.db.days = 7
	bump()
end

-- A plan over several days: receipts (and the crates for their Favor) come at the end, after the
-- forecast; the forecast says the writs a day and when each rank is reached; the route has
-- Today and Later headings. On a one-day plan receipts are a today step.
do
	WM.faction, WM.standing, WM.rep, WM.favor = "Alliance", 5, 3000, 0
	WM.questsDone = { [98247] = true }
	ns.db.targetStanding, ns.db.days = 6, 7
	ns.Choices.SetGoal(0)
	ns.db.favorGoal = 100
	WM.auctionator[264014], WM.auctionator[6048] = 10000, 20000
	bump()
	local plan = ns.Planner.Get("combined")
	local keys, at = {}, {}
	for i, s in ipairs(plan.steps) do keys[#keys + 1] = s.key .. ":" .. s.day at[s.key] = i end
	local k = table.concat(keys, " ")
	ok(at.receipts and at.later and at.receipts > at.later, "receipts after the forecast: " .. k)
	eq(plan.steps[at.receipts].day, "end", "receipts at the end")
	ok(plan.steps[at.receipts].title:find("^At the end, if still short"), "and say so")
	ok(at.fill248683 and plan.steps[at.fill248683].day == "today", "the goal's ore crates are today: " .. k)
	ok(at.endfill248682 and plan.steps[at.endfill248682].day == "end", "the receipts' herb crates are at the end: " .. k)
	eq(plan.steps[at.fill248682].title:match("Fill (%d+)"), "10", "only the goal's herb crates today")
	for _, r in ipairs(plan.shopping) do
		ok(r.itemID ~= 248682 or r.need == 10, "shopping buys only today's herb crates")
	end
	local later = plan.steps[at.later]
	eq(later.perDay.writs, 2, "two writs a day")
	eq(later.perDay.rep, 150, "150 rep a day")
	eq(#later.reach, 1, "one rank to reach")
	eq(later.reach[1].day, "end", "Honored at the end, with receipts")
	ns.StepTooltip(UIParent, later)
	local tip = table.concat(GameTooltip.lines, "\n")
	ok(tip:find("Writs a day | 2 %(%+150 rep%)") and tip:find("Honored | at the end"), "the forecast tooltip: " .. tip)
	ns.Window.Select("combined")
	WM.RunTimers()
	local heads = {}
	for _, r in ipairs(ns.Window.CurrentPanel().rows) do
		if r:IsShown() and not r.step then heads[#heads + 1] = r.name.text end
	end
	local h = table.concat(heads, "|")
	ok(h:find("Today") and h:find("Later"), "Today and Later headings: " .. h)
	-- One day: receipts are today, and no headings.
	ns.db.days = 1
	bump()
	plan = ns.Planner.Get("combined")
	local r
	for _, s in ipairs(plan.steps) do if s.key == "receipts" then r = s end end
	ok(r and r.day == "today", "one-day plan: receipts today")
	ns.db.days, ns.db.favorGoal = 7, 0
	bump()
end

-- /lerep status and help.
do
	WM.printed = {}
	SlashCmdList.LEREP("status")
	ok(printed("Azeroth Commerce Authority: Friendly"), "status names the faction")
	SlashCmdList.LEREP("help")
	ok(printed("/lerep status"), "help lists commands")
end

WM.done = true
