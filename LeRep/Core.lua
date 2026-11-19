-- LeRep: settings, events and slash commands. Settings are per character (LeRepCharDB, ns.db); what
-- you record (vendor prices, what turn-ins really gave) is shared by your characters (LeRepDB,
-- ns.adb).
local ADDON, ns = ...

ns.ICON = "Interface\\Icons\\INV_Misc_Note_02" -- a stock icon until LeRep has its own art

local DEFAULTS = {
	targetStanding = 8,  -- the rank the plans aim for: 5 Friendly, 6 Honored, 7 Revered, 8 Exalted
	favorGoal = 0,       -- Merchant's Favor the plans aim for (on top of what receipts need)
	favorGoalItem = nil, -- the reward picked for it, if one was (itemID)
	repBonus = 0,        -- percent more rep per turn-in (the Diplomat Legacy perk: 2 per rank)
	favorBonus = 0,      -- percent chance a filled crate pays double Favor (the Performance Bonus perk)
	days = 7,            -- finish within this many days (0: no limit); writs are once a day each
	writAgeDays = 1,     -- a writ counts as on sale if Auctionator saw it this many days ago or less
	usePouch = true,     -- take the Coin Pouch a writ pays off its cost
	lastPlan = "combined", -- the plan tab opened last: Shopping and the step alerts follow it
	stepAlerts = true,   -- say in chat when a step is done
	known = {},          -- recipeSpellID -> true: recipes this character knows (read from the profession window)
	window = {},         -- the window: pos, size, tab
	minimap = { angle = 325, hide = false }, -- clear of Nothing Wasted, Ticky, Leboof, Leproc and Leprofit (200-300)
}
ns.DEFAULTS = DEFAULTS

-- The settings the Options tab's Defaults button puts back.
ns.OPTION_KEYS = { "targetStanding", "favorGoal", "favorGoalItem", "days", "repBonus", "favorBonus", "writAgeDays", "usePouch", "stepAlerts" }

local ACCOUNT_DEFAULTS = {
	vendorPrices = {}, -- itemID -> copper for one, recorded at vendors
	itemNames = {},    -- itemID -> name, for items the game hasn't loaded yet
	seen = {           -- what turn-ins really gave (Recorder.lua); these replace the data's guesses
		receiptFavor = nil, -- the Forged Delivery Receipt's price in Favor, at the scribe
		crateFavor = {},    -- "Apprentice" / "ApprenticeGreen"... -> the least Favor seen for one
		pouch = {},         -- Coin Pouch itemID -> { total copper, how many opened }
	},
}

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and CopyDefaults({}, v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			CopyDefaults(dst[k], v)
		end
	end
	return dst
end

function ns.Print(msg)
	print("|cffffd100LeRep|r: " .. msg)
end

function ns.Version()
	local v = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
	return "v" .. v .. (ns.build and (" build " .. ns.build) or "")
end

function ns.ResetOptions()
	for _, k in ipairs(ns.OPTION_KEYS) do ns.db[k] = DEFAULTS[k] end
end

-- Refreshing ---------------------------------------------------------------------------------

-- Plans are worked out again only when something they use changed: prices, what you hold, your
-- standing or Favor, the settings. ns.Changed() marks that; the window redraws a moment later.
ns.version = 0
function ns.Changed()
	ns.version = ns.version + 1
	ns.Refresh()
end

-- Many events can arrive at once (bags, prices, rep): redraw once, a moment later. Once you've
-- opened a plan this session, also check whether its first step got done (step alerts).
local queued = false
function ns.Refresh()
	if queued then return end
	queued = true
	C_Timer.After(0.2, function()
		queued = false
		if ns.Window then ns.Window.Refresh() end
		if ns.watching then ns.Planner.WatchSteps() end
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "AUCTION_HOUSE_CLOSED", "UPDATE_FACTION", "CURRENCY_DISPLAY_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_MONEY" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == ADDON then
		LeRepCharDB = CopyDefaults(type(LeRepCharDB) == "table" and LeRepCharDB or {}, DEFAULTS)
		LeRepDB = CopyDefaults(type(LeRepDB) == "table" and LeRepDB or {}, ACCOUNT_DEFAULTS)
		ns.db, ns.adb = LeRepCharDB, LeRepDB
	elseif event == "PLAYER_LOGIN" then
		if ns.Minimap then ns.Minimap.Init() end
		ns.Changed()
	elseif event ~= "ADDON_LOADED" then
		-- What you hold, your rep or Favor changed, or a scan brought new prices.
		ns.Changed()
	end
end)

-- Slash commands -------------------------------------------------------------------------------

local function Status()
	ns.Print(ns.Version())
	ns.Print("Prices: " .. ns.Prices.SourcesText())
	local camp = ns.Faction.Camp()
	if not camp then
		ns.Print("this character has no trade faction (Alliance or Horde only).")
		return
	end
	local standing, value = ns.Faction.Standing()
	ns.Print(("%s: %s, %d rep; %d Merchant's Favor; Shipping Label %s."):format(camp.factionName,
		ns.Faction.StandingName(standing), value or 0, ns.Faction.Favor() or 0,
		ns.Faction.LabelDone() and "handed in" or "not handed in yet"))
	local known = 0
	for _ in pairs(ns.db.known) do known = known + 1 end
	ns.Print(("%d of the recipes behind writ items and crate bundles are known by this character%s."):format(known,
		known == 0 and " (open your profession windows once to read them)" or ""))
end

local function Help()
	ns.Print(ns.Version())
	ns.Print("/lerep - open or close the window")
	ns.Print("/lerep status - price sources, your standing and Favor")
	ns.Print("/lerep minimap - show or hide the minimap button")
	ns.Print("/lerep reset - put the window back in the middle at its normal size")
end

SLASH_LEREP1 = "/lerep"
SlashCmdList.LEREP = function(msg)
	local cmd = strtrim(msg or ""):match("^(%S*)") or ""
	cmd = cmd:lower()
	if cmd == "" then
		ns.Window.Toggle()
	elseif cmd == "help" then
		Help()
	elseif cmd == "status" then
		Status()
	elseif cmd == "minimap" then
		ns.Minimap.SetShown(ns.db.minimap.hide)
	elseif cmd == "reset" then
		ns.Window.ResetPosition()
		ns.Print("the window is back in the middle.")
	else
		ns.Print("unknown command '" .. cmd .. "'. /lerep help lists the commands.")
	end
end
