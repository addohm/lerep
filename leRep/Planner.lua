-- leRep: the plans. Each finds the cheapest gold path to its targets:
--   rank:     the target rank. Writs, the Shipping Label and receipts, cheapest gold per rep first,
--             plus the crates its receipts' Favor needs.
--   favor:    the Favor goal. Filled crates only, cheapest gold per Favor first.
--   combined: both at once.
-- Costs are what the items are worth at today's prices (what you hold counts at its price too), less
-- the Coin Pouches writs pay (plan.pouches: what they add up to); a writ whose pouch pays more than
-- it and its item costs less than nothing. The gold you'd actually spend, after what you hold and
-- before any pouch pays you back, is the shopping list's total.
--
-- Writs are once a day each. A plan finishes within ns.db.days days (0: no limit): it assumes the
-- writs on sale today are on sale each day at today's prices, and receipts cover the rest. A
-- receipt costs an empty crate plus its Favor at what Favor costs to earn from crates at that
-- point, so receipts get dearer as a Favor goal uses up the cheap crates.
local _, ns = ...

local Planner = {}
ns.Planner = Planner

Planner.KINDS = { "rank", "favor", "combined" }
Planner.NAMES = { rank = "Rank", favor = "Favor", combined = "Combined" }
local HUGE = 1e9

-- Crates on sale: how many and at what price. Fresh = Auctionator saw them recently.
local function Supply(item)
	local held = ns.BagCount(item)
	local price = ns.Prices.Buyout(item)
	local age = ns.Prices.Age(item)
	local listed = 0
	if price and (not age or age <= ns.db.writAgeDays) then
		local h = ns.Prices.History(item)
		listed = (h and h.listed and h.listed > 0) and h.listed or HUGE
	end
	return { item = item, held = held, listed = listed, price = price, left = held + listed }
end

-- What a unit of a crate is worth to the plan's choices: its price, or 0 for one you hold that has
-- no price.
local function UnitPrice(s)
	return s.price or 0
end

-- The cheapest bundle to fill a crate with: { itemID, count, cost } or nil.
local function BestBundle(crate, price)
	local best
	for _, b in ipairs(crate.bundles) do
		local each = price(b[1])
		if each then
			local cost = each * b[2]
			if not best or cost < best.cost then best = { item = b[1], count = b[2], cost = cost } end
		end
	end
	return best
end

-- Writs ------------------------------------------------------------------------------------------

-- Every writ a plan could use: { id, writ, cost (one hand-in), rep, today (can do it today),
-- later (on sale, so assumed on sale each later day) }, cheapest per rep first.
local function WritLines(price, missing)
	local lines = {}
	for id, w in pairs(ns.data.writs) do
		local held = ns.BagCount(id) > 0
		local buyout = ns.Prices.Buyout(id)
		local age = ns.Prices.Age(id)
		local onSale = buyout and (not age or age <= ns.db.writAgeDays) and true or false
		local today = (held or onSale) and not ns.Faction.WritDoneToday(w)
		if today or onSale then
			local each, how = price(w.item)
			if each then
				-- Below zero when the Coin Pouch pays more than the writ and its item: a gain, done first.
				local pouch = ns.Faction.PouchValue(w.tier)
				local cost = (buyout or 0) + each * w.count - pouch
				lines[#lines + 1] = { id = id, writ = w, cost = cost, pouch = pouch, rep = ns.Faction.Rep(w.rep),
					today = today, later = onSale, held = held, writPrice = buyout, itemPrice = each, itemHow = how }
			else
				missing[w.item] = true
			end
		end
	end
	table.sort(lines, function(a, b)
		local ra, rb = a.cost / a.rep, b.cost / b.rep
		if ra ~= rb then return ra < rb end
		return a.id < b.id
	end)
	return lines
end

-- Favor from crates ------------------------------------------------------------------------------

-- The crate supply and the ways to fill crates for Favor, cheapest per Favor first.
local function Crates(price, missing)
	local supply, fills = {}, {}
	for id, crate in pairs(ns.data.crates) do
		local s = Supply(id)
		supply[id] = s
		if s.left > 0 then
			local bundle = BestBundle(crate, price)
			if bundle then
				local favor = ns.Faction.CrateFavor(crate)
				local unit = UnitPrice(s) + bundle.cost
				fills[#fills + 1] = { item = id, crate = crate, bundle = bundle, unit = unit, favor = favor, rate = unit / favor, units = 0 }
			else
				for _, b in ipairs(crate.bundles) do missing[b[1]] = true end
			end
		end
	end
	table.sort(fills, function(a, b)
		if a.rate ~= b.rate then return a.rate < b.rate end
		return a.item < b.item
	end)
	return supply, fills
end

-- Working one plan out ---------------------------------------------------------------------------

local function Work(kind)
	local db, data = ns.db, ns.data
	local plan = { kind = kind, steps = {}, missing = {}, rep = 0, favor = 0, cost = 0, pouches = 0 }
	local camp = ns.Faction.Camp()
	plan.camp = camp
	if not camp then
		plan.problem = "This character has no trade faction."
		return plan
	end
	local price = ns.Make.New()
	plan.price = price
	local wantRep = kind ~= "favor"
	local wantFavor = kind ~= "rank"
	local standing, value = ns.Faction.Standing()
	value = value or 0
	plan.standing, plan.value = standing, value
	plan.needRep = wantRep and ns.Faction.RepToGo(db.targetStanding) or 0
	plan.goal = wantFavor and ns.Choices.FavorGoal() or 0
	plan.held = ns.Faction.Favor()
	plan.receiptFavor = ns.Faction.ReceiptFavor()

	local supply, fills = Crates(price, plan.missing)
	local bank = plan.held -- Favor you have or will have earned, not yet spent
	local cursor = 1

	local function NextFill()
		while fills[cursor] and supply[fills[cursor].item].left <= 0 do cursor = cursor + 1 end
		return fills[cursor]
	end
	-- Spend Favor: from the bank, then by filling crates (whole crates; extra Favor stays in the
	-- bank). False if the crates run out.
	local purpose = "goal" -- what Favor is being earned for: the goal, or receipts (step 3)
	local function SpendFavor(amount)
		while bank < amount do
			local f = NextFill()
			if not f then return false end
			local need = math.ceil((amount - bank) / f.favor)
			local take = math.min(need, supply[f.item].left)
			supply[f.item].left = supply[f.item].left - take
			f.units = f.units + take
			if purpose == "receipts" then f.forReceipts = (f.forReceipts or 0) + take end
			bank = bank + take * f.favor
			plan.cost = plan.cost + take * f.unit
		end
		bank = bank - amount
		return true
	end
	-- What Favor costs to earn at this point, per Favor.
	local function FavorRate()
		local f = NextFill()
		return f and f.rate
	end

	-- 1. The Favor goal comes first: receipts then use what's left.
	if plan.goal > 0 and not SpendFavor(plan.goal) then
		plan.shortFavor = plan.goal
	end

	-- 2. The Shipping Label: 2,000 rep (and 50 Favor) for the price of filling one crate.
	local repLeft = plan.needRep
	if repLeft > 0 and not ns.Faction.LabelDone() then
		local holding = ns.BagCount(camp.labelItem) > 0
		local first
		if not holding then
			first = NextFill()
			if first then
				supply[first.item].left = supply[first.item].left - 1
				first.units = first.units + 1
				bank = bank + first.favor
				plan.cost = plan.cost + first.unit
			end
		end
		if holding or first then
			local rep = ns.Faction.Rep(data.labelRep)
			plan.label = { rep = rep, favor = data.labelFavor, fill = first }
			bank = bank + data.labelFavor
			repLeft = repLeft - rep
			plan.rep = plan.rep + rep
		end
	end

	purpose = "receipts"
	-- 3. Rep: writs and receipts, cheapest per rep first. Receipts need Friendly, so until then only
	-- writs count.
	local lines = WritLines(price, plan.missing)
	local days = db.days or 7
	local laterCopies = days == 0 and HUGE or math.max(days - 1, 0)
	local friendly = ns.Faction.THRESHOLDS[data.receipt.standing]
	local gained = plan.rep
	local li = 1
	local taken = {} -- line -> { today = 0/1, later = n }
	local receipts, containers = 0, {}
	local RF = plan.receiptFavor
	local receiptRep = ns.Faction.Rep(data.receipt.rep)

	local function NextWrit()
		while lines[li] do
			local l, t = lines[li], taken[lines[li]]
			if l.today and not (t and t.today) then return l, "today" end
			if l.later and (not t or t.later < laterCopies) then return l, "later" end
			li = li + 1
		end
	end
	local function CheapestContainer()
		local best
		for id, s in pairs(supply) do
			if s.left > 0 and (not best or UnitPrice(s) < UnitPrice(best)) then best = s end
		end
		return best
	end

	local guard = 0
	while repLeft > 0 and guard < 20000 do
		guard = guard + 1
		local writ, when = NextWrit()
		local writRate = writ and writ.cost / writ.rep
		local receiptRate, container
		if value + gained >= friendly then
			container = CheapestContainer()
			local fr = FavorRate()
			if container and (fr or bank >= RF) then
				receiptRate = (UnitPrice(container) + RF * (fr or 0)) / receiptRep
			end
		end
		if writ and (not receiptRate or writRate <= receiptRate) then
			local t = taken[writ] or { today = 0, later = 0 }
			taken[writ] = t
			if when == "today" then t.today = 1 else t.later = t.later + 1 end
			repLeft, gained = repLeft - writ.rep, gained + writ.rep
			plan.cost = plan.cost + writ.cost
			plan.pouches = plan.pouches + writ.pouch
		elseif receiptRate then
			if not SpendFavor(RF) then break end
			container.left = container.left - 1
			containers[container.item] = (containers[container.item] or 0) + 1
			receipts = receipts + 1
			repLeft, gained = repLeft - receiptRep, gained + receiptRep
			plan.cost = plan.cost + UnitPrice(container)
		else
			break
		end
	end
	plan.rep = gained
	if repLeft > 0 then plan.shortRep = repLeft end
	plan.receipts, plan.containers = receipts, containers
	plan.favor = plan.goal + receipts * RF
	plan.bank = bank

	-- Days: one of each writ a day.
	local maxLater = 0
	plan.writsToday, plan.writsLater = {}, {}
	for _, l in ipairs(lines) do
		local t = taken[l]
		if t then
			if t.today > 0 then table.insert(plan.writsToday, l) end
			if t.later > 0 then
				table.insert(plan.writsLater, { line = l, copies = t.later })
				maxLater = math.max(maxLater, t.later)
			end
		end
	end
	plan.days = (#plan.writsToday > 0 or receipts > 0 or plan.label) and 1 + maxLater or maxLater
	plan.fills = {}
	for _, f in ipairs(fills) do
		if f.units > 0 then table.insert(plan.fills, f) end
	end
	return plan
end

-- Steps ------------------------------------------------------------------------------------------

local function Where(npc, camp)
	if not npc then return camp.place end
	local text = npc.name .. ", " .. camp.place
	if npc.x and npc.y then text = text .. (" at %.1f, %.1f"):format(npc.x * 100, npc.y * 100) end
	return text
end
Planner.Where = Where

-- The plan as steps, in the order to do them. Each: { key, kind, title, detail, where, rep, favor,
-- cost, uses = { { itemID, count } }, day ("today", "later") }.
local function Steps(plan)
	local steps, camp, data = {}, plan.camp, ns.data
	local function Add(s) steps[#steps + 1] = s return s end

	for item in pairs(data.sealedWrits) do
		local n = ns.BagCount(item)
		if n > 0 then
			Add({ key = "open" .. item, kind = "open", icon = item, day = "today",
				title = ("Open %d %s"):format(n, ns.ItemName(item)),
				detail = "The writ inside joins the plan." })
		end
	end
	if ns.BagCount(data.genericCrate) > 0 then
		Add({ key = "read", kind = "read", icon = data.genericCrate, day = "today",
			title = ("Read the label on %d %s"):format(ns.BagCount(data.genericCrate), ns.ItemName(data.genericCrate)),
			detail = "It tells you which goods the crate takes; then the plan can use it." })
	end

	local function FillStep(f, units, key, why)
		local uses = { { f.item, units }, { f.bundle.item, f.bundle.count * units } }
		return Add({ key = key, kind = "fill", icon = f.item, day = "today", item = f.item,
			title = ("Fill %d %s"):format(units, ns.ItemName(f.item)),
			detail = ("Each with %d %s. %s"):format(f.bundle.count, ns.ItemName(f.bundle.item), why or ""),
			where = Where(camp.intake, camp), favor = math.floor(f.favor * units + 0.5), cost = f.unit * units, uses = uses })
	end

	local labelFill = plan.label and plan.label.fill
	if plan.label then
		if labelFill then FillStep(labelFill, 1, "labelfill", "Your first filled crate brings the Shipping Label.") end
		Add({ key = "label", kind = "label", icon = camp.labelItem, day = "today",
			title = "Hand in the Shipping Label", detail = "Once per character.",
			where = Where(camp.intake, camp), rep = plan.label.rep, favor = plan.label.favor, cost = 0, uses = {} })
	end

	for _, l in ipairs(plan.writsToday) do
		local uses = { { l.writ.item, l.writ.count } }
		if not l.held then table.insert(uses, 1, { l.id, 1 }) end
		local cust = l.writ.customer
		Add({ key = "writ" .. l.id, kind = "writ", icon = l.id, day = "today", item = l.id, writ = l,
			title = ns.ItemName(l.id),
			detail = ("Deliver %s%s."):format(l.writ.count > 1 and (l.writ.count .. " ") or "", ns.ItemName(l.writ.item)),
			where = cust and (cust.name .. (cust.x and (" at %.1f, %.1f"):format(cust.x * 100, cust.y * 100) or "")) or "the customer marked on your map",
			rep = l.rep, cost = l.cost, uses = uses })
	end

	-- On a plan over several days, receipts and the crates filled for their Favor come at the end,
	-- after the forecast: they cover only what writs leave, and the plan is worked out again daily.
	local defer = plan.receipts > 0 and #plan.writsLater > 0
	for _, f in ipairs(plan.fills) do
		local units = f.units - ((labelFill == f) and 1 or 0)
		local later = defer and math.min(units, f.forReceipts or 0) or 0
		if units - later > 0 then FillStep(f, units - later, "fill" .. f.item) end
	end

	local function ReceiptStep(day)
		local uses, cost = {}, 0
		for item, n in pairs(plan.containers) do
			table.insert(uses, { item, n })
			cost = cost + (ns.Prices.Buyout(item) or 0) * n
		end
		table.sort(uses, function(a, b) return a[2] > b[2] end)
		local container = uses[1] and ns.ItemName(uses[1][1]) or "Waylaid Crate"
		Add({ key = "receipts", kind = "receipt", icon = data.receipt.item, day = day,
			title = (day == "end" and "At the end, if still short: return %d crates with receipts"
				or "Return %d empty crates with Forged Delivery Receipts"):format(plan.receipts),
			detail = ("Buy %d receipts (%d Favor each) from %s; put one on each empty crate (%s%s) and hand it in at %s.%s"):format(
				plan.receipts, plan.receiptFavor, camp.scribe.name, container, #uses > 1 and " and others" or "", camp.intake.name,
				day == "end" and " The plan is worked out again each day, so by then writs may have covered more." or ""),
			where = Where(camp.scribe, camp), rep = ns.Faction.Rep(data.receipt.rep) * plan.receipts,
			favor = -plan.receipts * plan.receiptFavor, cost = cost, uses = uses })
	end
	if plan.receipts > 0 and not defer then ReceiptStep("today") end

	if #plan.writsLater > 0 then
		local rep, cost, n = 0, 0, 0
		for _, x in ipairs(plan.writsLater) do
			rep, cost, n = rep + x.line.rep * x.copies, cost + x.line.cost * x.copies, n + x.copies
		end
		-- The forecast, day by day: day 1 is today's steps; on day d each writ with at least d - 1
		-- later copies is done once more. Note the day each rank up to the target is reached.
		local T, target = ns.Faction.THRESHOLDS, ns.db.targetStanding or 8
		local total = plan.value or 0
		for _, s in ipairs(steps) do total = total + (s.rep or 0) end
		local reach = {}
		local function Check(day)
			for st = 5, target do
				if not reach[st] and (plan.value or 0) < T[st] and total >= T[st] then reach[st] = day end
			end
		end
		Check(1)
		local perDay = { writs = 0, rep = 0 }
		for d = 2, plan.days do
			local add, count = 0, 0
			for _, x in ipairs(plan.writsLater) do
				if x.copies >= d - 1 then add, count = add + x.line.rep, count + 1 end
			end
			if d == 2 then perDay.writs, perDay.rep = count, add end
			total = total + add
			Check(d)
		end
		if defer then
			total = total + ns.Faction.Rep(data.receipt.rep) * plan.receipts
			Check("end")
		end
		local ranks = {}
		for st = 5, target do
			if reach[st] then ranks[#ranks + 1] = { standing = st, day = reach[st] } end
		end
		Add({ key = "later", kind = "later", icon = plan.writsLater[1].line.id, day = "later",
			title = ("Days 2 to %d: %d more writs"):format(plan.days, n),
			detail = "The same writs each day, if they're on sale at today's prices (an estimate).",
			rep = rep, cost = cost, uses = {}, perDay = perDay, reach = ranks })
	end

	if defer then
		for _, f in ipairs(plan.fills) do
			local units = f.units - ((labelFill == f) and 1 or 0)
			local later = math.min(units, f.forReceipts or 0)
			if later > 0 then
				local s = FillStep(f, later, "endfill" .. f.item, "For the receipts' Favor.")
				s.day = "end"
				s.title = "At the end: " .. s.title
			end
		end
		ReceiptStep("end")
	end
	return steps
end

-- Shopping ----------------------------------------------------------------------------------------

-- What to buy for a plan's steps for today: every item they use, crafted ones broken down into
-- their materials, less what you hold (counted once). Rows: { itemID, need, have, buy, each, cost,
-- how ("vendor", "auction", or nil if no price) }, dearest first; and the total gold.
function Planner.Shopping(plan)
	local need, order = {}, {}
	local function Need(item, count, depth)
		local _, how, option = plan.price(item)
		if how == "craft" and option and depth < 3 then
			local crafts = math.ceil(count / math.max(option.rec.yield or 1, 1))
			for _, r in ipairs(option.rec.reagents) do Need(r[1], r[2] * crafts, depth + 1) end
			return
		end
		if not need[item] then order[#order + 1] = item end
		need[item] = (need[item] or 0) + count
	end
	for _, s in ipairs(plan.steps or {}) do
		if s.day == "today" then
			for _, u in ipairs(s.uses or {}) do Need(u[1], u[2], 0) end
		end
	end
	local rows, total = {}, 0
	for _, item in ipairs(order) do
		local have = ns.ItemCount(item)
		local buy = math.max(0, need[item] - have)
		local each, how = ns.Prices.Buy(item)
		local cost = each and buy * each
		total = total + (cost or 0)
		rows[#rows + 1] = { itemID = item, need = need[item], have = have, buy = buy, each = each, cost = cost, how = how }
	end
	table.sort(rows, function(a, b)
		if (a.cost or 0) ~= (b.cost or 0) then return (a.cost or 0) > (b.cost or 0) end
		return a.itemID < b.itemID
	end)
	return rows, total
end

-- How far your gold goes: the steps in order, each costing what you'd still have to buy (what you
-- hold is used up as the steps go), until the gold runs out part-way through a step. Returns
-- { all (covers the whole plan), rep (where your rep gets to), favor (Favor you'd have), short
-- (gold missing for the rest) }.
function Planner.GoldReach(plan, money)
	local held, gold = {}, money
	local rep, favor = plan.value or 0, plan.held or 0
	local total = 0
	for _, s in ipairs(plan.steps or {}) do
		local spend = 0
		if s.day == "later" then
			spend = s.cost or 0
		else
			for _, u in ipairs(s.uses or {}) do
				local have = held[u[1]] or ns.ItemCount(u[1])
				local use = math.min(have, u[2])
				held[u[1]] = have - use
				spend = spend + (u[2] - use) * (plan.price(u[1]) or 0)
			end
		end
		total = total + spend
		local share = 1
		if spend > gold then share = spend > 0 and gold / spend or 1 end
		rep = rep + (s.rep or 0) * share
		favor = favor + (s.favor or 0) * share
		gold = math.max(0, gold - spend)
	end
	return { all = total <= money, rep = math.floor(rep), favor = math.floor(favor), short = math.max(0, total - money) }
end

-- Plans are worked out again only when something changed (ns.version).
local cache = {}
function Planner.Get(kind)
	local c = cache[kind]
	if c and c.version == ns.version then return c.plan end
	local plan = Work(kind)
	if plan.camp then
		plan.steps = Steps(plan)
		plan.shopping, plan.spend = Planner.Shopping(plan)
	end
	cache[kind] = { version = ns.version, plan = plan }
	return plan
end

-- The plan Shopping and the step alerts follow: the plan tab opened last.
function Planner.Followed()
	return Planner.Get(ns.db.lastPlan or "combined")
end

-- Step alerts: when the followed plan's first step is a writ or the Shipping Label and it's now
-- done, say so and name the next step. (Other steps can leave the plan because prices changed, so
-- they aren't announced.)
local lastFirst
function Planner.WatchSteps()
	local plan = Planner.Followed()
	local first = plan.steps and plan.steps[1]
	local last = lastFirst
	lastFirst = first and { key = first.key, kind = first.kind, title = first.title, writ = first.writ }
	if not (ns.db.stepAlerts and last) or (first and first.key == last.key) then return end
	local done = (last.kind == "writ" and last.writ and ns.Faction.WritDoneToday(last.writ.writ))
		or (last.kind == "label" and ns.Faction.LabelDone())
	if done then
		ns.Print(("step done: %s.%s"):format(last.title, first and (" Next: " .. first.title .. ".") or " That's the plan done."))
		local play, kit = rawget(_G, "PlaySound"), rawget(_G, "SOUNDKIT")
		if play and kit and kit.UI_QUEST_COMPLETE then pcall(play, kit.UI_QUEST_COMPLETE) end
	end
end
