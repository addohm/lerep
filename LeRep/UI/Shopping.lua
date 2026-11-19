-- LeRep: the Shopping tab. Everything today's steps of the plan you followed last need, combined:
-- crafted items broken down into their materials, what you hold counted once (need, have, buy,
-- each, cost), the gold to spend, and Send to Auctionator.
local _, ns = ...

local GREY, ORANGE = "|cff9d9d9d", "|cffff9933"
local ROW_H, COLS, COL_W = 16, 5, 70

local panel, scroll, inner, heading, header, emptyText, totalText, sendButton
local rows = {}

local function Row(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Button", nil, inner)
	r:SetHeight(ROW_H)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", 8, 0)
	r.name:SetPoint("RIGHT", r, "RIGHT", -(COLS * COL_W + 4), 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.cols = {}
	for c = 1, COLS do
		local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetWidth(COL_W - 4)
		fs:SetJustifyH("RIGHT")
		fs:SetPoint("RIGHT", r, "RIGHT", -((COLS - c) * COL_W + 4), 0)
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
	rows[i] = r
	return r
end

local function Build(p)
	panel = p
	heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOPLEFT", 4, -4)
	heading:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
	heading:SetJustifyH("LEFT")
	panel.heading = heading

	scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -24)
	scroll:SetPoint("BOTTOMRIGHT", -24, 34)
	inner = CreateFrame("Frame", nil, scroll)
	inner:SetSize(500, 1)
	scroll:SetScrollChild(inner)
	scroll:SetScript("OnSizeChanged", function(_, width) inner:SetWidth(width) end)

	header = Row(0)
	header:EnableMouse(false)
	header.name:SetFontObject("GameFontNormalSmall")
	header.name:SetText("Item")
	for c, text in ipairs({ "Need", "Have", "Buy", "Each", "Cost" }) do
		header.cols[c]:SetFontObject("GameFontNormalSmall")
		header.cols[c]:SetText(text)
	end
	rows[0] = nil

	emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("TOPLEFT", 8, -40)
	emptyText:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
	emptyText:SetJustifyH("LEFT")
	panel.emptyText = emptyText

	local rule = panel:CreateTexture(nil, "BORDER")
	rule:SetPoint("BOTTOMLEFT", 0, 30)
	rule:SetPoint("BOTTOMRIGHT", 0, 30)
	rule:SetHeight(1)
	rule:SetColorTexture(0.6, 0.45, 0.15, 0.6)

	sendButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	sendButton:SetSize(160, 22)
	sendButton:SetPoint("BOTTOMRIGHT", -2, 2)
	sendButton:SetText("Send to Auctionator")
	sendButton:SetScript("OnClick", function() ns.Shopping.SendToAuctionator() end)
	sendButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Send to Auctionator")
		GameTooltip:AddLine(("Makes Auctionator's \"%s\" shopping list from what's left to buy, replacing the last one. Items vendors sell are left out."):format(ns.Shopping.LIST_NAME), 1, 1, 1, true)
		if not ns.Shopping.CanSend() then GameTooltip:AddLine("Needs Auctionator.", 1, 0.6, 0.2) end
		GameTooltip:Show()
	end)
	sendButton:SetScript("OnLeave", GameTooltip_Hide)
	panel.send = sendButton

	totalText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	totalText:SetPoint("BOTTOMLEFT", 4, 8)
	totalText:SetPoint("RIGHT", sendButton, "LEFT", -8, 0)
	totalText:SetJustifyH("LEFT")
	panel.totalText = totalText
end

local function Refresh()
	local plan = ns.Planner.Followed()
	local list = plan.shopping or {}
	local receipts = (plan.receipts or 0) > 0
	heading:SetText(("For today's steps of the %s plan%s"):format(ns.Planner.NAMES[plan.kind],
		receipts and ((GREY .. ";  plus %d Forged Delivery Receipts for %d Favor each, from %s|r"):format(plan.receipts, plan.receiptFavor, plan.camp.scribe.name)) or ""))
	local empty = #list == 0
	emptyText:SetShown(empty)
	emptyText:SetText(plan.problem or "Nothing to buy for today's steps.")
	header:SetShown(not empty)

	local y = 0
	if not empty then
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
		header:SetPoint("RIGHT", inner, "RIGHT")
		header:Show()
		y = ROW_H
	end
	local missing = false
	for i, m in ipairs(list) do
		local r = Row(i)
		r.itemID = m.itemID
		local tag = m.how == "vendor" and (GREY .. " (vendor)|r") or (not m.each and (ORANGE .. " (no price)|r") or "")
		r.name:SetText(ns.ItemNameColored(m.itemID) .. tag)
		r.cols[1]:SetText(m.need)
		r.cols[2]:SetText(m.have > 0 and m.have or (GREY .. "0|r"))
		r.cols[3]:SetText(m.buy > 0 and m.buy or (GREY .. "-|r"))
		r.cols[4]:SetText(m.each and ns.Money(m.each) or (ORANGE .. "?|r"))
		r.cols[5]:SetText(m.buy > 0 and (m.cost and ns.Money(m.cost) or (ORANGE .. "?|r")) or (GREY .. "-|r"))
		if m.buy > 0 and not m.each then missing = true end
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -y)
		r:SetPoint("RIGHT", inner, "RIGHT")
		r:Show()
		y = y + ROW_H
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	inner:SetHeight(math.max(1, y))
	totalText:SetText(empty and "" or (("To buy: %s%s"):format(ns.Money(plan.spend or 0), missing and (", and " .. ORANGE .. "some items have no price|r") or "")))
	sendButton:SetEnabled(not empty)
end

ns.Window.AddPage({ id = "shopping", label = "Shopping", build = Build, refresh = Refresh })
