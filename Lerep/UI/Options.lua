-- Lerep: the Options tab, built from leprofit's widgets: the targets, the day limit, your Legacy perks'
-- bonuses, prices, and what Lerep has recorded so far.
local _, ns = ...

local GREY = "|cff9d9d9d"
local stack

local function Changed()
	ns.Changed()
end

local function Build(panel)
	local UI = ns.UI
	stack = UI.Stack(panel)
	stack:Add(UI.OptionHeading(panel, "Targets"))
	stack:Add(UI.OptionSelect(panel, "Rank to reach", ns.Choices.RANKS,
		function() return ns.db.targetStanding end,
		function(v) ns.db.targetStanding = v Changed() end,
		{ tooltip = { "Rank to reach", "The Rank and Combined plans' target." } }))
	stack:Add(UI.OptionSelect(panel, "Favor goal", ns.Choices.Goals,
		ns.Choices.GoalKey, ns.Choices.SetGoal,
		{ boxWidth = 210, tooltip = { "Favor goal", "Merchant's Favor for a reward, for the Favor and Combined plans. Type any amount below instead." } }))
	stack:Add(UI.OptionEdit(panel, "Or an amount of Favor",
		function() local g = ns.Choices.FavorGoal() return g > 0 and tostring(g) or "" end,
		function(text)
			local n = tonumber(text)
			if n and n >= 0 then
				ns.db.favorGoal, ns.db.favorGoalItem, ns.db.favorGoalProf = math.floor(n), nil, nil
				Changed()
			end
		end,
		{ "Or an amount of Favor", "Type a number and press Enter. 0 clears the goal." }))
	stack:Add(UI.OptionSelect(panel, "Finish within", ns.Choices.DAYS,
		function() return ns.db.days end,
		function(v) ns.db.days = v Changed() end,
		{ tooltip = { "Finish within", "Writs can each be done once a day. The plans use writs over this many days, assuming today's writs are on sale each day at today's prices, and receipts for what writs can't cover in that time. No limit: writs only, unless receipts are cheaper." } }))

	stack:Add(UI.OptionHeading(panel, "Legacy perks"))
	stack:Add(UI.OptionSelect(panel, "More rep per turn-in (Diplomat)",
		{ { 0, "0%" }, { 2, "2%" }, { 4, "4%" }, { 6, "6%" }, { 8, "8%" }, { 10, "10%" } },
		function() return ns.db.repBonus end,
		function(v) ns.db.repBonus = v Changed() end,
		{ tooltip = { "Diplomat", "2% more rep per rank. Lerep sets this itself when it sees how much rep a writ gives you." } }))
	stack:Add(UI.OptionSelect(panel, "Chance of double Favor (Performance Bonus)",
		{ { 0, "0%" }, { 3, "3%" }, { 6, "6%" }, { 9, "9%" }, { 12, "12%" }, { 15, "15%" } },
		function() return ns.db.favorBonus end,
		function(v) ns.db.favorBonus = v Changed() end,
		{ tooltip = { "Performance Bonus", "The chance a filled crate pays double Favor. The plans count the average." } }))

	stack:Add(UI.OptionHeading(panel, "Prices"))
	stack:Add(UI.OptionSelect(panel, "On sale if Auctionator saw it within",
		{ { 0, "today" }, { 1, "1 day" }, { 2, "2 days" }, { 3, "3 days" }, { 7, "7 days" } },
		function() return ns.db.writAgeDays end,
		function(v) ns.db.writAgeDays = v Changed() end,
		{ tooltip = { "On sale", "A writ or crate counts as on sale if your last scan that saw it is this recent." } }))
	stack:Add(UI.OptionCheck(panel, "Take the Coin Pouch off a writ's cost",
		function() return ns.db.usePouch end,
		function(v) ns.db.usePouch = v Changed() end,
		{ "Coin Pouch", "Each writ pays a Coin Pouch. Until you've opened some, Lerep uses a guess at what they hold." }))

	stack:Add(UI.OptionHeading(panel, "Other"))
	stack:Add(UI.OptionCheck(panel, "Say in chat when a step is done",
		function() return ns.db.stepAlerts end,
		function(v) ns.db.stepAlerts = v end,
		{ "Step alerts", "For the plan tab you opened last." }))
	stack:Add(UI.OptionCheck(panel, "Minimap button",
		function() return not ns.db.minimap.hide end,
		function(v) ns.Minimap.SetShown(v) end))

	stack:Add(UI.OptionHeading(panel, "What Lerep has seen"))
	stack:Add(UI.OptionText(panel, function()
		local seen, lines = ns.adb.seen, {}
		local rf, rfSeen = ns.Faction.ReceiptFavor()
		lines[#lines + 1] = ("Forged Delivery Receipt: %d Favor%s"):format(rf, rfSeen and "" or (GREY .. " (from guides; visit the scribe to check)|r"))
		local crates = {}
		for _, tier in ipairs({ "Apprentice", "Journeyman", "Expert", "Artisan" }) do
			for _, green in ipairs({ false, true }) do
				local v = seen.crateFavor[tier .. (green and "Green" or "")]
				if v then crates[#crates + 1] = ("%s%s %d"):format(tier, green and " (crafted)" or "", v) end
			end
		end
		lines[#lines + 1] = "Favor per filled crate: " .. (#crates > 0 and table.concat(crates, ", ") or (GREY .. "none handed in yet; using the published numbers|r"))
		local pouches = {}
		for tier, id in pairs(ns.Faction.POUCHES) do
			local p = seen.pouch[id]
			if p and p.n > 0 then pouches[#pouches + 1] = ("%s %s (%d opened)"):format(tier, ns.MoneyPlain(p.total / p.n), p.n) end
		end
		lines[#lines + 1] = "Coin Pouches: " .. (#pouches > 0 and table.concat(pouches, ", ") or (GREY .. "none opened yet; using guesses|r"))
		return table.concat(lines, "\n")
	end, 64))
end

ns.Window.AddPage({
	id = "options", label = "Options", build = Build,
	refresh = function() if stack then stack:Sync() end end,
	defaults = function()
		ns.ResetOptions()
		ns.Changed()
	end,
})
