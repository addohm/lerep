-- LeRep's scenarios, run by run_tests.py against the fake client (WM). Each block sets the game up,
-- does something, and checks what LeRep made of it.
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

-- Turn-in values: the data's guesses until LeRep has seen the real ones.
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

WM.done = true
