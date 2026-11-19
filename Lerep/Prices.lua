-- Lerep: prices (from leprofit). Auction prices come from Auctionator or TradeSkillMaster on this
-- computer (their own scans); vendor prices from what you recorded at vendors or Lerep's data. A
-- vendor price wins; without one, the auction price.
local ADDON, ns = ...

local Prices = {}
ns.Prices = Prices

local function Auctionator()
	local api = rawget(_G, "Auctionator")
	api = type(api) == "table" and type(api.API) == "table" and api.API.v1
	return type(api) == "table" and api or nil
end

local function TSM()
	local api = rawget(_G, "TSM_API")
	return (type(api) == "table" and api.GetCustomPriceValue) and api or nil
end

local function TSMPrice(source, itemID)
	local api = TSM()
	if not api then return nil end
	local price = ns.Try(api.GetCustomPriceValue, source, "i:" .. itemID)
	return type(price) == "number" and price > 0 and price or nil
end

-- The lowest buyout: Auctionator's last scan, else TSM's.
function Prices.Buyout(itemID)
	local api = Auctionator()
	if api and api.GetAuctionPriceByItemID then
		local price = ns.Try(api.GetAuctionPriceByItemID, ADDON, itemID)
		if type(price) == "number" and price > 0 then return price end
	end
	return TSMPrice("DBMinBuyout", itemID)
end

-- Auctionator's price history. Its database keeps, for each day you scanned (21 days by default),
-- the lowest price seen and the most listed at once. That isn't in Auctionator's official API, so
-- every step is checked: if an update changes it, these numbers are simply missing.
local HISTORY_DAYS = 14
Prices.HISTORY_DAYS = HISTORY_DAYS

local function Today()
	local A = rawget(_G, "Auctionator")
	local zero = type(A) == "table" and type(A.Constants) == "table" and A.Constants.SCAN_DAY_0
	if type(zero) ~= "number" then return nil end
	return math.floor((time() - zero) / 86400)
end

local function ReadHistory(itemID)
	local A = rawget(_G, "Auctionator")
	local db = type(A) == "table" and A.Database
	if type(db) ~= "table" or type(db.GetPriceHistory) ~= "function" then return nil end
	local list = ns.Try(db.GetPriceHistory, db, tostring(itemID))
	if type(list) ~= "table" or #list == 0 then return nil end
	local days = {}
	for _, e in ipairs(list) do
		local day, price = type(e) == "table" and tonumber(e.rawDay), type(e) == "table" and tonumber(e.minSeen)
		if day and price then days[#days + 1] = { day = day, price = price, listed = tonumber(e.available) } end
	end
	if #days == 0 then return nil end
	table.sort(days, function(a, b) return a.day > b.day end)
	local today = Today() or days[1].day
	local sum, seen, recent, nRecent, before, nBefore = 0, 0, 0, 0, 0, 0
	for _, d in ipairs(days) do
		local ago = today - d.day
		if ago >= 0 and ago < HISTORY_DAYS then
			sum, seen = sum + d.price, seen + 1
		end
		if ago >= 0 and ago < 3 then
			recent, nRecent = recent + d.price, nRecent + 1
		elseif ago >= 3 and ago < 7 then
			before, nBefore = before + d.price, nBefore + 1
		end
	end
	local h = { seen = seen, days = HISTORY_DAYS, listed = days[1].listed, lastSeen = today - days[1].day }
	if seen > 0 then h.average = math.floor(sum / seen) end
	-- The trend: the last 3 days against the 4 before, level within 5%.
	if nRecent > 0 and nBefore > 0 then
		local a, b = recent / nRecent, before / nBefore
		h.trend = (a > b * 1.05 and 1) or (a < b * 0.95 and -1) or 0
	end
	return h
end

-- An item's history: { average (14 days), seen (days listed of the last 14), days (14), listed
-- (at the last scan it was seen), lastSeen (days ago), trend (1 up, 0 level, -1 down) }, or nil.
-- Read once per moment: the list asks for it many times.
local memo, memoStamp = {}, nil
function Prices.History(itemID)
	local stamp = GetTime()
	if stamp ~= memoStamp then memo, memoStamp = {}, stamp end
	local h = memo[itemID]
	if h == nil then
		h = ReadHistory(itemID) or false
		memo[itemID] = h
	end
	return h or nil
end

-- The steadier price: TSM's market value if TSM is installed, else the 14-day average of
-- Auctionator's daily lowest prices.
function Prices.Market(itemID)
	local tsm = TSMPrice("DBMarket", itemID)
	if tsm then return tsm end
	local h = Prices.History(itemID)
	return h and h.average
end

-- What that steadier price is called, for the sums' text.
function Prices.MarketName()
	return TSM() and "TSM's market value" or "14-day average"
end

-- How many days old Auctionator's price is, or nil if unknown.
function Prices.Age(itemID)
	local api = Auctionator()
	if not (api and api.GetAuctionAgeByItemID) then return nil end
	local age = ns.Try(api.GetAuctionAgeByItemID, ADDON, itemID)
	return type(age) == "number" and age or nil
end

-- What a vendor charges for one, if anyone has recorded it: you (Recorder.lua), Lerep's data, or
-- Auctionator, which records the same thing at every vendor you open (items in endless supply, the
-- price for one).
function Prices.Vendor(itemID)
	local price = ns.adb and ns.adb.vendorPrices[itemID]
	if price then return price end
	if ns.data.vendorPrices[itemID] then return ns.data.vendorPrices[itemID] end
	local api = Auctionator()
	if api and api.GetVendorPriceByItemID then
		price = ns.Try(api.GetVendorPriceByItemID, ADDON, itemID)
		if type(price) == "number" and price > 0 then return price end
	end
	return nil
end

-- What buying one costs: a vendor's price (vendors never run out), else the auction house's.
-- Returns the price and where it's from ("vendor" or "auction").
function Prices.Buy(itemID)
	local vendor = Prices.Vendor(itemID)
	if vendor then return vendor, "vendor" end
	local auction = Prices.Buyout(itemID) or Prices.Market(itemID)
	if auction then return auction, "auction" end
	return nil, nil
end

function Prices.HasAuctionator() return Auctionator() ~= nil end
function Prices.HasTSM() return TSM() ~= nil end

function Prices.SourcesText()
	local parts = {}
	if Prices.HasAuctionator() then parts[#parts + 1] = "Auctionator" end
	if Prices.HasTSM() then parts[#parts + 1] = "TSM" end
	if #parts == 0 then return "no auction addon: install Auctionator and scan the auction house" end
	return table.concat(parts, " + ")
end
