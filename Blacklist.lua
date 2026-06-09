local AddonName, AddonTable = ...
local L = AddonTable.Localize

local ALERT_COOLDOWN_SECONDS = 30
local NAMEPLATE_SCAN_INTERVAL = 5
local NAMEPLATE_UNIT_MAX = 40
local NAMEPLATE_SCAN_CVARS = {
	"nameplateShowAll",
	"nameplateShowFriends",
	"nameplateShowEnemies",
}
local BLACKLIST_SUFFIXES = { "five", "four", "three", "two", "jr" }

local ALERT_SOUND = (SOUNDKIT and SOUNDKIT.RaidWarning) or 8959
local RAID_SCREEN_ALERT_HOLD = 5
local RAID_FLASH_DURATION = 0.75
local RAID_FLASH_MAX_ALPHA = 0.42

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

local IGNORE_LIST_MAX = 50

local blacklistFrame
local nameplateScanTicker
local ignoreListSyncFrame
local blacklistFlashFrame
local recentAlerts = {}
local ignoreListSyncApplying = false
local ignoreListSyncSuppressUserAlerts = false
local pendingLoginIgnoreSync = false
local ignoreListAltWasSynced = false
local LOGIN_IGNORE_SYNC_DELAYS = { 0.5, 1.5, 3, 6, 10 }
local whisperHooksInstalled = false
local originalSendChatMessage
local originalCChatInfoSendChatMessage

local ALERT_LABELS = {
	whisper_out = function() return L["Blacklist context whisper out"] end,
	group = function() return L["Blacklist context group"] end,
	invite = function() return L["Blacklist context invite"] end,
	trade_request = function() return L["Blacklist context trade request"] end,
	trade_show = function() return L["Blacklist context trade"] end,
	mouseover = function() return L["Blacklist context mouseover"] end,
	target = function() return L["Blacklist context target"] end,
	nameplate = function() return L["Blacklist context nameplate"] end,
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

local function GetNumIgnores()
	if C_FriendList and C_FriendList.GetNumIgnores then
		return C_FriendList.GetNumIgnores() or 0
	end
	if GetNumIgnores then
		return GetNumIgnores() or 0
	end
	return 0
end

local function GetIgnoreNameRaw(index)
	if type(index) ~= "number" or index < 1 then
		return nil
	end
	local name
	if C_FriendList and C_FriendList.GetIgnoreName then
		name = C_FriendList.GetIgnoreName(index)
	elseif GetIgnoreName then
		name = GetIgnoreName(index)
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

local function AddIgnoreName(name)
	if type(name) ~= "string" or name == "" then
		return
	end
	if C_FriendList and C_FriendList.AddIgnore then
		C_FriendList.AddIgnore(name)
	elseif AddIgnore then
		AddIgnore(name)
	end
end

local function RemoveIgnoreAtIndex(index)
	if C_FriendList and C_FriendList.DelIgnoreByIndex then
		C_FriendList.DelIgnoreByIndex(index)
	elseif DelIgnoreByIndex then
		DelIgnoreByIndex(index)
	end
end

local function GetCurrentPlayerKey()
	if UnitFullName then
		local fullName = UnitFullName("player")
		if type(fullName) == "string" and fullName ~= "" then
			return fullName
		end
	end
	return UnitName and UnitName("player") or ""
end

local function CollectNameVariants(name)
	local variants = {}
	local seen = {}
	local function add(value)
		if type(value) ~= "string" then
			return
		end
		value = TrimString(value)
		if value == "" or seen[value] then
			return
		end
		seen[value] = true
		variants[#variants + 1] = value
	end

	add(name)
	if Ambiguate then
		add(Ambiguate(name, "none"))
		add(Ambiguate(name, "short"))
		add(Ambiguate(name, "server"))
	end
	add(name:match("^([^%-]+)"))
	return variants
end

local function IgnoreNamesMatch(nameA, nameB)
	if not nameA or not nameB then
		return false
	end
	for _, variantA in ipairs(CollectNameVariants(nameA)) do
		for _, variantB in ipairs(CollectNameVariants(nameB)) do
			if string.lower(variantA) == string.lower(variantB) then
				return true
			end
		end
	end
	return false
end

local function IsNameInIgnoreNameList(name, nameList)
	for _, entry in ipairs(nameList) do
		if IgnoreNamesMatch(name, entry) then
			return true
		end
	end
	return false
end

local function ReadLocalIgnoreList()
	local names = {}
	for i = 1, GetNumIgnores() do
		local name = GetIgnoreNameRaw(i)
		if name then
			names[#names + 1] = name
		end
	end
	return names
end

local function IsIgnoreListSyncEnabled()
	return ConfigEnabled("IgnoreListSyncEnabled", false)
end

local function GetIgnoreListSyncMainKey()
	AddonTable.EnsureMGTBlacklistConfig()
	return MGTConfig.IgnoreListSyncMain
end

function AddonTable.IsCurrentCharacterIgnoreListMain()
	AddonTable.EnsureMGTBlacklistConfig()
	local mainKey = MGTConfig.IgnoreListSyncMain
	if type(mainKey) ~= "string" or mainKey == "" then
		return true
	end
	return GetCurrentPlayerKey() == mainKey
end

function AddonTable.IsCurrentCharacterIgnoreListSyncAlt()
	AddonTable.EnsureMGTBlacklistConfig()
	if not IsIgnoreListSyncEnabled() then
		return false
	end
	local mainKey = MGTConfig.IgnoreListSyncMain
	if type(mainKey) ~= "string" or mainKey == "" then
		return false
	end
	return GetCurrentPlayerKey() ~= mainKey
end

function AddonTable.GetIgnoreListSyncMainDisplayName()
	local mainKey = GetIgnoreListSyncMainKey()
	if type(mainKey) ~= "string" or mainKey == "" then
		return "?"
	end
	return NormalizePlayerName(mainKey)
end

local function GetAccountIgnoreNamesForApply()
	AddonTable.EnsureMGTBlacklistConfig()
	local accountNames = MGTConfig.AccountIgnoreNames or {}
	local applyNames = {}
	local overflow = #accountNames > IGNORE_LIST_MAX
	for i = 1, math.min(#accountNames, IGNORE_LIST_MAX) do
		applyNames[#applyNames + 1] = accountNames[i]
	end
	return applyNames, overflow
end

local function UpdateAccountIgnoreListFromLocal()
	AddonTable.EnsureMGTBlacklistConfig()
	MGTConfig.AccountIgnoreNames = ReadLocalIgnoreList()
	MGTConfig.AccountIgnoreNamesRevision = (tonumber(MGTConfig.AccountIgnoreNamesRevision) or 0) + 1
end

local function ShouldSyncIgnoreListForCharacter()
	if not IsIgnoreListSyncEnabled() then
		return false
	end
	if AddonTable.IsCurrentCharacterIgnoreListSyncAlt() then
		return true
	end
	return AddonTable.IsCurrentCharacterIgnoreListMain()
		and ConfigEnabled("IgnoreListSyncLoginApply", true)
end

local function IsLocalIgnoreListSynced()
	local applyNames = GetAccountIgnoreNamesForApply()
	local localNames = ReadLocalIgnoreList()
	for _, accountName in ipairs(applyNames) do
		if not IsNameInIgnoreNameList(accountName, localNames) then
			return false
		end
	end
	for _, localName in ipairs(localNames) do
		if not IsNameInIgnoreNameList(localName, applyNames) then
			return false
		end
	end
	return true
end

local function FinishIgnoreListSyncApply()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.75, function()
			ignoreListSyncApplying = false
			ignoreListSyncSuppressUserAlerts = false
			if IsLocalIgnoreListSynced() then
				pendingLoginIgnoreSync = false
				if AddonTable.IsCurrentCharacterIgnoreListSyncAlt() then
					ignoreListAltWasSynced = true
				end
			end
			if AddonTable.RefreshIgnoreListSyncUI then
				AddonTable.RefreshIgnoreListSyncUI()
			end
		end)
	else
		ignoreListSyncApplying = false
		ignoreListSyncSuppressUserAlerts = false
		if IsLocalIgnoreListSynced() then
			pendingLoginIgnoreSync = false
			if AddonTable.IsCurrentCharacterIgnoreListSyncAlt() then
				ignoreListAltWasSynced = true
			end
		end
	end
end

local function ApplyAccountIgnoreListToLocal()
	if ignoreListSyncApplying then
		return false
	end
	ignoreListSyncApplying = true
	ignoreListSyncSuppressUserAlerts = true

	local applyNames, overflow = GetAccountIgnoreNamesForApply()

	for i = GetNumIgnores(), 1, -1 do
		local localName = GetIgnoreNameRaw(i)
		if localName and not IsNameInIgnoreNameList(localName, applyNames) then
			RemoveIgnoreAtIndex(i)
		end
	end

	for _, accountName in ipairs(applyNames) do
		if not IsNameInIgnoreNameList(accountName, ReadLocalIgnoreList()) then
			if GetNumIgnores() < IGNORE_LIST_MAX then
				AddIgnoreName(accountName)
			else
				overflow = true
			end
		end
	end

	FinishIgnoreListSyncApply()
	return overflow
end

local function RunIgnoreListSyncAttempt()
	if not ShouldSyncIgnoreListForCharacter() then
		pendingLoginIgnoreSync = false
		return false
	end
	if IsLocalIgnoreListSynced() then
		pendingLoginIgnoreSync = false
		if AddonTable.IsCurrentCharacterIgnoreListSyncAlt() then
			ignoreListAltWasSynced = true
		end
		if AddonTable.RefreshIgnoreListSyncUI then
			AddonTable.RefreshIgnoreListSyncUI()
		end
		return true
	end
	ApplyAccountIgnoreListToLocal()
	return IsLocalIgnoreListSynced()
end

local function ScheduleLoginIgnoreListSync()
	if not ShouldSyncIgnoreListForCharacter() then
		pendingLoginIgnoreSync = false
		return
	end
	pendingLoginIgnoreSync = true
	if not C_Timer or not C_Timer.After then
		RunIgnoreListSyncAttempt()
		return
	end
	for _, delay in ipairs(LOGIN_IGNORE_SYNC_DELAYS) do
		C_Timer.After(delay, function()
			if pendingLoginIgnoreSync then
				RunIgnoreListSyncAttempt()
			end
		end)
	end
end

local function SyncIgnoreListOnLogin()
	ignoreListAltWasSynced = false
	ScheduleLoginIgnoreListSync()
end

local function OnIgnoreListUpdate()
	if not IsIgnoreListSyncEnabled() then
		return
	end

	if pendingLoginIgnoreSync and ShouldSyncIgnoreListForCharacter() then
		RunIgnoreListSyncAttempt()
	end

	if ignoreListSyncApplying or ignoreListSyncSuppressUserAlerts then
		return
	end

	if AddonTable.IsCurrentCharacterIgnoreListMain() then
		UpdateAccountIgnoreListFromLocal()
		if AddonTable.RefreshIgnoreListSyncUI then
			AddonTable.RefreshIgnoreListSyncUI()
		end
		return
	end

	if AddonTable.IsCurrentCharacterIgnoreListSyncAlt() then
		if IsLocalIgnoreListSynced() then
			ignoreListAltWasSynced = true
			return
		end
		if not ignoreListAltWasSynced or pendingLoginIgnoreSync then
			ApplyAccountIgnoreListToLocal()
			return
		end
		local mainName = AddonTable.GetIgnoreListSyncMainDisplayName()
		print("|cFFFF8800[MyGuildTools]|r " .. string.format(L["Ignore list sync edit on main"], mainName))
		ApplyAccountIgnoreListToLocal()
	end
end

function AddonTable.ResetIgnoreListSync()
	AddonTable.EnsureMGTBlacklistConfig()
	MGTConfig.IgnoreListSyncEnabled = "DISABLED"
	MGTConfig.IgnoreListSyncMain = nil
	MGTConfig.AccountIgnoreNames = {}
	MGTConfig.AccountIgnoreNamesRevision = 0
	pendingLoginIgnoreSync = false
	ignoreListAltWasSynced = false
	ignoreListSyncApplying = false
	ignoreListSyncSuppressUserAlerts = false
	AddonTable.RefreshIgnoreListSyncWatcher()
	if AddonTable.RefreshIgnoreListSyncUI then
		AddonTable.RefreshIgnoreListSyncUI()
	end
	print("|cFF0088FF[MyGuildTools]|r " .. L["Ignore list sync reset done"])
end

function AddonTable.SetIgnoreListSyncEnabled(enabled)
	AddonTable.EnsureMGTBlacklistConfig()
	if enabled then
		MGTConfig.IgnoreListSyncEnabled = "ENABLED"
		local currentKey = GetCurrentPlayerKey()
		local previousMainKey = MGTConfig.IgnoreListSyncMain
		if type(previousMainKey) ~= "string" or previousMainKey == "" or previousMainKey ~= currentKey then
			MGTConfig.IgnoreListSyncMain = currentKey
			UpdateAccountIgnoreListFromLocal()
			if type(previousMainKey) == "string" and previousMainKey ~= "" and previousMainKey ~= currentKey then
				print("|cFF0088FF[MyGuildTools]|r " .. string.format(
					L["Ignore list sync main replaced"],
					AddonTable.GetIgnoreListSyncMainDisplayName(),
					NormalizePlayerName(previousMainKey)
				))
			else
				print("|cFF0088FF[MyGuildTools]|r " .. string.format(
					L["Ignore list sync main set"],
					AddonTable.GetIgnoreListSyncMainDisplayName()
				))
			end
		end
	else
		MGTConfig.IgnoreListSyncEnabled = "DISABLED"
		MGTConfig.IgnoreListSyncMain = nil
	end
	AddonTable.RefreshIgnoreListSyncWatcher()
	if AddonTable.RefreshIgnoreListSyncUI then
		AddonTable.RefreshIgnoreListSyncUI()
	end
end

function AddonTable.GetIgnoreListSyncStatusText()
	AddonTable.EnsureMGTBlacklistConfig()
	local accountCount = #(MGTConfig.AccountIgnoreNames or {})
	local localCount = GetNumIgnores()
	local status = string.format(L["Ignore list sync status"], accountCount, localCount)
	if accountCount > IGNORE_LIST_MAX then
		status = status .. " " .. string.format(L["Ignore list sync overflow"], accountCount, IGNORE_LIST_MAX)
	end
	return status
end

local function IgnoreListSyncEventHandler(self, event, ...)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		SyncIgnoreListOnLogin()
	elseif event == "IGNORELIST_UPDATE" then
		OnIgnoreListUpdate()
	end
end

function AddonTable.RefreshIgnoreListSyncWatcher()
	AddonTable.EnsureMGTBlacklistConfig()
	if not ignoreListSyncFrame then
		ignoreListSyncFrame = CreateFrame("Frame")
		ignoreListSyncFrame:SetScript("OnEvent", IgnoreListSyncEventHandler)
		ignoreListSyncFrame:RegisterEvent("PLAYER_LOGIN")
		ignoreListSyncFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	end
	if IsIgnoreListSyncEnabled() then
		ignoreListSyncFrame:RegisterEvent("IGNORELIST_UPDATE")
	else
		ignoreListSyncFrame:UnregisterEvent("IGNORELIST_UPDATE")
	end
end

local function FindIgnoreListEntry(name)
	for i = 1, GetNumIgnores() do
		local entry = GetIgnoreNameRaw(i)
		if entry then
			for _, candidate in ipairs(CollectNameVariants(name)) do
				if string.lower(NormalizePlayerName(candidate)) == string.lower(NormalizePlayerName(entry)) then
					return entry
				end
			end
			if NamesFuzzyMatch(name, entry) then
				return entry
			end
		end
	end
	return nil
end

local function IsNameOnIgnoreList(name)
	for _, candidate in ipairs(CollectNameVariants(name)) do
		if C_FriendList and C_FriendList.IsIgnored and C_FriendList.IsIgnored(candidate) then
			return true
		end
		if C_FriendList and C_FriendList.IsOnIgnoredList and C_FriendList.IsOnIgnoredList(candidate) then
			return true
		end
	end
	return FindIgnoreListEntry(name) ~= nil
end

local function IsIgnoreListVisible()
	return _G.IgnoreListFrame and _G.IgnoreListFrame:IsShown()
end

local function CloseBlockingUIPanels()
	if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then
		HideUIPanel(SettingsPanel)
	end
	if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and HideUIPanel then
		HideUIPanel(InterfaceOptionsFrame)
	end
end

local function GetIgnoreSubPanelIndex()
	local header = _G.FriendsTabHeader
	if header and header.numTabs and header.numTabs >= 3 then
		return 3
	end
	if _G.QuickJoinFrame then
		return 3
	end
	return 2
end

local function IsSocialIgnorePanelActive()
	local friendsFrame = _G.FriendsFrame
	local header = _G.FriendsTabHeader
	if not friendsFrame or not friendsFrame:IsShown() or not header or not PanelTemplates_GetSelectedTab then
		return false
	end
	if PanelTemplates_GetSelectedTab(friendsFrame) ~= 1 then
		return false
	end
	return PanelTemplates_GetSelectedTab(header) == GetIgnoreSubPanelIndex()
end

local function ShowSocialIgnoreList()
	if IsIgnoreListVisible() or IsSocialIgnorePanelActive() then
		return true
	end

	if ToggleIgnorePanel then
		ToggleIgnorePanel()
		if IsIgnoreListVisible() or IsSocialIgnorePanelActive() then
			return true
		end
	end

	local panelIndex = GetIgnoreSubPanelIndex()
	if ToggleFriendsSubPanel then
		ToggleFriendsSubPanel(panelIndex)
		if IsIgnoreListVisible() or IsSocialIgnorePanelActive() then
			return true
		end
	end

	local friendsFrame = _G.FriendsFrame
	if not friendsFrame then
		return false
	end

	if not friendsFrame:IsShown() and ToggleFriendsFrame then
		ToggleFriendsFrame()
	end

	local header = _G.FriendsTabHeader
	if header and PanelTemplates_SetTab then
		PanelTemplates_SetTab(friendsFrame, 1)
		PanelTemplates_SetTab(header, panelIndex)
		if FriendsFrame_Update then
			FriendsFrame_Update()
		end
		if not friendsFrame:IsShown() and ShowUIPanel then
			ShowUIPanel(friendsFrame)
		end
	end

	if FriendsFrame_ShowSubFrame then
		FriendsFrame_ShowSubFrame("IgnoreListFrame")
		if FriendsFrame_Update then
			FriendsFrame_Update()
		end
		if IgnoreList_Update then
			IgnoreList_Update()
		end
	end

	local tab = _G["FriendsTabHeaderTab" .. panelIndex]
	if tab then
		if FriendsTabHeader_ClickTab then
			FriendsTabHeader_ClickTab(tab)
		else
			local onClick = tab:GetScript("OnClick")
			if onClick then
				onClick(tab)
			end
		end
	end

	return IsIgnoreListVisible() or IsSocialIgnorePanelActive()
end

function AddonTable.OpenIgnoreList()
	CloseBlockingUIPanels()

	if ShouldSyncIgnoreListForCharacter() and not IsLocalIgnoreListSynced() then
		RunIgnoreListSyncAttempt()
	end

	local function OpenNow()
		ShowSocialIgnoreList()
		if ShouldSyncIgnoreListForCharacter() and not IsLocalIgnoreListSynced() then
			RunIgnoreListSyncAttempt()
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, OpenNow)
		C_Timer.After(0.1, function()
			if not IsIgnoreListVisible() and not IsSocialIgnorePanelActive() then
				ShowSocialIgnoreList()
			end
		end)
	else
		OpenNow()
	end
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
	if MGTConfig.BlacklistAlertNameplate == nil then
		MGTConfig.BlacklistAlertNameplate = "ENABLED"
	end
	if MGTConfig.BlacklistNameplateApplyCVars == nil then
		MGTConfig.BlacklistNameplateApplyCVars = "ENABLED"
	end
	if MGTConfig.BlacklistPlaySound == nil then
		MGTConfig.BlacklistPlaySound = "ENABLED"
	end
	if MGTConfig.BlacklistChatAlert == nil then
		MGTConfig.BlacklistChatAlert = "ENABLED"
	end
	if MGTConfig.BlacklistRaidScreenAlert == nil then
		MGTConfig.BlacklistRaidScreenAlert = "DISABLED"
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
	if MGTConfig.IgnoreListSyncEnabled == nil then
		MGTConfig.IgnoreListSyncEnabled = "DISABLED"
	end
	if MGTConfig.IgnoreListSyncLoginApply == nil then
		MGTConfig.IgnoreListSyncLoginApply = "ENABLED"
	end
	if type(MGTConfig.AccountIgnoreNames) ~= "table" then
		MGTConfig.AccountIgnoreNames = {}
	end
	if MGTConfig.AccountIgnoreNamesRevision == nil then
		MGTConfig.AccountIgnoreNamesRevision = 0
	end
	if #MGTConfig.AccountIgnoreNames == 0 and type(MGTConfig.BlacklistNames) == "table" then
		for _, name in ipairs(MGTConfig.BlacklistNames) do
			if type(name) == "string" and name ~= "" then
				MGTConfig.AccountIgnoreNames[#MGTConfig.AccountIgnoreNames + 1] = name
			end
		end
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
		nameplate = "BlacklistAlertNameplate",
	}
	local configKey = map[alertKey]
	if not configKey then
		return true
	end
	return ConfigEnabled(configKey, true)
end

function AddonTable.IsPlayerBlacklisted(name)
	name = TrimString(name or "")
	if name == "" then
		return false
	end
	local entry = FindIgnoreListEntry(name)
	if entry then
		return true, entry
	end
	if IsNameOnIgnoreList(name) then
		return true, NormalizePlayerName(name)
	end
	return false
end

local function ShouldPlayBlacklistSound()
	return ConfigEnabled("BlacklistPlaySound", true)
end

local function ShouldShowBlacklistChatAlert()
	return ConfigEnabled("BlacklistChatAlert", true)
end

local function ShouldShowBlacklistRaidScreenAlert()
	return ConfigEnabled("BlacklistRaidScreenAlert", false)
end

local function EnsureBlacklistFlashFrame()
	if blacklistFlashFrame then
		return blacklistFlashFrame
	end
	local frame = CreateFrame("Frame", "MGTBlacklistFlashFrame", UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(1000)
	frame:EnableMouse(false)
	frame:Hide()

	local flash = frame:CreateTexture(nil, "BACKGROUND")
	flash:SetAllPoints()
	if flash.SetColorTexture then
		flash:SetColorTexture(1, 0, 0, 0)
	else
		flash:SetTexture("Interface\\Buttons\\WHITE8x8")
		flash:SetVertexColor(1, 0, 0, 0)
	end
	frame.flash = flash
	blacklistFlashFrame = frame
	return frame
end

local function PlayBlacklistRedFlash()
	local frame = EnsureBlacklistFlashFrame()
	local flash = frame.flash
	if not flash then
		return
	end

	frame.flashStart = GetTime and GetTime() or 0
	frame:Show()
	frame:SetScript("OnUpdate", function(self)
		local elapsed = (GetTime and GetTime() or 0) - (self.flashStart or 0)
		if elapsed >= RAID_FLASH_DURATION then
			if flash.SetColorTexture then
				flash:SetColorTexture(1, 0, 0, 0)
			else
				flash:SetVertexColor(1, 0, 0, 0)
			end
			self:Hide()
			self:SetScript("OnUpdate", nil)
			return
		end

		local pulse = 0.5 - math.abs((elapsed / RAID_FLASH_DURATION) - 0.5)
		local alpha = RAID_FLASH_MAX_ALPHA * pulse * 2
		if flash.SetColorTexture then
			flash:SetColorTexture(1, 0, 0, alpha)
		else
			flash:SetVertexColor(1, 0, 0, alpha)
		end
	end)
end

local function ShowBlacklistRaidScreenAlert(msg)
	if not msg or msg == "" then
		return
	end
	local color = { r = 1, g = 0.15, b = 0.15 }
	if ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
		color = ChatTypeInfo["RAID_WARNING"]
	end
	if RaidNotice_AddMessage then
		if RaidWarningFrame then
			RaidNotice_AddMessage(RaidWarningFrame, msg, color, RAID_SCREEN_ALERT_HOLD)
		elseif RaidBossEmoteFrame then
			RaidNotice_AddMessage(RaidBossEmoteFrame, msg, color, RAID_SCREEN_ALERT_HOLD)
		end
	end
	PlayBlacklistRedFlash()
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
	if ShouldShowBlacklistChatAlert() then
		print("|cFFFF0000[MyGuildTools Blacklist]|r " .. msg)
	end
	if ShouldPlayBlacklistSound() then
		PlaySound(ALERT_SOUND, "Master")
	end
	if ShouldShowBlacklistRaidScreenAlert() then
		local raidMsg = string.format(L["Blacklist raid alert: %s"], displayName)
		if matchedEntry ~= displayName then
			raidMsg = raidMsg .. " " .. string.format(L["Blacklist alert matched entry"], matchedEntry)
		end
		raidMsg = raidMsg .. "\n(" .. context .. ")"
		ShowBlacklistRaidScreenAlert(raidMsg)
	end
end

local function CheckAndAlert(name, alertType, alertCategory)
	if not AddonTable.IsBlacklistActive() then
		return false
	end
	alertCategory = alertCategory or alertType
	if alertType == "whisper_out" then
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
	elseif alertType == "nameplate" then
		if not AddonTable.IsBlacklistAlertEnabled("nameplate") then
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

local function AlertOutgoingWhisper(target)
	if not AddonTable.IsBlacklistActive() or not target or target == "" then
		return false
	end
	local matched, entry = AddonTable.IsPlayerBlacklisted(target)
	if not matched then
		return false
	end
	if AddonTable.IsBlacklistAlertEnabled("whisper") then
		local playerKey = GetMatchCore(target)
		if CanAlertAgain(playerKey, "whisper_out") then
			AddonTable.ReportBlacklistAlert(NormalizePlayerName(target), entry, "whisper_out")
		end
	end
	return ShouldBlockInteraction()
end

local function InstallWhisperHooks()
	if whisperHooksInstalled then
		return
	end
	whisperHooksInstalled = true

	if C_ChatInfo and C_ChatInfo.SendChatMessage then
		originalCChatInfoSendChatMessage = C_ChatInfo.SendChatMessage
		C_ChatInfo.SendChatMessage = function(message, chatType, languageID, target, ...)
			local chat = chatType and string.upper(chatType)
			if chat == "WHISPER" and AlertOutgoingWhisper(target) then
				return
			end
			return originalCChatInfoSendChatMessage(message, chatType, languageID, target, ...)
		end
	end

	if SendChatMessage then
		originalSendChatMessage = SendChatMessage
		SendChatMessage = function(message, chatType, languageID, target, ...)
			local chat = chatType and string.upper(chatType)
			if chat == "WHISPER" and AlertOutgoingWhisper(target) then
				return
			end
			return originalSendChatMessage(message, chatType, languageID, target, ...)
		end
	end
end

local function OnOutgoingWhisper(_, recipient)
	AlertOutgoingWhisper(recipient)
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

local function IsOtherPlayerUnit(unit)
	if type(unit) ~= "string" or unit == "" or not UnitExists(unit) or UnitIsUnit(unit, "player") then
		return false
	end
	if UnitIsPlayer and UnitIsPlayer(unit) then
		return true
	end
	if UnitGUID then
		local guid = UnitGUID(unit)
		if type(guid) == "string" and guid:find("^Player%-") then
			return true
		end
	end
	return false
end

local function GetUnitPlayerName(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end
	local name = GetUnitName(unit, true)
	if not name or name == "" then
		name = GetUnitName(unit, false)
	end
	if type(name) == "string" and name ~= "" then
		return name
	end
	return nil
end

local function GetCVarSafe(key)
	if type(key) ~= "string" or key == "" or not GetCVar then
		return nil
	end
	local ok, value = pcall(GetCVar, key)
	if ok then
		return value
	end
	return nil
end

local function ApplyNameplateScanCVars()
	if not SetCVar or not ConfigEnabled("BlacklistNameplateApplyCVars", true) then
		return
	end
	if not AddonTable.IsBlacklistActive() or not AddonTable.IsBlacklistAlertEnabled("nameplate") then
		return
	end

	local changed = {}
	for _, key in ipairs(NAMEPLATE_SCAN_CVARS) do
		local current = GetCVarSafe(key)
		if current ~= nil and current ~= "1" then
			SetCVar(key, "1")
			changed[#changed + 1] = key
		end
	end
	if #changed > 0 then
		print("|cFF0088FF[MyGuildTools]|r " .. string.format(L["Nameplate CVar applied"], table.concat(changed, ", ")))
	end
end

local function CollectActiveNameplateUnits()
	local units = {}
	local seen = {}

	local function addUnit(unit)
		if type(unit) ~= "string" or unit == "" or seen[unit] then
			return
		end
		if not UnitExists(unit) then
			return
		end
		seen[unit] = true
		units[#units + 1] = unit
	end

	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if type(plates) ~= "table" or #plates == 0 then
			plates = C_NamePlate.GetNamePlates(true)
		end
		if type(plates) == "table" then
			for _, plate in ipairs(plates) do
				local unit = plate and plate.namePlateUnitToken
				if type(unit) ~= "string" or unit == "" then
					local unitFrame = plate and plate.UnitFrame
					if unitFrame and type(unitFrame.unit) == "string" then
						unit = unitFrame.unit
					end
				end
				addUnit(unit)
			end
		end
	end

	for i = 1, NAMEPLATE_UNIT_MAX do
		addUnit("nameplate" .. i)
	end

	return units
end

local function CheckUnitToken(unit, alertType)
	if not IsOtherPlayerUnit(unit) then
		return
	end
	local name = GetUnitPlayerName(unit)
	if name then
		CheckAndAlert(name, alertType, alertType)
	end
end

local function CheckNameplateUnit(unit)
	if not IsOtherPlayerUnit(unit) then
		return
	end
	local name = GetUnitPlayerName(unit)
	if name then
		CheckAndAlert(name, "nameplate", "nameplate")
	end
end

local function ScanNameplatesForBlacklist()
	if not AddonTable.IsBlacklistActive() or not AddonTable.IsBlacklistAlertEnabled("nameplate") then
		return
	end
	local seen = {}
	for _, unit in ipairs(CollectActiveNameplateUnits()) do
		if IsOtherPlayerUnit(unit) then
			local name = GetUnitPlayerName(unit)
			if name and not seen[name] then
				seen[name] = true
				CheckAndAlert(name, "nameplate", "nameplate")
			end
		end
	end
end

local function RefreshBlacklistNameplateScanner()
	if nameplateScanTicker and nameplateScanTicker.Cancel then
		nameplateScanTicker:Cancel()
		nameplateScanTicker = nil
	end
	if not blacklistFrame then
		return
	end
	local nameplateAlerts = AddonTable.IsBlacklistActive() and AddonTable.IsBlacklistAlertEnabled("nameplate")
	if nameplateAlerts then
		blacklistFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	else
		blacklistFrame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
	end
	if not nameplateAlerts then
		return
	end
	ApplyNameplateScanCVars()
	if C_Timer and C_Timer.NewTicker then
		nameplateScanTicker = C_Timer.NewTicker(NAMEPLATE_SCAN_INTERVAL, ScanNameplatesForBlacklist)
		if C_Timer.After then
			C_Timer.After(1, ScanNameplatesForBlacklist)
		end
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
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		CheckNameplateUnit(...)
	elseif event == "CHAT_MSG_WHISPER_INFORM" then
		OnOutgoingWhisper(...)
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
	"CHAT_MSG_WHISPER_INFORM",
}

function AddonTable.RefreshBlacklistWatcher()
	AddonTable.EnsureMGTBlacklistConfig()
	if not blacklistFrame then
		blacklistFrame = CreateFrame("Frame")
		blacklistFrame:SetScript("OnEvent", BlacklistEventHandler)
	end

	InstallWhisperHooks()
	RefreshBlacklistNameplateScanner()

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
		AddonTable.RefreshIgnoreListSyncWatcher()
	elseif event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == AddonName) then
		AddonTable.RefreshBlacklistWatcher()
		AddonTable.RefreshIgnoreListSyncWatcher()
	end
end)
