-- leRep: the Rewards tab. What Merchant's Favor buys, grouped by the rank each reward needs, then the
-- ones any rank can buy, then the recipes: one line per profession, open for this character's
-- professions (a click opens or closes one), with the recipes you know marked and last. It looks
-- like the Combined tab: the rank and goal dropdowns, your rep and Favor, a box for the picked
-- reward, the list below. Clicking a reward makes it your Favor goal; a profession line's "All"
-- makes every recipe of it you don't have yet the goal. Either raises the target rank when needed.
local _, ns = ...

local GREY, ORANGE, GREEN, GOLD = "|cff9d9d9d", "|cffff9933", "|cff1eff00", "|cffffd100"
local ROW_H, BOX_H, COL_W = 20, 104, 74
local RANKS = { 5, 6, 7, 8 }

local panel, rankDrop, goalDrop, repBar, favorBar, box, scroll, inner
local rows = {}
local selected

local function Number(n) return ns.Number(n) end

local function Standing()
	local standing, value = ns.Faction.Standing()
	return standing or 0, value or 0
end

-- "Unlocked", or how much rep is still needed for a standing.
local function RankStatus(standing)
	if standing == 0 then return GREEN .. "any rank|r" end
	local mine = Standing()
	if mine >= standing then return GREEN .. "unlocked|r" end
	return ORANGE .. Number(ns.Faction.RepToGo(standing)) .. " rep to go|r"
end

local function RankText(r)
	if r.standing == 0 then return GREY .. "-|r" end
	return ns.Faction.StandingName(r.standing) .. (r.guide and (GREY .. " ?|r") or "")
end

-- The list's entries, in order: headings, rewards, profession lines and their open recipes.
local function Entries()
	local list, byRank, anyRank, recipes = {}, {}, {}, {}
	for item, r in pairs(ns.data.rewards) do
		if ns.Choices.ForMySide(r) then
			local e = { kind = "reward", item = item, r = r }
			if r.profession then
				recipes[r.profession] = recipes[r.profession] or {}
				table.insert(recipes[r.profession], e)
			elseif r.standing > 0 then
				byRank[r.standing] = byRank[r.standing] or {}
				table.insert(byRank[r.standing], e)
			else
				table.insert(anyRank, e)
			end
		end
	end
	local function ByFavor(a, b)
		if a.r.favor ~= b.r.favor then return a.r.favor < b.r.favor end
		return a.item < b.item
	end
	for _, standing in ipairs(RANKS) do
		if byRank[standing] then
			table.sort(byRank[standing], ByFavor)
			list[#list + 1] = { kind = "head", text = ns.Faction.StandingName(standing), status = RankStatus(standing) }
			for _, e in ipairs(byRank[standing]) do list[#list + 1] = e end
		end
	end
	if #anyRank > 0 then
		table.sort(anyRank, ByFavor)
		list[#list + 1] = { kind = "head", text = "Any rank" }
		for _, e in ipairs(anyRank) do list[#list + 1] = e end
	end
	local profs = {}
	for prof in pairs(recipes) do profs[#profs + 1] = prof end
	table.sort(profs)
	if #profs > 0 then list[#list + 1] = { kind = "head", text = "Recipes" } end
	ns.db.rewardsOpen = ns.db.rewardsOpen or {}
	for _, prof in ipairs(profs) do
		local open = ns.db.rewardsOpen[prof]
		if open == nil then open = ns.Skill(prof) ~= nil end
		local t = ns.Choices.ProfessionRecipes(prof)
		list[#list + 1] = { kind = "prof", profession = prof, count = t.all, left = #t.left, favor = t.favor, open = open }
		if open then
			for _, e in ipairs(recipes[prof]) do e.have = ns.Choices.Have(e.item) end
			table.sort(recipes[prof], function(a, b)
				if a.have ~= b.have then return not a.have end
				return ByFavor(a, b)
			end)
			for _, e in ipairs(recipes[prof]) do
				e.indent = true
				list[#list + 1] = e
			end
		end
	end
	return list
end
ns.RewardEntries = Entries -- (tests)

-- Makes a reward, or a profession's recipes ("prof:<name>"), the Favor goal.
local function Pick(item)
	if type(item) == "string" then
		selected = item
		ns.Choices.SetGoal(item)
		return
	end
	if not ns.data.rewards[item] then return end
	selected = item
	ns.Choices.SetGoal("item:" .. item)
end
ns.PickReward = Pick -- (tests)

local function Row(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Button", nil, inner)
	r:SetHeight(ROW_H)
	r.mark = r:CreateTexture(nil, "BACKGROUND")
	r.mark:SetAllPoints()
	r.mark:SetColorTexture(1, 0.82, 0, 0.12)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(16, 16)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
	-- A profession line's "All": every recipe of it you don't have yet becomes the goal.
	r.all = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
	r.all:SetSize(COL_W - 14, ROW_H - 2)
	r.all:SetPoint("RIGHT", -4, 0)
	r.all:SetText("All")
	r.all:SetScript("OnClick", function(self)
		local e = self:GetParent().entry
		if e and e.kind == "prof" then Pick("prof:" .. e.profession) end
	end)
	r.all:SetScript("OnEnter", function(self)
		local e = self:GetParent().entry
		if not e then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("All " .. e.profession .. " recipes")
		GameTooltip:AddLine(("Make the %d you don't have yet your Favor goal (%s Favor). Each drops out once you learn it or its pattern is in your bags."):format(e.left, Number(e.favor)), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	r.all:SetScript("OnLeave", GameTooltip_Hide)
	r.all:Hide()
	r:SetScript("OnEnter", function(self)
		local e = self.entry
		if not (e and e.kind == "reward") then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(e.item)
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine("Merchant's Favor", Number(e.r.favor) .. (e.r.copper > 0 and (" + " .. ns.Money(e.r.copper)) or ""), 1, 0.82, 0, 1, 1, 1)
		if e.r.standing > 0 then
			GameTooltip:AddDoubleLine("Needs", ns.Faction.StandingName(e.r.standing), 1, 0.82, 0, 1, 1, 1)
			if e.r.guide then GameTooltip:AddLine("That rank is from guides: the game checks it on its side, so it isn't in the game's data.", 0.7, 0.7, 0.7, true) end
		end
		GameTooltip:AddLine("Click to make it your Favor goal.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", GameTooltip_Hide)
	r:SetScript("OnClick", function(self)
		local e = self.entry
		if not e then return end
		if e.kind == "prof" then
			ns.db.rewardsOpen[e.profession] = not e.open
			ns.Window.Refresh()
		elseif e.kind == "reward" and not ns.ItemModifiedClick(e.item) then
			Pick(e.item)
		end
	end)
	rows[i] = r
	return r
end

local function Build(p)
	panel = p
	local W = ns.PlanUI
	rankDrop = W.Dropdown(panel, 130, W.RankMenu)
	rankDrop:SetPoint("TOPLEFT", 0, 0)
	goalDrop = W.Dropdown(panel, 200, W.GoalMenu)
	goalDrop:SetPoint("LEFT", rankDrop, "RIGHT", 8, 0)
	panel.rankDrop, panel.goalDrop = rankDrop, goalDrop

	repBar = W.Bar(panel)
	repBar:SetPoint("TOPLEFT", 0, -34)
	repBar:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	repBar:SetStatusBarColor(0.2, 0.6, 1)
	favorBar = W.Bar(panel)
	favorBar:SetPoint("TOPLEFT", 0, -52)
	favorBar:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	favorBar:SetStatusBarColor(1, 0.7, 0.1)
	panel.repBar, panel.favorBar = repBar, favorBar

	box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 0, -74)
	box:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	box:SetHeight(BOX_H)
	box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	box:SetBackdropColor(0.1, 0.1, 0.14, 0.9)
	box:SetBackdropBorderColor(0.6, 0.45, 0.15, 0.8)
	box.icon = box:CreateTexture(nil, "ARTWORK")
	box.icon:SetSize(32, 32)
	box.icon:SetPoint("TOPLEFT", 8, -8)
	box.lines = {}
	for i = 1, 5 do
		local fs = box:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormal" or "GameFontHighlightSmall")
		fs:SetPoint("TOPLEFT", 48, i == 1 and -8 or (-12 - i * 14))
		fs:SetPoint("RIGHT", box, "RIGHT", -8, 0)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		box.lines[i] = fs
	end
	panel.box = box

	local head = Row(0)
	head:SetParent(panel)
	head:EnableMouse(false)
	head.mark:Hide()
	head:SetPoint("TOPLEFT", 0, -74 - BOX_H - 6)
	head:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	head.icon:Hide()
	head.name:SetPoint("LEFT", 4, 0)
	head.name:SetFontObject("GameFontNormal")
	head.name:SetText("Rewards")
	for c, text in ipairs({ "Rank", "Favor", "Gold" }) do
		head.cols[c]:SetFontObject("GameFontNormalSmall")
		head.cols[c]:SetText(text)
	end
	rows[0] = nil

	scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -74 - BOX_H - 6 - ROW_H)
	scroll:SetPoint("BOTTOMRIGHT", -24, 4)
	inner = CreateFrame("Frame", nil, scroll)
	inner:SetSize(500, 1)
	scroll:SetScrollChild(inner)
	scroll:SetScript("OnSizeChanged", function(_, width) inner:SetWidth(width) end)
end

local function GoalLine()
	local plan = ns.Planner.Get("combined")
	return GREEN .. "Your goal.|r " .. (plan.camp and ("The Combined plan gets you there for " .. ns.CostText(plan.cost)
		.. (plan.days and plan.days > 1 and (" over " .. plan.days .. " days") or "") .. ".") or "")
end

-- The box for a profession's recipes ("prof:<name>").
local function ShowProfession(prof)
	local L = box.lines
	local t = ns.Choices.ProfessionRecipes(prof)
	box.icon:SetTexture(ns.ItemIcon(t.left[1] or next(ns.data.rewards)))
	L[1]:SetText(("All %s recipes"):format(prof))
	L[2]:SetText(("%d of %d left: %s Favor%s"):format(#t.left, t.all, Number(t.favor), t.copper > 0 and (" + " .. ns.Money(t.copper)) or "")
		.. (t.standing > 0 and (GREY .. "  ·  |rNeeds " .. ns.Faction.StandingName(t.standing) .. ": " .. RankStatus(t.standing)) or ""))
	local held = ns.Faction.Favor()
	L[3]:SetText(("You have %s Favor%s"):format(Number(held), held >= t.favor and (": " .. GREEN .. "enough|r")
		or (", " .. ORANGE .. Number(t.favor - held) .. " to go|r")))
	local seller
	for _, item in ipairs(t.left) do
		local s = ns.data.rewards[item].sellers
		seller = seller or (s and s[ns.Faction.Side() or ""])
	end
	local camp = ns.Faction.Camp()
	L[4]:SetText(seller and (GOLD .. "Sold by|r " .. seller.name .. (camp and (", " .. camp.place) or "")
		.. (seller.x and (" at %.1f, %.1f"):format(seller.x * 100, seller.y * 100) or ""))
		or (GOLD .. "Sold at|r " .. (camp and camp.place or "your faction's camp")))
	L[5]:SetText(ns.db.favorGoalProf == prof and GoalLine() or (GREY .. "Press All on its line to make them your Favor goal.|r"))
end

local function ShowReward(item)
	if type(item) == "string" then return ShowProfession(item:sub(6)) end
	local r = item and ns.data.rewards[item]
	local L = box.lines
	if not r then
		box.icon:SetTexture(ns.ICON)
		L[1]:SetText("Merchant's Favor rewards")
		L[2]:SetText("Click a reward below to make it your Favor goal. The Favor and Combined plans then plan for it.")
		for i = 3, 5 do L[i]:SetText("") end
		return
	end
	box.icon:SetTexture(ns.ItemIcon(item))
	L[1]:SetText(ns.ItemNameColored(item) .. ((r.what and not r.profession) and (GREY .. "  " .. r.what .. "|r") or ""))
	local cost = Number(r.favor) .. " Favor" .. (r.copper > 0 and (" + " .. ns.Money(r.copper)) or "")
	local rank = r.standing > 0 and ("Needs " .. ns.Faction.StandingName(r.standing) .. (r.guide and (GREY .. " (from guides)|r") or "") .. ": " .. RankStatus(r.standing))
		or ("No rank needed")
	L[2]:SetText(cost .. GREY .. "  ·  |r" .. rank)
	local held = ns.Faction.Favor()
	L[3]:SetText(("You have %s Favor%s"):format(Number(held), held >= r.favor and (": " .. GREEN .. "enough|r")
		or (", " .. ORANGE .. Number(r.favor - held) .. " to go|r")))
	local camp = ns.Faction.Camp()
	local seller = r.sellers and r.sellers[ns.Faction.Side() or ""]
	if seller then
		L[4]:SetText(GOLD .. "Sold by|r " .. seller.name .. (camp and (", " .. camp.place) or "")
			.. (seller.x and (" at %.1f, %.1f"):format(seller.x * 100, seller.y * 100) or ""))
	else
		L[4]:SetText(GOLD .. "Sold at|r " .. (camp and camp.place or "your faction's camp"))
	end
	if ns.Choices.Have(item) then
		L[5]:SetText(GREEN .. (ns.Recorder.Knows(r.teaches) and "You know this recipe." or "Its pattern is in your bags.") .. "|r")
	elseif ns.db.favorGoalItem == item then
		L[5]:SetText(GoalLine())
	else
		L[5]:SetText(GREY .. "Click it in the list to make it your Favor goal.|r")
	end
end

local function Refresh()
	rankDrop:GenerateMenu()
	goalDrop:GenerateMenu()
	local camp = ns.Faction.Camp()
	local standing, value = Standing()
	local goal = ns.Faction.THRESHOLDS[ns.db.targetStanding] or 42000
	repBar:SetMinMaxValues(0, math.max(goal, 1))
	repBar:SetValue(math.max(0, math.min(value, goal)))
	repBar.text:SetText(camp and ("Rep: %s, %s of %s for %s"):format(ns.Faction.StandingName(standing), Number(value), Number(goal),
		ns.Faction.StandingName(ns.db.targetStanding)) or "This character has no trade faction.")
	local held, want = ns.Faction.Favor(), ns.Choices.FavorGoal()
	favorBar:SetMinMaxValues(0, math.max(want, 1))
	favorBar:SetValue(math.min(held, want))
	favorBar.text:SetText(("Merchant's Favor: %s held%s"):format(Number(held), want > 0 and (", goal " .. Number(want)) or ", no goal"))

	selected = selected or ns.db.favorGoalItem or (ns.db.favorGoalProf and ("prof:" .. ns.db.favorGoalProf))
	ShowReward(selected)

	local entries = Entries()
	local y = 0
	for i, e in ipairs(entries) do
		local r = Row(i)
		r.entry = e
		r.icon:ClearAllPoints()
		r.name:ClearAllPoints()
		r.name:SetPoint("RIGHT", r, "RIGHT", -(3 * COL_W + 4), 0)
		r.mark:SetShown((e.kind == "reward" and e.item == ns.db.favorGoalItem) or (e.kind == "prof" and e.profession == ns.db.favorGoalProf))
		r.all:SetShown(e.kind == "prof" and e.left > 0)
		for c = 1, 3 do r.cols[c]:SetText("") end
		if e.kind == "head" then
			r.icon:Hide()
			r.name:SetPoint("LEFT", 4, 0)
			r.name:SetText(GOLD .. e.text .. "|r" .. (e.status and ("  " .. e.status) or ""))
		elseif e.kind == "prof" then
			r.icon:Hide()
			r.name:SetPoint("LEFT", 8, 0)
			local known = e.count - e.left
			r.name:SetText((e.open and "- " or "+ ") .. e.profession .. GREY .. ("  %d recipe%s%s|r"):format(e.count, e.count == 1 and "" or "s",
				known > 0 and (", " .. known .. " you have") or ""))
			r.cols[2]:SetText(e.left > 0 and Number(e.favor) or (GREEN .. "all|r"))
		else
			local x = e.indent and 24 or 8
			r.icon:Show()
			r.icon:SetPoint("LEFT", x, 0)
			r.icon:SetTexture(ns.ItemIcon(e.item))
			r.name:SetPoint("LEFT", x + 22, 0)
			local name = e.r.profession and ns.ItemNameColored(e.item) or ns.Choices.RewardName(e.item)
			if e.have then name = GREY .. ns.ItemName(e.item) .. "|r " .. GREEN .. (ns.Recorder.Knows(e.r.teaches) and "known" or "in your bags") .. "|r" end
			r.name:SetText(name)
			r.cols[1]:SetText(RankText(e.r))
			r.cols[2]:SetText(Number(e.r.favor))
			r.cols[3]:SetText(e.r.copper > 0 and ns.Money(e.r.copper) or (GREY .. "-|r"))
		end
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -y)
		r:SetPoint("RIGHT", inner, "RIGHT")
		r:Show()
		y = y + ROW_H
	end
	for i = #entries + 1, #rows do rows[i]:Hide() end
	inner:SetHeight(math.max(1, y))
end

ns.Window.AddPage({ id = "rewards", label = "Rewards", build = Build, refresh = Refresh })
