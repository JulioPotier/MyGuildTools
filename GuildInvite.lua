local AddonName, AddonTable = ...

local popup
local inviteButton
local dismissFrame

local MENU_TYPES = {
	"MENU_UNIT_TARGET",
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_FRIEND",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
}

local function IsGuildInviteMenuEnabled()
	return MGTConfig and MGTConfig.GuildInviteMenu == "ENABLED"
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

local function NormalizePlayerName(name)
	if not name or name == "" then
		return nil
	end
	-- Ambiguate("Name-Realm", "none") keeps realm when present; good for equality checks.
	return Ambiguate(name, "none")
end

local function ResolveUnitFromPlayerName(playerName)
	playerName = NormalizePlayerName(playerName)
	if not playerName then
		return nil
	end

	local function unitMatches(unit)
		if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
			return false
		end
		return NormalizePlayerName(GetUnitName(unit, true)) == playerName
	end

	-- Common singletons
	local singletons = { "target", "mouseover", "focus" }
	for i = 1, #singletons do
		local u = singletons[i]
		if unitMatches(u) then
			return u
		end
	end

	-- Party / raid
	for i = 1, 4 do
		local u = "party" .. i
		if unitMatches(u) then
			return u
		end
	end
	for i = 1, 40 do
		local u = "raid" .. i
		if unitMatches(u) then
			return u
		end
	end

	-- Nearby players via nameplates (best-effort)
	for i = 1, 40 do
		local u = "nameplate" .. i
		if unitMatches(u) then
			return u
		end
	end

	return nil
end

local function HideGinviteButton()
	if popup then
		popup:Hide()
	end
	if dismissFrame then
		dismissFrame:Hide()
	end
end

function AddonTable.ShowGinviteButton(playerName)
	if not playerName or playerName == "" then
		return
	end
	if InCombatLockdown() then
		print("|cFF0088FF[MyGuildTools]|r |cFFFF0000Cannot use /ginvite during combat.|r")
		return
	end

	local label = "/ginvite " .. playerName
	inviteButton:SetAttribute("macrotext", "/ginvite " .. playerName)
	inviteButton:SetText(label)
	inviteButton:SetWidth(math.max(140, inviteButton:GetFontString():GetStringWidth() + 24))
	popup:SetWidth(inviteButton:GetWidth() + 16)

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	popup:ClearAllPoints()
	popup:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 8, (y / scale) + 8)
	dismissFrame:Show()
	popup:Show()
end

local function RegisterContextMenus()
	if not Menu or not Menu.ModifyMenu then
		return
	end

	for i = 1, #MENU_TYPES do
		local menuType = MENU_TYPES[i]
		Menu.ModifyMenu(menuType, function(ownerRegion, rootDescription, contextData)
			if not IsGuildInviteMenuEnabled() then
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

			rootDescription:CreateDivider()
			local targetHasGuild = false
			local guildUnit = unit
			if (not guildUnit or not UnitExists(guildUnit)) and playerName then
				guildUnit = ResolveUnitFromPlayerName(playerName)
			end
			if guildUnit and UnitExists(guildUnit) and UnitIsPlayer(guildUnit) then
				local guildName = GetGuildInfo(guildUnit)
				targetHasGuild = guildName ~= nil and guildName ~= ""
			end

			local button = rootDescription:CreateButton("/ginvite", function()
				if targetHasGuild then
					return
				end
				AddonTable.ShowGinviteButton(playerName)
			end)
			if targetHasGuild and button and button.SetEnabled then
				button:SetEnabled(false)
			end
		end)
	end
end

-- Raccourci clavier :
-- /mgtginvite, ou macro « /click MGTGinviteKeybindButton » puis touche native sur la barre.
local function InviteTargetViaGinvite()
	if InCombatLockdown() then
		print("|cFF0088FF[MyGuildTools]|r |cFFFF0000Cannot use /ginvite during combat.|r")
		return
	end

	local unit = "target"
	if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
		return
	end

	local guildName = GetGuildInfo(unit)
	if guildName ~= nil and guildName ~= "" then
		return
	end

	local playerName = GetUnitName(unit, true)
	if not playerName or playerName == "" then
		return
	end

	AddonTable.ShowGinviteButton(playerName)
end

SLASH_MGTGINVITE1 = "/mgtginvite"
SlashCmdList["MGTGINVITE"] = InviteTargetViaGinvite

local keybindStub = CreateFrame("Button", "MGTGinviteKeybindButton", UIParent)
keybindStub:Hide()
keybindStub:RegisterForClicks("LeftButtonUp", "RightButtonUp")
keybindStub:SetScript("OnClick", InviteTargetViaGinvite)

popup = CreateFrame("Frame", "MGTGinvitePopup", UIParent, "BackdropTemplate")
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

inviteButton = CreateFrame("Button", "MGTGinviteButton", popup, "SecureActionButtonTemplate,UIPanelButtonTemplate")
inviteButton:SetPoint("CENTER")
inviteButton:SetHeight(22)
inviteButton:SetAttribute("type", "macro")
inviteButton:RegisterForClicks("AnyUp")
inviteButton:SetScript("PostClick", function()
	HideGinviteButton()
end)

dismissFrame = CreateFrame("Button", nil, UIParent)
dismissFrame:SetAllPoints(UIParent)
dismissFrame:SetFrameStrata("FULLSCREEN_DIALOG")
dismissFrame:SetFrameLevel(popup:GetFrameLevel() - 1)
dismissFrame:EnableMouse(true)
dismissFrame:Hide()
dismissFrame:SetScript("OnClick", HideGinviteButton)

RegisterContextMenus()
