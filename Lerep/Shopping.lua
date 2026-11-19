-- Lerep: Send to Auctionator (from leprofit). Makes one "Lerep" shopping list from what's left to buy
-- for today's steps of the plan you followed last, leaving out what vendors sell.
local ADDON, ns = ...

local Shopping = {}
ns.Shopping = Shopping

Shopping.LIST_NAME = "Lerep"

local function AuctionatorAPI()
	local A = rawget(_G, "Auctionator")
	local api = type(A) == "table" and type(A.API) == "table" and A.API.v1
	if type(api) == "table" and api.CreateShoppingList then return api end
	return nil
end

function Shopping.CanSend()
	return AuctionatorAPI() ~= nil
end

-- One search term in Auctionator's format: the exact name and how many. Older Auctionator versions
-- differ in what ConvertToSearchString takes, so a plain exact-name search is the fallback.
local function SearchString(api, name, quantity)
	if api.ConvertToSearchString then
		local s = ns.Try(api.ConvertToSearchString, ADDON, { searchString = name, isExact = true, quantity = quantity })
		if type(s) == "string" and s ~= "" then return s end
	end
	return '"' .. name .. '"'
end

-- Returns how many items went in, or nil.
function Shopping.SendToAuctionator()
	local api = AuctionatorAPI()
	if not api then
		ns.Print("Auctionator isn't installed, or is too old to take shopping lists.")
		return nil
	end
	local plan = ns.Planner.Followed()
	local terms, vendor, unnamed = {}, {}, 0
	for _, m in ipairs(plan.shopping or {}) do
		if m.buy > 0 then
			local name = ns.ItemName(m.itemID)
			if name:match("^item %d+$") then
				unnamed = unnamed + 1
			elseif m.how == "vendor" then
				vendor[#vendor + 1] = name
			else
				terms[#terms + 1] = SearchString(api, name, m.buy)
			end
		end
	end
	if #terms == 0 then
		if #vendor > 0 then
			ns.Print("nothing to buy at the auction house. From a vendor: " .. table.concat(vendor, ", ") .. ".")
		elseif unnamed > 0 then
			ns.Print("the game hasn't loaded those items' names yet; try again in a moment.")
		else
			ns.Print("nothing to buy: you hold everything on the list.")
		end
		return 0
	end
	local ok, err = pcall(api.CreateShoppingList, ADDON, Shopping.LIST_NAME, terms)
	if not ok then
		ns.Print("Auctionator didn't take the list: " .. tostring(err))
		return nil
	end
	ns.Print(("sent %d item%s to Auctionator's |cffffffff%s|r shopping list. At the auction house, open Auctionator's Shopping tab and pick that list.")
		:format(#terms, #terms == 1 and "" or "s", Shopping.LIST_NAME))
	if #vendor > 0 then print("  Left out because a vendor sells them: " .. table.concat(vendor, ", ") .. ".") end
	if unnamed > 0 then
		print(("  %d item%s left out because the game hasn't loaded %s name yet; send again in a moment.")
			:format(unnamed, unnamed == 1 and "" or "s", unnamed == 1 and "its" or "their"))
	end
	return #terms
end

-- Choices shared by the plan tabs' top bar and Options ---------------------------------------------

ns.Choices = {}

ns.Choices.RANKS = { { 5, "Friendly" }, { 6, "Honored" }, { 7, "Revered" }, { 8, "Exalted" } }
ns.Choices.DAYS = { { 1, "1 day" }, { 3, "3 days" }, { 7, "7 days" }, { 14, "14 days" }, { 30, "30 days" }, { 0, "No limit" } }

-- The Favor goals: none, each reward in the data (cheapest first), or the amount typed in Options.
function ns.Choices.Goals()
	local list = { { 0, "No Favor goal" } }
	local rewards = {}
	local side = ns.Faction.Side()
	for item, g in pairs(ns.data.goals) do
		-- Each side's own tabard and sign only.
		if not g[5] or g[5] == side then rewards[#rewards + 1] = { item = item, favor = g[1], what = g[4] } end
	end
	table.sort(rewards, function(a, b)
		if a.favor ~= b.favor then return a.favor < b.favor end
		return a.item < b.item
	end)
	for _, r in ipairs(rewards) do
		list[#list + 1] = { "item:" .. r.item, ("%s (%d)"):format(r.what:gsub(" %(.*%)", ""), r.favor) }
	end
	if ns.db.favorGoal > 0 and not ns.db.favorGoalItem then
		list[#list + 1] = { "amount", ("%d Favor"):format(ns.db.favorGoal) }
	end
	return list
end

-- The current Favor goal as a choice key.
function ns.Choices.GoalKey()
	if ns.db.favorGoal == 0 then return 0 end
	if ns.db.favorGoalItem then return "item:" .. ns.db.favorGoalItem end
	return "amount"
end

function ns.Choices.SetGoal(key)
	if key == 0 then
		ns.db.favorGoal, ns.db.favorGoalItem = 0, nil
	elseif type(key) == "string" and key:find("^item:") then
		local item = tonumber(key:match("%d+"))
		ns.db.favorGoal, ns.db.favorGoalItem = ns.data.goals[item][1], item
	end
	ns.Changed()
end
