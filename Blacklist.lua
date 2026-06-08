local AddonName, AddonTable = ...
local L = AddonTable.Localize

local BLACKLIST_MAX_ENTRIES = 64
local ALERT_COOLDOWN_SECONDS = 30
local BLACKLIST_SUFFIXES = { "five", "four", "three", "two", "jr" }

local ALERT_SOUND = (SOUNDKIT and SOUNDKIT.RaidWarning) or 8959

local HOMOGLYPH_MAP = {
	["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["å"] = "a", ["ā"] = "a",
	["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e", ["ē"] = "e",
	["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i", ["ī"] = "i",
	["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o", ["ō"] = "o", ["ø"] = "o",
	["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u", ["ū"] = "u",
	["ý"] = "y", ["ÿ"] = "y",
	["ñ"] = "n", ["ç"] = "c",
	["0"] = "o", ["1"] = "l", ["3"] = "e", ["5"] = "s",
}

local blacklistFrame
local recentAlerts = {}
local sendChatHookInstalled = false
local whisperFilterInstalled = false
local originalSendChatMessage

local ALERT_LABELS = {
	whisper_in = function() return L["Blacklist context whisper in"] end,
	whisper_out = function() return L["Blacklist context whisper out"] end,
	group = function() return L["Blacklist context group"] end,
	invite = function() return L["Blacklist context invite"] end,
	trade_request = function() return L["Blacklist context trade request"] end,
	trade_show = function() return L["Blacklist context trade"] end,
	mouseover = function() return L["Blacklist context mouseover"] end,
	target = function() return L["Blacklist context target"] end,
}

local function TrimString(s)
	if type(s) ~= "string" then
		return ""
	end
	if strtrim then
		return strtrim(s)
	end
	return s:match("^%s*(.-)%s*$") or ""
end

local function NormalizePlayerName(name)
	name = TrimString(name or "")
	if name == "" then
		return ""
	end
	if Ambiguate then
		name = Ambiguate(name, "none") or name
	end
	return name:match("^([^%-]+)") or name
end

local function NormalizeHomoglyphs(name)
	local lower = string.lower(name)
	for from, to in pairs(HOMOGLYPH_MAP) do
		lower = lower:gsub(from, to)
	end
	return lower
end

local function StripBlacklistSuffix(core)
	for _, suffix in ipairs(BLACKLIST_SUFFIXES) do
		if #core > #suffix and core:sub(-#suffix) == suffix then
			return core:sub(1, -#suffix - 1)
		end
	end
	return core
end

local function GetMatchCore(name)
	local core = NormalizeHomoglyphs(NormalizePlayerName(name))
	if core == "" then
		return ""
	end
	return StripBlacklistSuffix(core)
end

local function Levenshtein(a, b)
	local lenA, lenB = #a, #b
	if lenA == 0 then
		return lenB
	end
	if lenB == 0 then
		return lenA
	end

	local row = {}
	for j = 0, lenB do
		row[j] = j
	end

	for i = 1, lenA do
		local prev = row[0]
		row[0] = i
		for j = 1, lenB do
			local cost = (a:byte(i) == b:byte(j)) and 0 or 1
			local insertCost = row[j] + 1
			local deleteCost = row[j - 1] + 1
			local replaceCost = prev + cost
			prev = row[j]
			row[j] = math.min(insertCost, deleteCost, replaceCost)
		end
	end
	return row[lenB]
end

local function GetFuzzyMaxDistance(coreA, coreB)
	local maxLen = math.max(#coreA, #coreB)
	local configured = tonumber(MGTConfig and MGTConfig.BlacklistFuzzyMaxDistance) or 1
	if maxLen > 8 then
		return math.max(configured, 2)
	end
	return configured
end

local function NamesFuzzyMatch(nameA, nameB)
	local coreA = GetMatchCore(nameA)
	local coreB = GetMatchCore(nameB)
	if coreA == "" or coreB == "" then
		return false
	end
	if coreA == coreB then
		return true
	end
	if MGTConfig and MGTConfig.BlacklistFuzzyMatch == "DISABLED" then
		return false
	end
	return Levenshtein(coreA, coreB) <= GetFuzzyMaxDistance(coreA, coreB)
end

local function ConfigEnabled(key, defaultEnabled)
	if not MGTConfig then
		return defaultEnabled
	end
	local value = MGTConfig[key]
	if value == nil then
		return defaultEnabled
	end
	return value == "ENABLED"
end

function AddonTable.EnsureMGTBlacklistConfig()
	MGTConfig = MGTConfig or {}
	if MGTConfig.BlacklistEnabled == nil then
		MGTConfig.BlacklistEnabled = "DISABLED"
	end
	if type(MGTConfig.BlacklistNames) ~= "table" then
		MGTConfig.BlacklistNames = {}
	end
	if MGTConfig.BlacklistAlertWhisper == nil then
		MGTConfig.BlacklistAlertWhisper = "ENABLED"
	end
	if MGTConfig.BlacklistAlertGroup == nil then
		MGTConfig.BlacklistAlertGroup = "ENABLED"
	end
	if MGTConfig.BlacklistAlertTrade == nil then
		MGTConfig.BlacklistAlertTrade = "ENABLED"
	end
	if MGTConfig.BlacklistAlertProximity == nil then
		MGTConfig.BlacklistAlertProximity = "ENABLED"
	end
	if MGTConfig.BlacklistPlaySound == nil then
		MGTConfig.BlacklistPlaySound = "ENABLED"
	end
	if MGTConfig.BlacklistAutoBlock == nil then
		MGTConfig.BlacklistAutoBlock = "DISABLED"
	end
	if MGTConfig.BlacklistFuzzyMatch == nil then
		MGTConfig.BlacklistFuzzyMatch = "ENABLED"
	end
	if MGTConfig.BlacklistFuzzyMaxDistance == nil then
		MGTConfig.BlacklistFuzzyMaxDistance = 1
	end
end

function AddonTable.IsBlacklistActive()
	AddonTable.EnsureMGTBlacklistConfig()
	return MGTConfig.BlacklistEnabled == "ENABLED"
end

function AddonTable.SetBlacklistActive(enabled)
	AddonTable.EnsureMGTBlacklistConfig()
	MGTConfig.BlacklistEnabled = enabled and "ENABLED" or "DISABLED"
	AddonTable.RefreshBlacklistWatcher()
end

function AddonTable.IsBlacklistAutoBlockEnabled()
	return ConfigEnabled("BlacklistAutoBlock", false)
end

function AddonTable.IsBlacklistAlertEnabled(alertKey)
	local map = {
		whisper = "BlacklistAlertWhisper",
		group = "BlacklistAlertGroup",
		trade = "BlacklistAlertTrade",
		proximity = "BlacklistAlertProximity",
	}
	local configKey = map[alertKey]
	if not configKey then
		return true
	end
	return ConfigEnabled(configKey, true)
end

function AddonTable.GetBlacklistNames()
	AddonTable.EnsureMGTBlacklistConfig()
	return MGTConfig.BlacklistNames
end

function AddonTable.IsPlayerBlacklisted(name)
	AddonTable.EnsureMGTBlacklistConfig()
	name = NormalizePlayerName(name)
	if name == "" then
		return false
	end
	for _, entry in ipairs(MGTConfig.BlacklistNames) do
		if NamesFuzzyMatch(name, entry) then
			return true, entry
		end
	end
	return false
end

function AddonTable.IsBlacklistNameDuplicate(name)
	local matched = AddonTable.IsPlayerBlacklisted(name)
	return matched
end

function AddonTable.AddBlacklistName(name)
	AddonTable.EnsureMGTBlacklistConfig()
	name = NormalizePlayerName(name)
	if name == "" then
		return false, "empty"
	end
	if #MGTConfig.BlacklistNames >= BLACKLIST_MAX_ENTRIES then
		return false, "full"
	end
	if AddonTable.IsBlacklistNameDuplicate(name) then
		return false, "duplicate"
	end
	MGTConfig.BlacklistNames[#MGTConfig.BlacklistNames + 1] = name
	return true
end

function AddonTable.RemoveBlacklistName(index)
	AddonTable.EnsureMGTBlacklistConfig()
	if type(index) ~= "number" or index < 1 or index > #MGTConfig.BlacklistNames then
		return false
	end
	table.remove(MGTConfig.BlacklistNames, index)
	return true
end

local function ShouldPlayBlacklistSound()
	return ConfigEnabled("BlacklistPlaySound", true)
end

local function GetAlertLabel(alertType)
	local fn = ALERT_LABELS[alertType]
	return fn and fn() or alertType
end

local function CanAlertAgain(playerKey, alertType)
	local now = GetTime and GetTime() or 0
	recentAlerts[playerKey] = recentAlerts[playerKey] or {}
	local last = recentAlerts[playerKey][alertType]
	if last and (now - last) < ALERT_COOLDOWN_SECONDS then
		return false
	end
	recentAlerts[playerKey][alertType] = now
	return true
end

function AddonTable.ReportBlacklistAlert(displayName, matchedEntry, alertType)
	displayName = displayName or matchedEntry or "?"
	matchedEntry = matchedEntry or displayName
	local context = GetAlertLabel(alertType or "group")
	local msg = string.format(L["Blacklist alert: %s"], displayName)
	if matchedEntry ~= displayName then
		msg = msg .. " " .. string.format(L["Blacklist alert matched entry"], matchedEntry)
	end
	msg = msg .. " (" .. context .. ")"
	print("|cFFFF0000[MyGuildTools Blacklist]|r " .. msg)
	if ShouldPlayBlacklistSound() then
		PlaySound(ALERT_SOUND, "Master")
	end
end

local function CheckAndAlert(name, alertType, alertCategory)
	if not AddonTable.IsBlacklistActive() then
		return false
	end
	alertCategory = alertCategory or alertType
	if alertType == "whisper_in" or alertType == "whisper_out" then
		if not AddonTable.IsBlacklistAlertEnabled("whisper") then
			return false
		end
	elseif alertType == "invite" or alertType == "group" then
		if not AddonTable.IsBlacklistAlertEnabled("group") then
			return false
		end
	elseif alertType == "trade_request" or alertType == "trade_show" then
		if not AddonTable.IsBlacklistAlertEnabled("trade") then
			return false
		end
	elseif alertType == "mouseover" or alertType == "target" then
		if not AddonTable.IsBlacklistAlertEnabled("proximity") then
			return false
		end
	end

	local matched, entry = AddonTable.IsPlayerBlacklisted(name)
	if not matched then
		return false
	end

	local playerKey = GetMatchCore(name)
	if playerKey == "" then
		playerKey = NormalizePlayerName(name)
	end
	if not CanAlertAgain(playerKey, alertCategory) then
		return true
	end

	local displayName = NormalizePlayerName(name)
	AddonTable.ReportBlacklistAlert(displayName, entry, alertType)
	return true
end

local function ShouldBlockInteraction()
	return AddonTable.IsBlacklistActive() and AddonTable.IsBlacklistAutoBlockEnabled()
end

local function DeclineBlacklistPartyInvite()
	if DeclineGroup then
		DeclineGroup()
	end
	if StaticPopup_Hide then
		StaticPopup_Hide("PARTY_INVITE")
		StaticPopup_Hide("PARTY_INVITE_XREALM")
	end
end

local function DeclineBlacklistTrade()
	if CancelTrade then
		CancelTrade()
	end
end

local function InstallWhisperFilter()
	if whisperFilterInstalled then
		return
	end
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(_, _, message, sender)
		if not AddonTable.IsBlacklistActive() then
			return false
		end
		local matched, entry = AddonTable.IsPlayerBlacklisted(sender)
		if not matched then
			return false
		end
		if AddonTable.IsBlacklistAlertEnabled("whisper") then
			local playerKey = GetMatchCore(sender)
			if CanAlertAgain(playerKey, "whisper_in") then
				AddonTable.ReportBlacklistAlert(NormalizePlayerName(sender), entry, "whisper_in")
			end
		end
		if ShouldBlockInteraction() then
			return true
		end
		return false
	end)
	whisperFilterInstalled = true
end

local function InstallSendChatMessageHook()
	if sendChatHookInstalled then
		return
	end
	originalSendChatMessage = SendChatMessage
	SendChatMessage = function(message, chatType, languageID, target, ...)
		if AddonTable.IsBlacklistActive() and target and chatType then
			local chat = string.upper(chatType)
			if chat == "WHISPER" then
				local matched, entry = AddonTable.IsPlayerBlacklisted(target)
				if matched then
					if AddonTable.IsBlacklistAlertEnabled("whisper") then
						local playerKey = GetMatchCore(target)
						if CanAlertAgain(playerKey, "whisper_out") then
							AddonTable.ReportBlacklistAlert(NormalizePlayerName(target), entry, "whisper_out")
						end
					end
					if ShouldBlockInteraction() then
						return
					end
				end
			end
		end
		return originalSendChatMessage(message, chatType, languageID, target, ...)
	end
	sendChatHookInstalled = true
end

local function GetTradePartnerName()
	if UnitName then
		local npcName = UnitName("NPC")
		if npcName and npcName ~= "" and UnitIsPlayer and UnitIsPlayer("NPC") then
			return npcName
		end
		local targetName = UnitName("target")
		if targetName and targetName ~= "" and UnitIsPlayer and UnitIsPlayer("target") then
			return targetName
		end
	end
	return nil
end

local function ScanGroupForBlacklist()
	if not AddonTable.IsBlacklistActive() or not AddonTable.IsBlacklistAlertEnabled("group") then
		return
	end
	local units = {}
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do
			units[#units + 1] = "raid" .. i
		end
	elseif IsInGroup and IsInGroup() then
		units[#units + 1] = "player"
		for i = 1, 4 do
			units[#units + 1] = "party" .. i
		end
	else
		return
	end
	for _, unit in ipairs(units) do
		if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
			local name = GetUnitName(unit, true)
			if name then
				CheckAndAlert(name, "group", "group")
			end
		end
	end
end

local function CheckUnitToken(unit, alertType)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
		return
	end
	local name = GetUnitName(unit, true)
	if name then
		CheckAndAlert(name, alertType, alertType)
	end
end

local function OnPartyInviteRequest(inviterName)
	if not AddonTable.IsBlacklistActive() then
		return
	end
	local matched = CheckAndAlert(inviterName, "invite", "invite")
	if matched and ShouldBlockInteraction() then
		DeclineBlacklistPartyInvite()
	end
end

local function OnTradeRequest()
	if not AddonTable.IsBlacklistActive() then
		return
	end
	local matched = false
	local name = GetTradePartnerName()
	if name then
		matched = CheckAndAlert(name, "trade_request", "trade_request")
	else
		for _, unit in ipairs({ "target", "mouseover" }) do
			if UnitExists(unit) and UnitIsPlayer(unit) then
				local unitName = GetUnitName(unit, true)
				if unitName and CheckAndAlert(unitName, "trade_request", "trade_request") then
					matched = true
					break
				end
			end
		end
	end
	if matched and ShouldBlockInteraction() then
		if DeclineTrade then
			DeclineTrade()
		end
	end
end

local function OnTradeShow()
	if not AddonTable.IsBlacklistActive() then
		return
	end
	local name = GetTradePartnerName()
	if not name then
		return
	end
	local matched = CheckAndAlert(name, "trade_show", "trade_show")
	if matched and ShouldBlockInteraction() then
		DeclineBlacklistTrade()
	end
end

local function BlacklistEventHandler(self, event, ...)
	if not AddonTable.IsBlacklistActive() then
		return
	end
	if event == "PARTY_INVITE_REQUEST" then
		OnPartyInviteRequest(...)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
		ScanGroupForBlacklist()
	elseif event == "TRADE_REQUEST" then
		OnTradeRequest()
	elseif event == "TRADE_SHOW" then
		OnTradeShow()
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		CheckUnitToken("mouseover", "mouseover")
	elseif event == "PLAYER_TARGET_CHANGED" then
		CheckUnitToken("target", "target")
	end
end

local WATCHER_EVENTS = {
	"PARTY_INVITE_REQUEST",
	"GROUP_ROSTER_UPDATE",
	"RAID_ROSTER_UPDATE",
	"TRADE_REQUEST",
	"TRADE_SHOW",
	"UPDATE_MOUSEOVER_UNIT",
	"PLAYER_TARGET_CHANGED",
}

function AddonTable.RefreshBlacklistWatcher()
	AddonTable.EnsureMGTBlacklistConfig()
	if not blacklistFrame then
		blacklistFrame = CreateFrame("Frame")
		blacklistFrame:SetScript("OnEvent", BlacklistEventHandler)
	end

	InstallWhisperFilter()
	InstallSendChatMessageHook()

	if AddonTable.IsBlacklistActive() then
		for _, eventName in ipairs(WATCHER_EVENTS) do
			blacklistFrame:RegisterEvent(eventName)
		end
	else
		for _, eventName in ipairs(WATCHER_EVENTS) do
			blacklistFrame:UnregisterEvent(eventName)
		end
	end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon == AddonName then
		AddonTable.EnsureMGTBlacklistConfig()
	elseif event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == AddonName) then
		AddonTable.RefreshBlacklistWatcher()
	end
end)
