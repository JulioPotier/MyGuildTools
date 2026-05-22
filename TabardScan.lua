local AddonName, AddonTable = ...
local L = AddonTable.Localize

MGTTabardHasCache = MGTTabardHasCache or {}

local TABARD_SLOT = GetInventorySlotInfo and GetInventorySlotInfo("TabardSlot") or 19
local CHEST_SLOT = GetInventorySlotInfo and GetInventorySlotInfo("ChestSlot") or 5
local INSPECT_INTERVAL = 1.8
local AUTO_INSPECT_RETRY_INTERVAL = 25

local scanFrame
local scanQueue = {}
local scanIndex = 0
local scanRunning = false
local pendingUnit = nil
local pendingName = nil
local pendingInspectToken = 0
local pendingDeadline = 0
local currentRunNoTabard = {}
local currentRunCannotInspect = {}
AddonTable.PendingTabardAnnounce = AddonTable.PendingTabardAnnounce or nil
local lastAutoScanGroupKeys = {}
local pendingAutoScanQueue = {}
local pendingInspectRetryByKey = {}
local pendingAutoScanAfterCombat = false
local autoScanDebounceTimer
local inspectRetryTicker

function AddonTable.HasPendingTabardAnnounce()
	return AddonTable.PendingTabardAnnounce and #AddonTable.PendingTabardAnnounce > 0
end

local function PrintMissingTabardsToChat(missing)
	for i = 1, #missing do
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cFF0088FF[MyGuildTools]|r " .. missing[i] .. " does not wear a tabard! :p"
		)
	end
end

local function NormalizePlayerKey(name)
	if not name then
		return nil
	end
	if Ambiguate then
		return Ambiguate(name, "none")
	end
	return name
end

local function GetTabardStalkerMinLevel()
	if not MGTConfig then
		return 40
	end
	local level = tonumber(MGTConfig.TabardStalkerMinLevel)
	if not level then
		return 40
	end
	if level < 1 then
		return 1
	end
	if level > 60 then
		return 60
	end
	return level
end

local function IsTabardStalkerGuildOnlyEnabled()
	return not MGTConfig or MGTConfig.TabardStalkerGuildOnly ~= "DISABLED"
end

local function IsTabardStalkerAutoScanEnabled()
	return MGTConfig and MGTConfig.TabardStalkerAutoScan == "ENABLED"
end

local function ShouldScanUnitForTabard(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsConnected(unit) then
		return false
	end

	local minLevel = GetTabardStalkerMinLevel()
	local level = UnitLevel(unit)
	if level and level > 0 and level < minLevel then
		return false
	end

	if IsTabardStalkerGuildOnlyEnabled() then
		local myGuild = GetGuildInfo("player")
		if not myGuild or myGuild == "" then
			return false
		end
		local theirGuild = GetGuildInfo(unit)
		-- Guild unknown is common for distant raid members; still queue them and resolve via inspect.
		if theirGuild and theirGuild ~= myGuild then
			return false
		end
	end

	return true
end

local function ClearTabardScanRunResults()
	wipe(currentRunNoTabard)
	wipe(currentRunCannotInspect)
	AddonTable.PendingTabardAnnounce = nil
end

local function InspectDataAvailable(unit)
	if not unit or not UnitExists(unit) then
		return false
	end
	if GetInventoryItemLink and GetInventoryItemLink(unit, CHEST_SLOT) then
		return true
	end
	if GetInventoryItemTexture(unit, CHEST_SLOT) then
		return true
	end
	return false
end

local function CanInspectUnitNow(unit)
	if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
		return false
	end
	if not CanInspect or not CanInspect(unit) then
		return false
	end
	if CheckInteractDistance and not CheckInteractDistance(unit, 1) then
		return false
	end
	return true
end

local function RecordCannotInspect(unit, displayName)
	local name = displayName or GetUnitName(unit, true) or "?"
	table.insert(currentRunCannotInspect, name)

	local key = NormalizePlayerKey(name)
	if not key then
		return
	end

	lastAutoScanGroupKeys[key] = nil

	if IsTabardStalkerAutoScanEnabled() and unit and UnitExists(unit) then
		pendingInspectRetryByKey[key] = { unit = unit, name = name }
	end
end

local function ClearInspectRetryForKey(key)
	if key then
		pendingInspectRetryByKey[key] = nil
	end
end

local function PrintCannotInspectToChat(names)
	for i = 1, #names do
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cFF0088FF[MyGuildTools]|r " .. string.format(
				L["%s is too far away or cannot be inspected."] or "%s is too far away or cannot be inspected.",
				names[i]
			)
		)
	end
end

function AddonTable.IsInGroupOrRaid()
	if IsInRaid and IsInRaid() then
		return true
	end
	if IsInGroup and IsInGroup() then
		return true
	end
	return false
end

function AddonTable.IsTabardScanRunning()
	return scanRunning
end

local function SetScanStatus(text)
	if AddonTable.OnTabardScanStatus then
		AddonTable.OnTabardScanStatus(text)
	end
end

local RunTabardScan
local lastRunQueuedCount = 0

local function FinishScan()
	scanRunning = false
	pendingUnit = nil
	pendingName = nil
	pendingInspectToken = 0
	pendingDeadline = 0
	scanQueue = {}
	scanIndex = 0

	SetScanStatus("")

	local missing = currentRunNoTabard
	local cannotInspect = currentRunCannotInspect
	ClearTabardScanRunResults()

	if #cannotInspect > 0 then
		PrintCannotInspectToChat(cannotInspect)
		if IsTabardStalkerAutoScanEnabled() then
			print("|cFF0088FF[MyGuildTools]|r " .. (L["Will retry inspection when in range (auto scan)."] or "Will retry inspection when in range (auto scan)."))
		end
	end

	if #missing == 0 and #cannotInspect == 0 and lastRunQueuedCount > 0 then
		AddonTable.PendingTabardAnnounce = nil
		print("|cFF0088FF[MyGuildTools]|r " .. (L["Tabard scan complete. Everyone has a tabard!"] or "Tabard scan complete. Everyone has a tabard!"))
	elseif #missing == 0 and #cannotInspect == 0 and lastRunQueuedCount == 0 then
		AddonTable.PendingTabardAnnounce = nil
		print("|cFF0088FF[MyGuildTools]|r " .. (L["No group members need a tabard scan."] or "No group members need a tabard scan."))
	elseif #missing > 0 then
		AddonTable.PendingTabardAnnounce = missing
		print("|cFF0088FF[MyGuildTools]|r " .. string.format(
			L["Tabard scan complete. %d without tabard (see chat)."] or "Tabard scan complete. %d without tabard (see chat).",
			#missing
		))
		PrintMissingTabardsToChat(missing)
		print("|cFF0088FF[MyGuildTools]|r " .. (L["Click Announce in /say to speak in game."] or "Click Announce in /say to speak in game."))
	else
		AddonTable.PendingTabardAnnounce = nil
	end

	if ClearInspectPlayer then
		ClearInspectPlayer()
	end

	if AddonTable.OnTabardScanFinished then
		AddonTable.OnTabardScanFinished(#missing, #cannotInspect)
	end

	if #pendingAutoScanQueue > 0 then
		local queue = pendingAutoScanQueue
		pendingAutoScanQueue = {}
		if C_Timer and C_Timer.After then
			C_Timer.After(0.15, function()
				RunTabardScan(queue, true)
			end)
		else
			RunTabardScan(queue, true)
		end
	end
end

function AddonTable.AnnounceMissingTabards()
	local missing = AddonTable.PendingTabardAnnounce
	if not missing or #missing == 0 then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		print("|cFF0088FF[MyGuildTools]|r " .. (L["Cannot announce in combat."] or "Cannot announce in combat."))
		return
	end

	for i = 1, #missing do
		SendChatMessage(missing[i] .. " does not wear a tabard! :p", "SAY")
	end

	AddonTable.PendingTabardAnnounce = nil
	print("|cFF0088FF[MyGuildTools]|r " .. (L["Announced missing tabards in /say."] or "Announced missing tabards in /say."))

	if AddonTable.OnTabardScanFinished then
		AddonTable.OnTabardScanFinished(0)
	end
end

local function RecordInspectResult(unit, displayName)
	local name = displayName or GetUnitName(unit, true) or "?"
	local key = NormalizePlayerKey(name)

	if not InspectDataAvailable(unit) then
		RecordCannotInspect(unit, name)
		return
	end

	if IsTabardStalkerGuildOnlyEnabled() then
		local myGuild = GetGuildInfo("player")
		local theirGuild = GetGuildInfo(unit)
		if myGuild and theirGuild and theirGuild ~= myGuild then
			return
		end
		if not theirGuild then
			RecordCannotInspect(unit, name)
			return
		end
	end

	ClearInspectRetryForKey(key)

	local texture = GetInventoryItemTexture(unit, TABARD_SLOT)
	if texture then
		if key then
			MGTTabardHasCache[key] = true
		end
	else
		table.insert(currentRunNoTabard, name)
	end
end

local InspectNext

local function CompletePendingInspect(token)
	if token ~= pendingInspectToken or not scanRunning or not pendingUnit then
		return
	end

	pendingInspectToken = 0
	pendingDeadline = 0

	local unit = pendingUnit
	local name = pendingName
	pendingUnit = nil
	pendingName = nil

	RecordInspectResult(unit, name)

	if ClearInspectPlayer then
		ClearInspectPlayer()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.05, function()
			if scanRunning then
				InspectNext()
			end
		end)
	else
		InspectNext()
	end
end

InspectNext = function()
	scanIndex = scanIndex + 1
	if scanIndex > #scanQueue then
		FinishScan()
		return
	end

	local entry = scanQueue[scanIndex]
	local unit = entry.unit
	local name = entry.name

	if not UnitExists(unit) or not UnitIsConnected(unit) then
		RecordCannotInspect(unit, name)
		InspectNext()
		return
	end

	SetScanStatus(string.format(L["Inspecting %d/%d: %s"], scanIndex, #scanQueue, name))

	-- Do not trust tabard texture until the player is in inspect range.
	if not CanInspectUnitNow(unit) then
		RecordCannotInspect(unit, name)
		InspectNext()
		return
	end

	if GetInventoryItemTexture(unit, TABARD_SLOT) then
		RecordInspectResult(unit, name)
		InspectNext()
		return
	end

	pendingUnit = unit
	pendingName = name
	pendingInspectToken = pendingInspectToken + 1
	local token = pendingInspectToken
	pendingDeadline = GetTime() + INSPECT_INTERVAL

	if ClearInspectPlayer then
		ClearInspectPlayer()
	end

	if NotifyInspect then
		NotifyInspect(unit)
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(INSPECT_INTERVAL, function()
			CompletePendingInspect(token)
		end)
	end
end

function AddonTable.ResetTabardCache()
	wipe(MGTTabardHasCache)
	print("|cFF0088FF[MyGuildTools]|r " .. (L["Tabard cache cleared."] or "Tabard cache cleared."))
end

local function TryAddUnitToScanQueue(queue, seen, unit)
	if not ShouldScanUnitForTabard(unit) then
		return
	end
	local name = GetUnitName(unit, true)
	if not name or seen[name] then
		return
	end
	seen[name] = true

	local key = NormalizePlayerKey(name)
	if key and MGTTabardHasCache[key] then
		return
	end

	table.insert(queue, { unit = unit, name = name })
end

local function BuildManualScanQueue()
	local queue = {}
	local seen = {}

	TryAddUnitToScanQueue(queue, seen, "player")
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do
			TryAddUnitToScanQueue(queue, seen, "raid" .. i)
		end
	else
		for i = 1, 4 do
			TryAddUnitToScanQueue(queue, seen, "party" .. i)
		end
	end

	return queue
end

local function EnumerateGroupUnits(callback)
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do
			callback("raid" .. i)
		end
	else
		for i = 1, 4 do
			callback("party" .. i)
		end
	end
end

local function GetCurrentGroupMemberKeys()
	local keys = {}
	EnumerateGroupUnits(function(unit)
		if unit == "player" or not ShouldScanUnitForTabard(unit) then
			return
		end
		local key = NormalizePlayerKey(GetUnitName(unit, true))
		if key then
			keys[key] = true
		end
	end)
	return keys
end

local function PruneAutoScanTracking()
	local current = GetCurrentGroupMemberKeys()
	for key in pairs(lastAutoScanGroupKeys) do
		if not current[key] then
			lastAutoScanGroupKeys[key] = nil
		end
	end
end

local function CollectAutoScanNewcomers()
	local queue = {}
	local seen = {}

	EnumerateGroupUnits(function(unit)
		if unit == "player" or not ShouldScanUnitForTabard(unit) then
			return
		end
		local name = GetUnitName(unit, true)
		if not name or seen[name] then
			return
		end
		seen[name] = true

		local key = NormalizePlayerKey(name)
		if not key or MGTTabardHasCache[key] or lastAutoScanGroupKeys[key] then
			return
		end

		lastAutoScanGroupKeys[key] = true
		table.insert(queue, { unit = unit, name = name })
	end)

	return queue
end

RunTabardScan = function(queue, quiet)
	if scanRunning then
		return false
	end
	if not queue or #queue == 0 then
		if not quiet then
			print("|cFF0088FF[MyGuildTools]|r " .. (L["No group members need a tabard scan."] or "No group members need a tabard scan."))
			if AddonTable.OnTabardScanFinished then
				AddonTable.OnTabardScanFinished()
			end
		end
		return false
	end

	scanQueue = queue
	lastRunQueuedCount = #queue
	ClearTabardScanRunResults()
	scanIndex = 0
	pendingInspectToken = 0
	pendingDeadline = 0
	scanRunning = true

	if AddonTable.OnTabardScanStarted then
		AddonTable.OnTabardScanStarted()
	end

	SetScanStatus(string.format(L["Inspecting %d/%d..."], 0, #scanQueue))
	InspectNext()
	return true
end

function AddonTable.StartTabardScan()
	if not AddonTable.IsInGroupOrRaid() then
		print("|cFF0088FF[MyGuildTools]|r " .. (L["You must be in a party or raid."] or "You must be in a party or raid."))
		return
	end
	RunTabardScan(BuildManualScanQueue(), false)
end

local function ScheduleAutoScanCheck()
	if not IsTabardStalkerAutoScanEnabled() then
		return
	end
	if C_Timer and C_Timer.After then
		if autoScanDebounceTimer and autoScanDebounceTimer.Cancel then
			autoScanDebounceTimer:Cancel()
		end
		autoScanDebounceTimer = C_Timer.After(0.6, function()
			autoScanDebounceTimer = nil
			AddonTable.ProcessAutoScanOnGroupChange()
		end)
	else
		AddonTable.ProcessAutoScanOnGroupChange()
	end
end

function AddonTable.ProcessAutoScanOnGroupChange()
	if not IsTabardStalkerAutoScanEnabled() then
		return
	end

	if not AddonTable.IsInGroupOrRaid() then
		wipe(lastAutoScanGroupKeys)
		wipe(pendingInspectRetryByKey)
		pendingAutoScanAfterCombat = false
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		pendingAutoScanAfterCombat = true
		return
	end

	pendingAutoScanAfterCombat = false
	PruneAutoScanTracking()

	local newcomers = CollectAutoScanNewcomers()
	if #newcomers == 0 then
		return
	end

	if scanRunning then
		for i = 1, #newcomers do
			table.insert(pendingAutoScanQueue, newcomers[i])
		end
		return
	end

	RunTabardScan(newcomers, true)
end

local function FindGroupUnitByKey(playerKey)
	if not playerKey then
		return nil
	end
	local found
	EnumerateGroupUnits(function(unit)
		if ShouldScanUnitForTabard(unit) and NormalizePlayerKey(GetUnitName(unit, true)) == playerKey then
			found = unit
		end
	end)
	return found
end

local function BuildInspectRetryQueue()
	local queue = {}
	for key, entry in pairs(pendingInspectRetryByKey) do
		local unit = FindGroupUnitByKey(key) or entry.unit
		if unit and UnitExists(unit) and ShouldScanUnitForTabard(unit) and CanInspectUnitNow(unit) then
			entry.unit = unit
			table.insert(queue, { unit = unit, name = entry.name, key = key })
		elseif not unit or not UnitExists(unit) then
			pendingInspectRetryByKey[key] = nil
		end
	end
	return queue
end

function AddonTable.ProcessInspectRetryQueue()
	if not IsTabardStalkerAutoScanEnabled() then
		return
	end
	if scanRunning or not AddonTable.IsInGroupOrRaid() then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		return
	end

	local queue = BuildInspectRetryQueue()
	if #queue == 0 then
		return
	end

	RunTabardScan(queue, true)
end

local function EnsureInspectRetryTicker()
	if not C_Timer or not C_Timer.NewTicker then
		return
	end
	if inspectRetryTicker and inspectRetryTicker.Cancel then
		return
	end
	inspectRetryTicker = C_Timer.NewTicker(AUTO_INSPECT_RETRY_INTERVAL, function()
		if IsTabardStalkerAutoScanEnabled() then
			AddonTable.ProcessInspectRetryQueue()
		end
	end)
end

EnsureInspectRetryTicker()

scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("INSPECT_READY")
scanFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
scanFrame:RegisterEvent("RAID_ROSTER_UPDATE")
scanFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
scanFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
scanFrame:SetScript("OnEvent", function(_, event)
	if event == "INSPECT_READY" then
		if not scanRunning or not pendingUnit or pendingInspectToken == 0 then
			return
		end
		CompletePendingInspect(pendingInspectToken)
		return
	end

	if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		ScheduleAutoScanCheck()
	elseif event == "PLAYER_REGEN_ENABLED" and pendingAutoScanAfterCombat then
		ScheduleAutoScanCheck()
	end
end)

scanFrame:SetScript("OnUpdate", function()
	if not scanRunning or not pendingUnit or pendingInspectToken == 0 or pendingDeadline == 0 then
		return
	end
	if GetTime() >= pendingDeadline then
		CompletePendingInspect(pendingInspectToken)
	end
end)
