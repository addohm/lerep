-- leRep: your trade faction. Which one is yours, your standing and Merchant's Favor, what you've done
-- today, and what each turn-in gives: the data's numbers, replaced by what you've seen in game.
local _, ns = ...
local Try = ns.Try

local Faction = {}
ns.Faction = Faction

-- Rep needed to reach each standing, counted from 0 at the start of Neutral.
Faction.THRESHOLDS = { [4] = 0, [5] = 3000, [6] = 9000, [7] = 21000, [8] = 42000 }
Faction.MAX = 42999 -- Exalted 999/1000
local NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

function Faction.StandingName(standing)
	return NAMES[standing or 0] or "?"
end

-- Your side's camp from the data (faction, NPCs), or nil for a character with no side.
function Faction.Side()
	local side = ns.Plain(Try(UnitFactionGroup, "player"))
	return (side == "Alliance" or side == "Horde") and side or nil
end

function Faction.Camp()
	local side = Faction.Side()
	return side and ns.data.camps[side]
end

-- Your standing (1 Hated ... 8 Exalted) and rep, counted from 0 at the start of Neutral like
-- Faction.THRESHOLDS. nil if the game doesn't say.
function Faction.Standing()
	local camp = Faction.Camp()
	if not camp then return nil end
	local id = camp.faction
	local api = C_Reputation and C_Reputation.GetFactionDataByID
	local data = api and Try(api, id)
	if type(data) == "table" and data.reaction then
		return data.reaction, data.currentStanding
	end
	local _, _, standing, _, _, value = Try(GetFactionInfoByID, id)
	if standing then return standing, value end
	return nil
end

-- Rep still needed to reach a standing (0 if you're there).
function Faction.RepToGo(target)
	local _, value = Faction.Standing()
	local goal = Faction.THRESHOLDS[target or 8] or 42000
	return math.max(0, goal - (value or 0))
end

function Faction.Favor()
	local info = C_CurrencyInfo and Try(C_CurrencyInfo.GetCurrencyInfo, ns.data.favorCurrency)
	return type(info) == "table" and info.quantity or 0
end

local function QuestDone(questID)
	return questID and C_QuestLog and Try(C_QuestLog.IsQuestFlaggedCompleted, questID) and true or false
end
Faction.QuestDone = QuestDone

-- The Shipping Label's 2,000 rep: once per character.
function Faction.LabelDone()
	local camp = Faction.Camp()
	return camp and QuestDone(camp.labelQuest) or false
end

-- Writs are daily: one handed in today shows as done until the daily reset.
function Faction.WritDoneToday(writ)
	return QuestDone(writ.quest)
end

-- Receipts need a standing (Friendly).
function Faction.CanBuyReceipts()
	local standing = Faction.Standing()
	return (standing or 0) >= ns.data.receipt.standing
end

-- What turn-ins give -----------------------------------------------------------------------------

-- Rep for a turn-in whose base is `base`, with your rep bonus (the Diplomat perk).
function Faction.Rep(base)
	return math.floor(base * (1 + (ns.db.repBonus or 0) / 100) + 0.5)
end

-- The Favor one filled crate pays on average: the least you've seen for its kind, else the data's;
-- times the Performance Bonus chance of double.
function Faction.CrateFavor(crate)
	local key = crate.tier .. (crate.green and "Green" or "")
	local seen = ns.adb and ns.adb.seen.crateFavor[key]
	return (seen or crate.favor) * (1 + (ns.db.favorBonus or 0) / 100), seen ~= nil
end

-- The receipt's price in Favor: what the scribe charged you, else the data's (from guides).
function Faction.ReceiptFavor()
	local seen = ns.adb and ns.adb.seen.receiptFavor
	return seen or ns.data.receipt.favor, seen ~= nil
end

-- What the Coin Pouch for a writ tier is worth: the average you've opened, else the data's guess.
local POUCHES = { Journeyman = 284584, Expert = 284585, Artisan = 284586 }
Faction.POUCHES = POUCHES
function Faction.PouchValue(tier)
	if not ns.db.usePouch then return 0 end
	local seen = ns.adb and ns.adb.seen.pouch[POUCHES[tier] or 0]
	if seen and seen.n and seen.n > 0 then return seen.total / seen.n, true end
	return ns.data.coinPouch[tier] or 0, false
end
