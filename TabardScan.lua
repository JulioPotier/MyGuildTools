local AddonName, AddonTable = ...
local L = AddonTable.Localize

MGTTabardHasCache = MGTTabardHasCache or {}

local TABARD_SLOT = GetInventorySlotInfo and GetInventorySlotInfo("TabardSlot") or 19
local INSPECT_INTERVAL = 1.8

local scanFrame
local scanQueue = {}
local scanIndex = 0
local scanRunning = false
local pendingUnit = nil
local pendingName = nil
local pendingInspectToken = 0
local pendingDeadline = 0
local currentRunNoTabard = {}
AddonTable.PendingTabardAnnounce = AddonTable.PendingTabardAnnounce or nil

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
	currentRunNoTabard = {}

	if #missing == 0 then
		AddonTable.PendingTabardAnnounce = nil
		print("|cFF0088FF[MyGuildTools]|r " .. (L["Tabard scan complete. Everyone has a tabard!"] or "Tabard scan complete. Everyone has a tabard!"))
	else
		AddonTable.PendingTabardAnnounce = missing
		print("|cFF0088FF[MyGuildTools]|r " .. string.format(
			L["Tabard scan complete. %d without tabard (see chat)."] or "Tabard scan complete. %d without tabard (see chat).",
			#missing
		))
		PrintMissingTabardsToChat(missing)
		print("|cFF0088FF[MyGuildTools]|r " .. (L["Click Announce in /say to speak in game."] or "Click Announce in /say to speak in game."))
	end

	if ClearInspectPlayer then
		ClearInspectPlayer()
	end

	if AddonTable.OnTabardScanFinished then
		AddonTable.OnTabardScanFinished(#missing)
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
	local texture = GetInventoryItemTexture(unit, TABARD_SLOT)
	local key = NormalizePlayerKey(displayName or GetUnitName(unit, true))

	if texture then
		if key then
			MGTTabardHasCache[key] = true
		end
	else
		table.insert(currentRunNoTabard, displayName or GetUnitName(unit, true) or key or "?")
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
		InspectNext()
		return
	end

	SetScanStatus(string.format(L["Inspecting %d/%d: %s"], scanIndex, #scanQueue, name))

	if GetInventoryItemTexture(unit, TABARD_SLOT) then
		RecordInspectResult(unit, name)
		InspectNext()
		return
	end

	if not CanInspect or not CanInspect(unit) or (CheckInteractDistance and not CheckInteractDistance(unit, 1)) then
		table.insert(currentRunNoTabard, name)
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

function AddonTable.StartTabardScan()
	if scanRunning then
		return
	end
	if not AddonTable.IsInGroupOrRaid() then
		print("|cFF0088FF[MyGuildTools]|r " .. (L["You must be in a party or raid."] or "You must be in a party or raid."))
		return
	end

	scanQueue = {}
	currentRunNoTabard = {}
	AddonTable.PendingTabardAnnounce = nil
	scanIndex = 0
	pendingInspectToken = 0
	pendingDeadline = 0

	local seen = {}
	local function addUnit(unit)
		if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsConnected(unit) then
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

		table.insert(scanQueue, { unit = unit, name = name })
	end

	addUnit("player")
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do
			addUnit("raid" .. i)
		end
	else
		for i = 1, 4 do
			addUnit("party" .. i)
		end
	end

	if #scanQueue == 0 then
		print("|cFF0088FF[MyGuildTools]|r " .. (L["No group members need a tabard scan."] or "No group members need a tabard scan."))
		if AddonTable.OnTabardScanFinished then
			AddonTable.OnTabardScanFinished()
		end
		return
	end

	scanRunning = true
	if AddonTable.OnTabardScanStarted then
		AddonTable.OnTabardScanStarted()
	end

	SetScanStatus(string.format(L["Inspecting %d/%d..."], 0, #scanQueue))
	InspectNext()
end

scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("INSPECT_READY")
scanFrame:SetScript("OnEvent", function(_, event)
	if event ~= "INSPECT_READY" or not scanRunning or not pendingUnit or pendingInspectToken == 0 then
		return
	end
	CompletePendingInspect(pendingInspectToken)
end)

scanFrame:SetScript("OnUpdate", function()
	if not scanRunning or not pendingUnit or pendingInspectToken == 0 or pendingDeadline == 0 then
		return
	end
	if GetTime() >= pendingDeadline then
		CompletePendingInspect(pendingInspectToken)
	end
end)
