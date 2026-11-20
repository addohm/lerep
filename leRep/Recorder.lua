-- leRep: what the game shows you. The recipes you know (profession windows), vendor prices and the
-- receipt's price (vendors), and what each turn-in really gave: rep for writs (your rep bonus),
-- Favor for filled crates, and what Coin Pouches hold. These replace the data's guesses.
local _, ns = ...
local Try = ns.Try

local Recorder = {}
ns.Recorder = Recorder

-- Recipes you know -------------------------------------------------------------------------------

-- Every recipe in leRep's data that this character knows: the profession window's list, or the
-- game's own spell check.
function Recorder.Knows(recipeID)
	if ns.db.known[recipeID] then return true end
	return Try(IsPlayerSpell, recipeID) and true or false
end

-- The recipes leRep cares about: those in its data, and those the Favor patterns teach.
local wanted
local function Wanted(id)
	if not wanted then
		wanted = {}
		for rid in pairs(ns.data.recipes) do wanted[rid] = true end
		for _, r in pairs(ns.data.rewards) do
			if r.teaches then wanted[r.teaches] = true end
		end
	end
	return wanted[id]
end

function Recorder.ReadProfession()
	local api = C_TradeSkillUI
	local ids = api and Try(api.GetAllRecipeIDs)
	if not ids then return end
	local changed = false
	for _, id in ipairs(ids) do
		if Wanted(id) then
			local info = Try(api.GetRecipeInfo, id)
			local learned = info and info.learned and true or nil
			if ns.db.known[id] ~= learned then
				ns.db.known[id] = learned
				changed = true
			end
		end
	end
	if changed then ns.Changed() end
end

-- Vendors ----------------------------------------------------------------------------------------

local function MerchantItem(i)
	local itemID = Try(GetMerchantItemID, i)
	local name, price, stack, available, extended
	local info = C_MerchantFrame and Try(C_MerchantFrame.GetItemInfo, i)
	if info then
		name, price, stack, available, extended = info.name, info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
	elseif GetMerchantItemInfo then
		local n, _, p, q, a, _, _, e = Try(GetMerchantItemInfo, i)
		name, price, stack, available, extended = n, p, q, a, e
	end
	return itemID, ns.Plain(name), price, stack, available, extended
end

-- The Favor a vendor charges for item slot i, or nil.
local function FavorCost(i)
	for j = 1, (Try(GetMerchantItemCostInfo, i) or 0) do
		local _, amount, link, currencyName = Try(GetMerchantItemCostItem, i, j)
		local currency = ns.Plain(link) and tonumber(link:match("currency:(%d+)"))
		if currency == ns.data.favorCurrency or ns.Plain(currencyName) == "Merchant's Favor" then
			return amount
		end
	end
	return nil
end

-- Materials the plans may buy: anything in a recipe, a crate bundle or a writ.
local materials
local function IsMaterial(itemID)
	if not materials then
		materials = {}
		for _, r in pairs(ns.data.recipes) do
			for _, m in ipairs(r.reagents) do materials[m[1]] = true end
		end
		for _, c in pairs(ns.data.crates) do
			for _, b in ipairs(c.bundles) do materials[b[1]] = true end
		end
		for _, w in pairs(ns.data.writs) do materials[w.item] = true end
	end
	return materials[itemID]
end

function Recorder.ScanMerchant()
	if not ns.db then return end
	local changed, prices = false, 0
	for i = 1, (Try(GetMerchantNumItems) or 0) do
		local itemID, name, price, stack, available, extended = MerchantItem(i)
		if itemID == ns.data.receipt.item then
			local favor = FavorCost(i)
			if favor and ns.adb.seen.receiptFavor ~= favor then
				ns.adb.seen.receiptFavor = favor
				changed = true
				ns.Print(("recorded the Forged Delivery Receipt's price: %d Merchant's Favor."):format(favor))
			end
		elseif itemID and price and price > 0 and not extended and (not available or available < 0) and IsMaterial(itemID) then
			-- A material in endless supply; the price is for the stack the vendor sells.
			local each = price / math.max(stack or 1, 1)
			if ns.adb.vendorPrices[itemID] ~= each then
				ns.adb.vendorPrices[itemID] = each
				if name then ns.adb.itemNames[itemID] = name end
				changed, prices = true, prices + 1
			end
		end
	end
	if prices > 0 then
		local vendor = ns.Plain(Try(UnitName, "npc"))
		ns.Print(("recorded %d material price%s from %s."):format(prices, prices == 1 and "" or "s", vendor or "this vendor"))
	end
	if changed then ns.Changed() end
end

-- Turn-ins ---------------------------------------------------------------------------------------

-- The reward window shows before you hand in: note your rep and Favor then, and compare a moment
-- after the hand-in.
local before
local function Snapshot()
	local _, value = ns.Faction.Standing()
	before = { rep = value, favor = ns.Faction.Favor() }
end

local writByQuest
local function WritFor(questID)
	if not writByQuest then
		writByQuest = {}
		for _, w in pairs(ns.data.writs) do writByQuest[w.quest] = w end
	end
	return writByQuest[questID]
end

function Recorder.TurnedIn(questID)
	local was = before
	before = nil
	if not was then return end
	C_Timer.After(1, function()
		local _, value = ns.Faction.Standing()
		local rep = value and was.rep and value - was.rep
		local favor = ns.Faction.Favor() - (was.favor or 0)
		local writ = WritFor(questID)
		local crate = ns.data.sealedCrates[questID]
		if writ and rep and rep > 0 then
			-- Rep above the writ's base is your rep bonus (the Diplomat perk), to the nearest 2%.
			local bonus = math.floor((rep / writ.rep - 1) * 50 + 0.5) * 2
			if bonus >= 0 and bonus <= 10 and bonus ~= ns.db.repBonus then
				ns.db.repBonus = bonus
				ns.Print(("you get %d%% more rep per turn-in; leRep plans with that now."):format(bonus))
			end
		elseif crate and favor > 0 then
			-- A Performance Bonus can double it: keep the least seen.
			local key = crate.tier .. (crate.green and "Green" or "")
			local seen = ns.adb.seen.crateFavor
			if not seen[key] or favor < seen[key] then
				seen[key] = favor
				ns.Print(("recorded: a filled %s%s crate pays %d Favor."):format(crate.tier, crate.green and " (crafted goods)" or "", favor))
			end
		end
		ns.Changed()
	end)
end

-- Coin Pouches: when one leaves your bags and your money goes up within a few seconds (either can
-- come first), that's what it held.
local pouchCounts, money, opened, gained
local function CountPouches()
	local t = {}
	for _, id in pairs(ns.Faction.POUCHES) do t[id] = ns.BagCount(id) end
	return t
end

local function RecordPouch(id, copper)
	local seen = ns.adb.seen.pouch
	seen[id] = seen[id] or { total = 0, n = 0 }
	seen[id].total, seen[id].n = seen[id].total + copper, seen[id].n + 1
	opened, gained = nil, nil
	ns.Changed()
end

function Recorder.CheckPouches()
	local now, cash, t = CountPouches(), Try(GetMoney) or 0, GetTime()
	if pouchCounts then
		for id, n in pairs(now) do
			if pouchCounts[id] and n == pouchCounts[id] - 1 then opened = { id = id, at = t } end
		end
	end
	if money and cash > money then gained = { copper = cash - money, at = t } end
	if opened and gained and math.abs(opened.at - gained.at) < 3 then RecordPouch(opened.id, gained.copper) end
	pouchCounts, money = now, cash
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED", "MERCHANT_SHOW",
	"MERCHANT_UPDATE", "QUEST_COMPLETE", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "PLAYER_LOGIN" }) do
	pcall(events.RegisterEvent, events, e)
end
local pending = false
events:SetScript("OnEvent", function(_, event, arg)
	if not ns.db then return end
	if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		Recorder.ScanMerchant()
	elseif event == "QUEST_COMPLETE" then
		Snapshot()
	elseif event == "QUEST_TURNED_IN" then
		Recorder.TurnedIn(arg)
	elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_MONEY" or event == "PLAYER_LOGIN" then
		Recorder.CheckPouches()
	elseif event == "NEW_RECIPE_LEARNED" and type(arg) == "number" and Wanted(arg) then
		ns.db.known[arg] = true
		ns.Changed()
	elseif not pending then
		-- Profession events come several at a time: read once, half a second after the last.
		pending = true
		C_Timer.After(0.5, function()
			pending = false
			Recorder.ReadProfession()
		end)
	end
end)
