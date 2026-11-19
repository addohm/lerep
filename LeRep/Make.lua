-- LeRep: what one of an item costs you (from leprofit's make-vs-buy): the cheaper of buying it (a
-- vendor's price, else the auction house's) and crafting it with a recipe this character knows,
-- whose materials are priced the same way, three levels deep.
local _, ns = ...

local Make = {}
ns.Make = Make

local MAX_DEPTH = 3

-- product itemID -> the recipes in LeRep's data that make it
local makers
local function Makers(itemID)
	if not makers then
		makers = {}
		for id, r in pairs(ns.data.recipes) do
			makers[r.product] = makers[r.product] or {}
			table.insert(makers[r.product], { id = id, rec = r })
		end
	end
	return makers[itemID]
end

local Price

-- The cheapest way to make one with a recipe you know: { id, rec, cost } or nil.
local function CraftOption(itemID, depth, memo)
	if depth >= MAX_DEPTH then return nil end
	local best
	for _, m in ipairs(Makers(itemID) or {}) do
		if ns.Recorder.Knows(m.id) then
			local cost = 0
			for _, r in ipairs(m.rec.reagents) do
				local p = r[1] ~= itemID and Price(r[1], depth + 1, memo)
				if not p then cost = nil break end
				cost = cost + p * r[2]
			end
			if cost then
				local each = cost / math.max(m.rec.yield or 1, 1)
				if not best or each < best.cost or (each == best.cost and m.rec.name < best.rec.name) then
					best = { id = m.id, rec = m.rec, cost = each }
				end
			end
		end
	end
	return best
end

-- One's price, and how: "vendor", "auction" or "craft" (with the craft option).
function Price(itemID, depth, memo)
	local key = itemID .. ":" .. depth
	local m = memo[key]
	if m then return m[1], m[2], m[3] end
	local price, how = ns.Prices.Buy(itemID)
	local craft = CraftOption(itemID, depth, memo)
	local option
	if craft and (not price or craft.cost < price) then
		price, how, option = craft.cost, "craft", craft
	end
	memo[key] = { price, how, option }
	return price, how, option
end

-- A price list for one plan: prices are looked up once and kept.
function Make.New()
	local memo = {}
	return function(itemID) return Price(itemID, 0, memo) end
end
