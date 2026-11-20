-- leRep: the Rank, Favor and Combined tabs. Each shows its targets in a top bar, your progress, the
-- current step (what to buy or craft, and where to hand it in), and the route: every step with
-- what it gives and costs. Click a step in the route to see it in the step box; hover it for its
-- detail. Opening one of these tabs makes it the plan Shopping and the step alerts follow.
local _, ns = ...

local GREY, ORANGE, GREEN, GOLD = "|cff9d9d9d", "|cffff9933", "|cff1eff00", "|cffffd100"
local ROW_H, ITEM_H, STEP_H = 20, 16, 132
local COL_W = 74 -- Rep, Favor, Cost

local function Dropdown(parent, width, generator)
	local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	d:SetWidth(width)
	d:SetupMenu(generator)
	return d
end

local function RankMenu(_, root)
	for _, c in ipairs(ns.Choices.RANKS) do
		root:CreateRadio("To " .. c[2], function() return ns.db.targetStanding == c[1] end,
			function() ns.db.targetStanding = c[1] ns.Changed() end)
	end
end

local function GoalMenu(_, root)
	for _, c in ipairs(ns.Choices.Goals()) do
		root:CreateRadio(c[2], function() return ns.Choices.GoalKey() == c[1] end,
			function() ns.Choices.SetGoal(c[1]) end)
	end
end

local function DaysMenu(_, root)
	for _, c in ipairs(ns.Choices.DAYS) do
		root:CreateRadio(c[1] == 0 and "No day limit" or ("Within " .. c[2]), function() return ns.db.days == c[1] end,
			function() ns.db.days = c[1] ns.Changed() end)
	end
end

local function Bar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(14)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.5)
	bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.text:SetPoint("LEFT", 6, 0)
	bar.text:SetPoint("RIGHT", -6, 0)
	bar.text:SetJustifyH("LEFT")
	return bar
end

local function Number(n)
	n = math.floor(n + 0.5)
	local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (n < 0 and "-" or "") .. s
end
ns.Number = Number

-- A step's tooltip lines: its detail, where, what it gives and costs, and what it uses.
local function StepTooltip(owner, s)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(s.title)
	if s.detail and s.detail ~= "" then GameTooltip:AddLine(s.detail, 1, 1, 1, true) end
	if s.where then GameTooltip:AddLine("Where: " .. s.where, 0.8, 0.8, 0.8, true) end
	if s.rep and s.rep ~= 0 then GameTooltip:AddDoubleLine("Rep", "+" .. Number(s.rep), 1, 0.82, 0, 1, 1, 1) end
	if s.favor and s.favor ~= 0 then
		GameTooltip:AddDoubleLine("Merchant's Favor", (s.favor > 0 and "+" or "") .. Number(s.favor), 1, 0.82, 0, 1, 1, 1)
	end
	if s.cost then GameTooltip:AddDoubleLine("Cost", ns.Money(s.cost), 1, 0.82, 0, 1, 1, 1) end
	if s.writ then
		local l = s.writ
		GameTooltip:AddDoubleLine("  The writ", l.held and "in your bags" or ns.Money(l.writPrice), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("  " .. ns.ItemName(l.writ.item), ns.Money(l.itemPrice * l.writ.count) .. (l.itemHow == "craft" and " (craft it)" or ""), 0.8, 0.8, 0.8, 1, 1, 1)
		local pouch = ns.Faction.PouchValue(l.writ.tier)
		if pouch > 0 then GameTooltip:AddDoubleLine("  Coin Pouch", "-" .. ns.Money(pouch), 0.8, 0.8, 0.8, 1, 1, 1) end
		GameTooltip:AddDoubleLine("  Per rep", ns.Money(l.cost / l.rep), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	GameTooltip:Show()
end
ns.StepTooltip = StepTooltip

local function MakePage(kind)
	local page = { id = kind, label = ns.Planner.NAMES[kind] }
	local panel, rankDrop, goalDrop, daysDrop, repBar, favorBar
	local box, routeScroll, routeInner, totalText, emptyText
	local rows, itemRows = {}, {}
	local selected -- the step key shown in the box

	local function ItemRow(i)
		if itemRows[i] then return itemRows[i] end
		local r = CreateFrame("Button", nil, box)
		r:SetHeight(ITEM_H)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.name:SetPoint("LEFT", 44, 0)
		r.name:SetPoint("RIGHT", r, "RIGHT", -(3 * COL_W + 4), 0)
		r.name:SetJustifyH("LEFT")
		r.name:SetWordWrap(false)
		r.cols = {}
		for c = 1, 3 do
			local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetWidth(COL_W - 4)
			fs:SetJustifyH("RIGHT")
			fs:SetPoint("RIGHT", r, "RIGHT", -((3 - c) * COL_W + 4), 0)
			r.cols[c] = fs
		end
		r:SetScript("OnEnter", function(self)
			if not self.itemID then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", GameTooltip_Hide)
		r:SetScript("OnClick", function(self) ns.ItemModifiedClick(self.itemID) end)
		itemRows[i] = r
		return r
	end

	local function RouteRow(i)
		if rows[i] then return rows[i] end
		local r = CreateFrame("Button", nil, routeInner)
		r:SetHeight(ROW_H)
		r.highlight = r:CreateTexture(nil, "BACKGROUND")
		r.highlight:SetAllPoints()
		r.highlight:SetColorTexture(1, 0.82, 0, 0.12)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(16, 16)
		r.icon:SetPoint("LEFT", 4, 0)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.name:SetPoint("LEFT", 26, 0)
		r.name:SetPoint("RIGHT", r, "RIGHT", -(3 * COL_W + 4), 0)
		r.name:SetJustifyH("LEFT")
		r.name:SetWordWrap(false)
		r.cols = {}
		for c = 1, 3 do
			local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetWidth(COL_W - 4)
			fs:SetJustifyH("RIGHT")
			fs:SetPoint("RIGHT", r, "RIGHT", -((3 - c) * COL_W + 4), 0)
			r.cols[c] = fs
		end
		r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
		r:SetScript("OnEnter", function(self) if self.step then StepTooltip(self, self.step) end end)
		r:SetScript("OnLeave", GameTooltip_Hide)
		r:SetScript("OnClick", function(self)
			if self.step and not ns.ItemModifiedClick(self.step.item) then
				selected = self.step.key
				ns.Window.Refresh()
			end
		end)
		rows[i] = r
		return r
	end

	local function Build(p)
		panel = p
		rankDrop = Dropdown(panel, 130, RankMenu)
		rankDrop:SetPoint("TOPLEFT", 0, 0)
		goalDrop = Dropdown(panel, 200, GoalMenu)
		daysDrop = Dropdown(panel, 130, DaysMenu)
		if kind == "favor" then
			rankDrop:Hide()
			daysDrop:Hide()
			goalDrop:SetPoint("TOPLEFT", 0, 0)
		elseif kind == "rank" then
			goalDrop:Hide()
			daysDrop:SetPoint("LEFT", rankDrop, "RIGHT", 8, 0)
		else
			goalDrop:SetPoint("LEFT", rankDrop, "RIGHT", 8, 0)
			daysDrop:SetPoint("LEFT", goalDrop, "RIGHT", 8, 0)
		end
		panel.rankDrop, panel.goalDrop, panel.daysDrop = rankDrop, goalDrop, daysDrop

		repBar = Bar(panel)
		repBar:SetPoint("TOPLEFT", 0, -34)
		repBar:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
		repBar:SetStatusBarColor(0.2, 0.6, 1)
		favorBar = Bar(panel)
		favorBar:SetPoint("TOPLEFT", 0, kind == "favor" and -34 or -52)
		favorBar:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
		favorBar:SetStatusBarColor(1, 0.7, 0.1)
		repBar:SetShown(kind ~= "favor")
		favorBar:SetShown(kind ~= "rank")
		panel.repBar, panel.favorBar = repBar, favorBar

		-- The step box.
		local top = kind == "combined" and -74 or -56
		box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 0, top)
		box:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
		box:SetHeight(STEP_H)
		box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		box:SetBackdropColor(0.1, 0.1, 0.14, 0.9)
		box:SetBackdropBorderColor(0.6, 0.45, 0.15, 0.8)
		box.icon = box:CreateTexture(nil, "ARTWORK")
		box.icon:SetSize(32, 32)
		box.icon:SetPoint("TOPLEFT", 8, -8)
		box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		box.title:SetPoint("TOPLEFT", 48, -8)
		box.title:SetPoint("RIGHT", box, "RIGHT", -8, 0)
		box.title:SetJustifyH("LEFT")
		box.title:SetWordWrap(false)
		box.gives = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		box.gives:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -3)
		box.gives:SetPoint("RIGHT", box, "RIGHT", -8, 0)
		box.gives:SetJustifyH("LEFT")
		box.where = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		box.where:SetPoint("TOPLEFT", box.gives, "BOTTOMLEFT", 0, -3)
		box.where:SetPoint("RIGHT", box, "RIGHT", -8, 0)
		box.where:SetJustifyH("LEFT")
		box.where:SetWordWrap(false)
		box.header = ItemRow(0)
		box.header:EnableMouse(false)
		box.header:SetPoint("TOPLEFT", 0, -58)
		box.header:SetPoint("RIGHT", box, "RIGHT", -6, 0)
		box.header.name:SetFontObject("GameFontNormalSmall")
		box.header.name:SetText("Uses")
		for c, text in ipairs({ "Have", "Buy", "Cost" }) do
			box.header.cols[c]:SetFontObject("GameFontNormalSmall")
			box.header.cols[c]:SetText(text)
		end
		panel.box = box

		-- The route.
		local head = RouteRow(0)
		head:SetParent(panel)
		head:EnableMouse(false)
		head.highlight:Hide()
		head:SetPoint("TOPLEFT", 0, top - STEP_H - 6)
		head:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
		head.name:SetFontObject("GameFontNormal")
		head.name:SetText("Route")
		for c, text in ipairs({ "Rep", "Favor", "Cost" }) do
			head.cols[c]:SetFontObject("GameFontNormalSmall")
			head.cols[c]:SetText(text)
		end
		routeScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
		routeScroll:SetPoint("TOPLEFT", 0, top - STEP_H - 6 - ROW_H)
		routeScroll:SetPoint("BOTTOMRIGHT", -24, 52)
		routeInner = CreateFrame("Frame", nil, routeScroll)
		routeInner:SetSize(500, 1)
		routeScroll:SetScrollChild(routeInner)
		routeScroll:SetScript("OnSizeChanged", function(_, width) routeInner:SetWidth(width) end)
		rows[0] = nil -- the heading isn't a route row

		local rule = panel:CreateTexture(nil, "BORDER")
		rule:SetPoint("BOTTOMLEFT", 0, 48)
		rule:SetPoint("BOTTOMRIGHT", 0, 48)
		rule:SetHeight(1)
		rule:SetColorTexture(0.6, 0.45, 0.15, 0.6)
		totalText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		totalText:SetPoint("BOTTOMLEFT", 4, 4)
		totalText:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
		totalText:SetHeight(42)
		totalText:SetJustifyH("LEFT")
		totalText:SetJustifyV("MIDDLE")
		panel.totalText = totalText

		emptyText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		emptyText:SetPoint("TOPLEFT", 12, -12)
		emptyText:SetPoint("RIGHT", box, "RIGHT", -12, 0)
		emptyText:SetJustifyH("LEFT")
		panel.emptyText = emptyText
	end

	local function ShowStep(s)
		local on = s ~= nil
		emptyText:SetShown(not on)
		for _, f in ipairs({ box.icon, box.title, box.gives, box.where, box.header }) do f:SetShown(on) end
		if not on then
			for _, r in pairs(itemRows) do r:Hide() end
			return
		end
		box.icon:SetTexture(ns.ItemIcon(s.icon))
		box.title:SetText(s.title)
		local gives = {}
		if s.rep and s.rep ~= 0 then gives[#gives + 1] = GREEN .. "+" .. Number(s.rep) .. " rep|r" end
		if s.favor and s.favor ~= 0 then
			gives[#gives + 1] = (s.favor > 0 and (GREEN .. "+") or (ORANGE)) .. Number(s.favor) .. " Favor|r"
		end
		if s.cost and s.cost > 0 then gives[#gives + 1] = "costs " .. ns.Money(s.cost) end
		box.gives:SetText(table.concat(gives, GREY .. "  ·  |r") .. ((s.detail and s.detail ~= "") and ("  " .. GREY .. s.detail .. "|r") or ""))
		box.where:SetText(s.where and (GOLD .. "Where:|r " .. s.where) or "")
		local uses = s.uses or {}
		box.header:SetShown(#uses > 0)
		for i, u in ipairs(uses) do
			if i > 4 then break end
			local r = ItemRow(i)
			r.itemID = u[1]
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -58 - i * ITEM_H)
			r:SetPoint("RIGHT", box, "RIGHT", -6, 0)
			local have = ns.ItemCount(u[1])
			local buy = math.max(0, u[2] - have)
			local each = ns.Planner.Get(kind).price(u[1])
			r.name:SetText(u[2] .. " x " .. ns.ItemNameColored(u[1]))
			r.cols[1]:SetText(have > 0 and have or (GREY .. "0|r"))
			r.cols[2]:SetText(buy > 0 and buy or (GREY .. "-|r"))
			r.cols[3]:SetText(each and ns.Money(each * u[2]) or (ORANGE .. "?|r"))
			r:Show()
		end
		for i = math.min(#uses, 4) + 1, #itemRows do itemRows[i]:Hide() end
	end

	local function Refresh()
		local plan = ns.Planner.Get(kind)
		rankDrop:GenerateMenu()
		goalDrop:GenerateMenu()
		daysDrop:GenerateMenu()

		if plan.problem then
			repBar:Hide()
			favorBar:Hide()
			ShowStep(nil)
			emptyText:SetText(plan.problem)
			for _, r in pairs(rows) do r:Hide() end
			totalText:SetText("")
			return
		end

		-- Progress.
		local T = ns.Faction.THRESHOLDS
		if kind ~= "favor" then
			local goal = T[ns.db.targetStanding] or 42000
			repBar:SetMinMaxValues(0, math.max(goal, 1))
			repBar:SetValue(math.max(0, math.min(plan.value, goal)))
			repBar.text:SetText(("Rep: %s, %s of %s for %s%s"):format(ns.Faction.StandingName(plan.standing), Number(plan.value),
				Number(goal), ns.Faction.StandingName(ns.db.targetStanding),
				plan.needRep > 0 and (" (" .. Number(plan.needRep) .. " to go)") or GREEN .. " (there)|r"))
		end
		if kind ~= "rank" then
			local want = plan.goal + plan.receipts * plan.receiptFavor
			favorBar:SetMinMaxValues(0, math.max(want, 1))
			favorBar:SetValue(math.min(plan.held, want))
			local parts = {}
			if plan.goal > 0 then parts[#parts + 1] = Number(plan.goal) .. " goal" end
			if plan.receipts > 0 then parts[#parts + 1] = Number(plan.receipts * plan.receiptFavor) .. " for receipts" end
			favorBar.text:SetText(("Merchant's Favor: %s held%s"):format(Number(plan.held),
				#parts > 0 and (", needs " .. Number(want) .. " (" .. table.concat(parts, ", ") .. ")") or ", no goal"))
		end

		-- The step box: the step picked in the route, else the first.
		local steps = plan.steps or {}
		local shown
		for _, s in ipairs(steps) do
			if s.key == selected then shown = s end
		end
		shown = shown or steps[1]
		selected = shown and shown.key
		ShowStep(shown)
		if not shown then
			if kind == "favor" and plan.goal == 0 then
				emptyText:SetText("Pick a Favor goal above: a reward, or an amount in Options.")
			elseif plan.shortRep or plan.shortFavor then
				emptyText:SetText(ORANGE .. "Nothing can be planned yet.|r Scan the auction house with Auctionator, so leRep has writ and crate prices.")
			else
				emptyText:SetText(GREEN .. "You're there.|r Nothing left to do for this plan.")
			end
		end

		-- The route.
		local y = 0
		for i, s in ipairs(steps) do
			local r = RouteRow(i)
			r.step = s
			r.icon:SetTexture(ns.ItemIcon(s.icon))
			r.name:SetText((s.day == "later" and GREY or "") .. s.title .. (s.day == "later" and "|r" or ""))
			r.cols[1]:SetText((s.rep and s.rep ~= 0) and Number(s.rep) or (GREY .. "-|r"))
			r.cols[2]:SetText((s.favor and s.favor ~= 0) and ((s.favor < 0 and ORANGE or "") .. Number(s.favor)) or (GREY .. "-|r"))
			r.cols[3]:SetText(s.cost and s.cost > 0 and ns.Money(s.cost) or (GREY .. "-|r"))
			r.highlight:SetShown(s.key == selected)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", routeInner, "TOPLEFT", 0, -y)
			r:SetPoint("RIGHT", routeInner, "RIGHT")
			r:Show()
			y = y + ROW_H
		end
		for i = #steps + 1, #rows do rows[i]:Hide() end
		routeInner:SetHeight(math.max(1, y))

		-- Totals and warnings.
		local lines = {}
		local total = ("Whole plan: %s"):format(ns.Money(plan.cost))
		if plan.days and plan.days > 1 then total = total .. (" over %d days"):format(plan.days) end
		total = total .. ("  ·  To buy today: %s"):format(ns.Money(plan.spend or 0))
		lines[1] = total
		-- How far your gold goes.
		if #steps > 0 then
			local money = ns.Try(GetMoney) or 0
			local reach = ns.Planner.GoldReach(plan, money)
			if reach.all then
				lines[#lines + 1] = ("Your %s covers the whole plan."):format(ns.Money(money))
			else
				local parts = {}
				if kind ~= "favor" then
					local standing = 4
					for s = 5, 8 do if reach.rep >= T[s] then standing = s end end
					parts[#parts + 1] = ("%s rep (%s)"):format(Number(reach.rep), ns.Faction.StandingName(standing))
				end
				if kind ~= "rank" then parts[#parts + 1] = Number(reach.favor) .. " Favor" end
				lines[#lines + 1] = ("Your %s gets you to %s; %s short of the rest."):format(ns.Money(money),
					table.concat(parts, " and "), ns.Money(reach.short))
			end
		end
		local warn = {}
		if plan.shortRep then warn[#warn + 1] = ("%s rep short: not enough writs on sale in that time%s"):format(Number(plan.shortRep),
			(plan.value + plan.rep < ns.Faction.THRESHOLDS[5]) and ", and receipts need Friendly" or ", and no crates for receipts") end
		if plan.shortFavor then warn[#warn + 1] = "not enough crates on sale for the Favor goal" end
		local missing = 0
		for _ in pairs(plan.missing) do missing = missing + 1 end
		if missing > 0 then warn[#warn + 1] = ("%d item%s with no price (scan the auction house)"):format(missing, missing == 1 and "" or "s") end
		if #warn > 0 then lines[#lines + 1] = ORANGE .. table.concat(warn, "; ") .. "|r" end
		totalText:SetText(table.concat(lines, "\n"))
	end

	page.build, page.refresh = Build, Refresh
	page.onSelect = function()
		ns.db.lastPlan = kind
		ns.watching = true
	end
	page.panelRows = function() return rows end
	return page
end

-- Shared with the Rewards tab, which looks like these.
ns.PlanUI = { Dropdown = Dropdown, RankMenu = RankMenu, GoalMenu = GoalMenu, Bar = Bar }

for _, kind in ipairs(ns.Planner.KINDS) do
	ns.Window.AddPage(MakePage(kind))
end
