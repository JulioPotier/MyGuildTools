local AddonName, AddonTable = ...
local L = AddonTable.Localize

local popup
local targetButton
local dismissFrame

local CHAT_MENU_TYPES = {
	"MENU_CHAT_PLAYER",
	"MENU_CHAT_ROSTER",
}

local PLAYER_MENU_TYPES = {
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_FRIEND",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID_PLAYER",
}

local function NormalizeTargetName(name)
	if type(name) ~= "string" then
		return ""
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return ""
	end
	if Ambiguate then
		name = Ambiguate(name, "none") or name
	end
	name = name:match("^([^%-]+)") or name
	return name
end

function AddonTable.EnsureMGTChatTargetConfig()
	if type(MGTConfig) ~= "table" then
		MGTConfig = {}
	end
	if MGTConfig.TargetPlayerFromChat == nil then
		MGTConfig.TargetPlayerFromChat = "DISABLED"
	end
end

function AddonTable.IsChatTargetEnabled()
	AddonTable.EnsureMGTChatTargetConfig()
	return MGTConfig.TargetPlayerFromChat == "ENABLED"
end

function AddonTable.SetChatTargetEnabled(enabled)
	AddonTable.EnsureMGTChatTargetConfig()
	MGTConfig.TargetPlayerFromChat = enabled and "ENABLED" or "DISABLED"
end

local function GetContextPlayerName(contextData)
	if not contextData then
		return nil
	end
	if contextData.name and contextData.name ~= "" then
		return contextData.name
	end
	local unit = contextData.unit or contextData.unitToken
	if unit and UnitExists(unit) and UnitIsPlayer(unit) then
		return GetUnitName(unit, true)
	end
	return nil
end

local function IsChatPlayerContext(ownerRegion, contextData)
	if contextData then
		if contextData.chatFrame or contextData.chatType then
			return true
		end
		if contextData.isChatLink or contextData.linkType == "player" then
			return true
		end
	end

	local region = ownerRegion
	for _ = 1, 12 do
		if not region then
			break
		end
		local name = region.GetName and region:GetName()
		if type(name) == "string" and name:find("ChatFrame") then
			return true
		end
		region = region:GetParent()
	end

	return false
end

local function ResolveTargetUnit(playerName, contextData)
	local unit = contextData and (contextData.unit or contextData.unitToken)
	if unit and UnitExists(unit) and UnitIsPlayer(unit) then
		return unit
	end
	if AddonTable.ResolveUnitFromPlayerName then
		return AddonTable.ResolveUnitFromPlayerName(playerName)
	end
	return nil
end

local function HideTargetPopup()
	if popup then
		popup:Hide()
	end
	if dismissFrame then
		dismissFrame:Hide()
	end
end

local function ShowTargetPopup(playerName)
	playerName = NormalizeTargetName(playerName)
	if playerName == "" or not targetButton or not popup then
		return
	end

	local unit = ResolveTargetUnit(playerName, nil)
	targetButton:SetParent(popup)
	targetButton:ClearAllPoints()
	targetButton:SetPoint("CENTER")

	if unit and UnitExists(unit) and UnitIsPlayer(unit) then
		targetButton:SetAttribute("type", "target")
		targetButton:SetAttribute("unit", unit)
		targetButton:SetAttribute("macrotext", nil)
	else
		targetButton:SetAttribute("type", "macro")
		targetButton:SetAttribute("unit", nil)
		targetButton:SetAttribute("macrotext", "/target " .. playerName)
	end

	local label = "/target " .. playerName
	targetButton:SetText(label)
	targetButton:SetWidth(math.max(140, targetButton:GetFontString():GetStringWidth() + 24))
	popup:SetWidth(targetButton:GetWidth() + 16)
	popup:SetHeight(36)

	if AddonTable.PlacePopupNearCursor then
		AddonTable.PlacePopupNearCursor(popup)
	end

	dismissFrame:Show()
	popup:Show()
	targetButton:Show()
end

local function TargetPlayerFromChat(playerName, contextData, ownerRegion)
	playerName = NormalizeTargetName(playerName)
	if playerName == "" then
		return
	end

	if not InCombatLockdown() and TargetUnit then
		local unit = ResolveTargetUnit(playerName, contextData)
		if unit and UnitExists(unit) and UnitIsPlayer(unit) then
			TargetUnit(unit)
			return
		end
	end

	ShowTargetPopup(playerName)
end

local function AppendTargetMenuEntry(rootDescription, playerName, contextData)
	if not playerName or playerName == "" then
		return
	end

	rootDescription:CreateDivider()
	rootDescription:CreateButton("/target", function()
		TargetPlayerFromChat(playerName, contextData)
	end)
end

local function RegisterChatTargetMenu(menuType, requireChatContext)
	if not Menu or not Menu.ModifyMenu then
		return
	end

	Menu.ModifyMenu(menuType, function(ownerRegion, rootDescription, contextData)
		if not AddonTable.IsChatTargetEnabled() then
			return
		end
		if requireChatContext and not IsChatPlayerContext(ownerRegion, contextData) then
			return
		end

		local playerName = GetContextPlayerName(contextData)
		if not playerName then
			return
		end

		local unit = contextData.unit or contextData.unitToken
		if unit and UnitExists(unit) and not UnitIsPlayer(unit) then
			return
		end

		AppendTargetMenuEntry(rootDescription, playerName, contextData)
	end)
end

local function CreateTargetPopup()
	popup = CreateFrame("Frame", "MGTChatTargetPopup", UIParent, "BackdropTemplate")
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetSize(200, 36)
	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	popup:SetBackdropColor(0, 0, 0, 0.85)
	popup:Hide()

	targetButton = CreateFrame("Button", "MGTChatTargetButton", popup, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	targetButton:SetPoint("CENTER")
	targetButton:SetHeight(22)
	targetButton:RegisterForClicks("AnyUp")
	targetButton:SetScript("PostClick", HideTargetPopup)

	dismissFrame = CreateFrame("Button", nil, UIParent)
	dismissFrame:SetAllPoints(UIParent)
	dismissFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	dismissFrame:SetFrameLevel(popup:GetFrameLevel() - 1)
	dismissFrame:EnableMouse(true)
	dismissFrame:Hide()
	dismissFrame:SetScript("OnClick", HideTargetPopup)
end

local function RegisterChatTargetMenus()
	if not Menu or not Menu.ModifyMenu then
		return
	end

	for i = 1, #CHAT_MENU_TYPES do
		RegisterChatTargetMenu(CHAT_MENU_TYPES[i], false)
	end
	for i = 1, #PLAYER_MENU_TYPES do
		RegisterChatTargetMenu(PLAYER_MENU_TYPES[i], true)
	end
end

CreateTargetPopup()
RegisterChatTargetMenus()
