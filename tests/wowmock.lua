-- A small fake WoW client for LeRep's tests (from leprofit's): frames that accept any method call,
-- events, timers, items, a profession window, a vendor, reputation, currency, quests, and
-- Auctionator's and TSM's price APIs. Tests set the data
-- through WM (items, prices, the recipes shown, the vendor's stock) and fire events with WM.Fire.
local M = {
	printed = {}, frames = {}, timers = {},
	items = {},       -- itemID -> { name, sellPrice, bindType, quality, count }
	auctionator = {}, -- itemID -> price
	auctionatorVendor = {}, -- itemID -> what a vendor charges, as Auctionator recorded it
	ages = {},        -- itemID -> days
	opened = {},      -- skill lines C_TradeSkillUI.OpenTradeSkill was asked to open
	history = {},     -- itemID -> Auctionator's price history, newest first: { rawDay, minSeen, maxSeen, available }
	today = 2000,     -- Auctionator's day number for today
	lists = {},       -- Auctionator shopping lists made: name -> search strings
	tsm = nil,        -- { DBMinBuyout = { [id] = n }, DBMarket = { [id] = n } } when TSM is installed
	profession = nil, -- the open profession window's name
	recipes = {},     -- what the open window lists: { id, name, learned, product, min, max, reagents = { { id, n } } }
	merchant = {},    -- the vendor's stock: { itemID, name, price, stack, available, extended }
	skills = {},      -- profession -> rank
	faction = "Alliance",
	standing = 4,     -- your standing with your trade faction: 4 Neutral ... 8 Exalted
	rep = 0,          -- your rep, from 0 at the start of Neutral
	favor = 0,        -- Merchant's Favor
	questsDone = {},  -- questID -> true: flagged completed (dailies until the reset)
	spells = {},      -- spellID -> true: IsPlayerSpell
	money = 0,
	costs = {},       -- merchant slot -> { { amount, link, currencyName } }
}

local function Permissive(t)
	return setmetatable(t, { __index = function(_, k)
		if type(k) == "string" and k:match("^%u") then return function() return nil end end
	end })
end

local function FontString()
	local fs = Permissive({ shown = true, points = {} })
	function fs:SetPoint(...) table.insert(self.points, { ... }) end
	function fs:ClearAllPoints() self.points = {} end
	function fs:SetText(t) self.text = t end
	function fs:GetText() return self.text end
	function fs:GetStringWidth() return #(self.text or "") * 6 end
	function fs:Show() self.shown = true end
	function fs:Hide() self.shown = false end
	function fs:SetShown(v) self.shown = v and true or false end
	function fs:IsShown() return self.shown end
	return fs
end

local function NewFrame(kind, name, parent)
	local f = { kind = kind, name = name, parent = parent, shown = true, points = {}, scripts = {}, events = {}, level = 1, w = 0, h = 0, children = {} }
	if parent and parent.children then table.insert(parent.children, f) end
	function f:Show()
		local was = self.shown
		self.shown = true
		if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function f:Hide()
		local was = self.shown
		self.shown = false
		if was and self.scripts.OnHide then self.scripts.OnHide(self) end
	end
	function f:SetShown(v) if v then self:Show() else self:Hide() end end
	function f:IsShown() return self.shown end
	function f:SetSize(w, h) self.w, self.h = w, h end
	function f:GetSize() return self.w, self.h end
	function f:SetWidth(w) self.w = w end
	function f:SetHeight(h) self.h = h end
	function f:GetWidth() return self.w end
	function f:GetHeight() return self.h end
	function f:GetCenter() return 0, 0 end
	function f:GetEffectiveScale() return 1 end
	function f:GetChecked() return self.checked end
	function f:SetChecked(v) self.checked = v end
	function f:SetText(t) self.text = t end
	function f:GetText() return self.text end
	function f:HasFocus() return false end
	function f:ClearAllPoints() self.points = {} end
	function f:SetPoint(...) table.insert(self.points, { ... }) end
	function f:GetPoint() local p = self.points[1] or {} return p[1], nil, p[3], p[4], p[5] end
	function f:GetFrameLevel() return self.level end
	function f:SetFrameLevel(l) self.level = l end
	function f:SetParent(p) self.parent = p end
	function f:SetScript(event, fn) self.scripts[event] = fn end
	function f:HookScript(event, fn)
		local old = self.scripts[event]
		self.scripts[event] = old and function(...) old(...) fn(...) end or fn
	end
	function f:GetScript(event) return self.scripts[event] end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:CreateTexture()
		local tex = Permissive({})
		function tex:SetDesaturated(v) self.desaturated = v and true or false end
		return tex
	end
	function f:SetAlpha(a) self.alpha = a end
	function f:CreateFontString() return FontString() end
	function f:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
	-- Blizzard's menu system: a DropdownButton keeps the function that builds its menu.
	function f:SetupMenu(fn) self.menuGenerator = fn end
	table.insert(M.frames, f)
	if name then _G[name] = f end
	return Permissive(f)
end
M.NewFrame = NewFrame

function CreateFrame(kind, name, parent) return NewFrame(kind, name, parent) end
UIParent = NewFrame("Frame", "UIParent")
Minimap = NewFrame("Frame", "Minimap")
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
function GameTooltip:SetItemByID(id) self.item = id end
-- The tooltip keeps its lines (a double line as "left | right") until the next SetOwner.
GameTooltip.lines = {}
function GameTooltip:SetOwner() self.lines = {} end
function GameTooltip:AddLine(text) table.insert(self.lines, tostring(text)) end
function GameTooltip:AddDoubleLine(left, right) table.insert(self.lines, tostring(left) .. " | " .. tostring(right)) end
function GameTooltip_Hide() end
UISpecialFrames = {}
SlashCmdList = {}
ITEM_QUALITY_COLORS = { [2] = { hex = "|cff1eff00" } }
Enum = {}

function M.Fire(event, ...)
	for _, f in ipairs(M.frames) do
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end

-- Timers run when the test calls WM.RunTimers (C_Timer.After(0) and longer alike).
C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }
function M.RunTimers()
	for _ = 1, 10 do
		local list = M.timers
		M.timers = {}
		if #list == 0 then return end
		for _, fn in ipairs(list) do fn() end
	end
end

print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	table.insert(M.printed, table.concat(parts, " "))
end

function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s, n)
	local out, start = {}, 1
	while true do
		if n and #out == n - 1 then out[#out + 1] = s:sub(start) break end
		local i = s:find(sep, start, true)
		if not i then out[#out + 1] = s:sub(start) break end
		out[#out + 1] = s:sub(start, i - 1)
		start = i + 1
	end
	return unpack(out)
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function GetTime() return M.clock or 1000 end
function time() return M.today * 86400 + 3600 end
-- Modified clicks: set WM.modifier to "CHATLINK" (shift) or "DRESSUP" (ctrl); links land in WM.linked.
M.linked = {}
function IsModifiedClick(action) return M.modifier ~= nil and M.modifier == action end
function HandleModifiedItemClick(link) table.insert(M.linked, link) return true end
function InCombatLockdown() return false end
function GetCursorPosition() return 0, 0 end
function UnitFactionGroup(unit) return unit == "npc" and M.npcFaction or M.faction end
function UnitReaction() return M.npcReaction end
function UnitName(unit) return unit == "npc" and M.vendorName or "Tester" end
function GetZoneText() return "Stormwind City" end
function GetSubZoneText() return "Trade District" end
C_Map = {
	GetBestMapForUnit = function() return 84 end,
	GetMapInfo = function() return { name = "Stormwind City" } end,
	GetPlayerMapPosition = function()
		return { GetXY = function() return 0.642, 0.581 end }
	end,
}
C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "1.0.0" or nil end }
C_CurrencyInfo = {
	GetCurrencyInfo = function(id) return id == 3402 and { quantity = M.favor, name = "Merchant's Favor" } or nil end,
	GetCoinTextureString = function(c)
		local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
		local out = {}
		if g > 0 then out[#out + 1] = g .. "g" end
		if s > 0 then out[#out + 1] = s .. "s" end
		if k > 0 then out[#out + 1] = k .. "c" end
		return table.concat(out, " ")
	end,
}

C_Reputation = {
	GetFactionDataByID = function(id)
		local mine = (M.faction == "Alliance" and 2586) or (M.faction == "Horde" and 2587)
		if id ~= mine then return { reaction = 1, currentStanding = -42000 } end
		return { reaction = M.standing, currentStanding = M.rep }
	end,
}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return M.questsDone[id] or false end }
function IsPlayerSpell(id) return M.spells[id] or false end
function GetMoney() return M.money end
function GetMerchantItemCostInfo(i) return M.costs[i] and #M.costs[i] or 0 end
function GetMerchantItemCostItem(i, j)
	local c = M.costs[i] and M.costs[i][j]
	if c then return 134400, c[1], c[2], c[3] end
end

-- Items
C_Item = {
	GetItemNameByID = function(id) return M.items[id] and M.items[id].name end,
	GetItemQualityByID = function(id) return M.items[id] and M.items[id].quality end,
	GetItemIconByID = function(id) return M.items[id] and 134400 or nil end,
	GetItemCount = function(id) return M.items[id] and M.items[id].count or 0 end,
	GetItemInfo = function(id)
		local it = M.items[id]
		if not it then return nil end
		local link = ("|cffffffff|Hitem:%d::::::::|h[%s]|h|r"):format(id, it.name)
		return it.name, link, it.quality or 1, 1, 1, "", "", 20, "", 134400, it.sellPrice or 0, 0, 0, it.bindType or 0
	end,
}
Item = {
	CreateFromItemID = function(_, id)
		local item = {}
		function item:IsItemEmpty() return false end
		function item:ContinueOnItemLoad(fn) M.loads = (M.loads or 0) + 1 end
		function item:GetItemName() return M.items[id] and M.items[id].name end
		return item
	end,
}

-- Skills
function GetNumSkillLines() local n = 0 for _ in pairs(M.skills) do n = n + 1 end return n end
function GetSkillLineInfo(i)
	local n = 0
	for name, rank in pairs(M.skills) do
		n = n + 1
		if n == i then return name, false, false, rank end
	end
end

-- The profession window
C_TradeSkillUI = {
	GetBaseProfessionInfo = function() return M.profession and { professionName = M.profession } end,
	GetTradeSkillLine = function() return 1, M.profession end,
	OpenTradeSkill = function(line)
		table.insert(M.opened, line)
		return true
	end,
	GetAllRecipeIDs = function()
		local ids = {}
		for _, r in ipairs(M.recipes) do ids[#ids + 1] = r.id end
		return ids
	end,
	GetRecipeInfo = function(id)
		for _, r in ipairs(M.recipes) do
			if r.id == id then return { name = r.name, learned = r.learned, icon = 1 } end
		end
	end,
	GetRecipeSchematic = function(id)
		for _, r in ipairs(M.recipes) do
			if r.id == id then
				local slots = {}
				for _, g in ipairs(r.reagents) do
					slots[#slots + 1] = { reagents = { { itemID = g[1] } }, quantityRequired = g[2], required = true }
				end
				return { outputItemID = r.product, quantityMin = r.min or 1, quantityMax = r.max or r.min or 1, reagentSlotSchematics = slots }
			end
		end
	end,
}

-- The vendor
function GetMerchantNumItems() return #M.merchant end
function GetMerchantItemID(i) return M.merchant[i] and M.merchant[i].itemID end
C_MerchantFrame = {
	GetItemInfo = function(i)
		local m = M.merchant[i]
		return m and { name = m.name, price = m.price, stackCount = m.stack or 1, numAvailable = m.available or -1, hasExtendedCost = m.extended or false }
	end,
}

-- Price addons
Auctionator = { Constants = { SCAN_DAY_0 = 0 }, Database = {
	GetPriceHistory = function(_, key)
		assert(type(key) == "string", "Auctionator's keys are strings")
		return M.history[tonumber(key)] or {}
	end,
}, API = { v1 = {
	GetAuctionPriceByItemID = function(caller, id)
		assert(caller == "LeRep", "Auctionator needs the caller's name")
		return M.auctionator[id]
	end,
	GetAuctionAgeByItemID = function(_, id) return M.ages[id] end,
	GetVendorPriceByItemID = function(_, id) return M.auctionatorVendor[id] end,
	ConvertToSearchString = function(_, term) return ('"%s";;;;;;;;;;;;;%d'):format(term.searchString, term.quantity) end,
	CreateShoppingList = function(caller, name, terms)
		assert(caller == "LeRep")
		M.lists[name] = terms
	end,
} } }
function M.SetTSM(prices)
	M.tsm = prices
	TSM_API = prices and {
		GetCustomPriceValue = function(source, itemString)
			local id = tonumber(itemString:match("^i:(%d+)$"))
			return M.tsm[source] and M.tsm[source][id]
		end,
	} or nil
end

-- A menu's root, as SetupMenu's function gets it: records the radio buttons added.
function M.MenuRoot()
	local root = { radios = {} }
	function root:CreateRadio(text, isSelected, setSelected)
		table.insert(self.radios, { text = text, isSelected = isSelected, setSelected = setSelected })
	end
	return root
end

return M
