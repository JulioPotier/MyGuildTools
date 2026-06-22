local AddonName, AddonTable = ...
local L = AddonTable.Localize

local popup
local inviteButton
local dismissFrame

local GUILD_MEMBER_POPUP_WHICH = {
	ADD_GUILDMEMBER = true,
	MGT_ADD_GUILD_MEMBER = true,
}

local MENU_TYPES = {
	"MENU_UNIT_TARGET",
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_FRIEND",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
}

function AddonTable.PlayerCanGuildInvite()
	if not IsInGuild or not IsInGuild() then
		return false
	end
	if CanGuildInvite and not CanGuildInvite() then
		return false
	end
	return true
end

local function IsGuildInviteMenuEnabled()
	return AddonTable.PlayerCanGuildInvite()
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

local function ReportGuildInvite(msg)
	print("|cFF0088FF[MyGuildTools]|r " .. msg)
end

local function ParseGuildInviteName(rawName)
	if not rawName then
		return nil
	end
	local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return nil
	end
	-- Classic Era invite expects "Name" (no realm). Strip "-Realm" if user pasted it.
	name = name:gsub("%s+", " ")
	name = name:match("^([^-]+)") or name
	return name
end

local function GetPopupEditBox(popupFrame)
	if not popupFrame then
		return nil
	end
	if popupFrame.editBox and popupFrame.editBox.GetText then
		return popupFrame.editBox
	end
	local frameName = popupFrame.GetName and popupFrame:GetName()
	if frameName then
		local editBox = _G[frameName .. "EditBox"]
		if editBox and editBox.GetText then
			return editBox
		end
	end
	return nil
end

local function CommitAutoCompleteEditBox(editBox)
	if not editBox or not editBox.autoCompleteParams then
		return
	end
	if type(AutoCompleteEditBox_OnEnterPressed) == "function" then
		pcall(AutoCompleteEditBox_OnEnterPressed, editBox)
	elseif type(AutoCompleteEditBox_OnTabPressed) == "function" then
		pcall(AutoCompleteEditBox_OnTabPressed, editBox)
	end
end

local function GetAutoCompleteInviteName(editBox)
	if not editBox or not editBox.autoCompleteParams or not GetAutoCompleteResults then
		return nil
	end
	local typed = editBox:GetText() or ""
	if typed == "" then
		return nil
	end
	local params = editBox.autoCompleteParams
	local includeFlags, excludeFlags = 0, 0
	if type(params) == "table" then
		includeFlags = params.includeFlags or params.include or 0
		excludeFlags = params.excludeFlags or params.exclude or 0
	elseif type(params) == "number" then
		includeFlags = params
	end
	local cursor = (editBox.GetCursorPosition and editBox:GetCursorPosition()) or #typed
	local results
	if pcall(function()
		results = GetAutoCompleteResults(typed, 1, cursor, true, includeFlags, excludeFlags)
	end) and results and results[1] and results[1].name then
		return results[1].name
	end
	if pcall(function()
		results = GetAutoCompleteResults(typed, 1, cursor, includeFlags, excludeFlags)
	end) and results and results[1] and results[1].name then
		return results[1].name
	end
	return nil
end

local function GetGuildInviteEditBoxText(popupFrame)
	local editBox = GetPopupEditBox(popupFrame)
	if not editBox then
		return popupFrame and popupFrame._mgtPendingInviteName or nil
	end
	CommitAutoCompleteEditBox(editBox)
	local text = editBox:GetText()
	if (not text or text == "") and popupFrame and popupFrame._mgtPendingInviteName then
		text = popupFrame._mgtPendingInviteName
	end
	if (not text or text == "") then
		text = GetAutoCompleteInviteName(editBox)
	end
	return text
end

local function TrackInviteNameFromEditBox(popupFrame, editBox)
	if not popupFrame or not editBox then
		return
	end
	local text = editBox:GetText()
	if text and text ~= "" then
		popupFrame._mgtPendingInviteName = text
	end
	local completed = GetAutoCompleteInviteName(editBox)
	if completed and completed ~= "" then
		popupFrame._mgtPendingInviteName = completed
	end
end

local function GetActiveGuildMemberPopup()
	for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
		local frame = _G["StaticPopup" .. i]
		if frame and frame:IsShown() and frame.which and GUILD_MEMBER_POPUP_WHICH[frame.which] then
			return frame
		end
	end
	return nil
end

local function GetGuildMemberDialogFrame(dialog)
	if dialog and dialog.editBox and dialog.which and GUILD_MEMBER_POPUP_WHICH[dialog.which] then
		return dialog
	end
	if dialog and dialog.GetParent then
		local parent = dialog:GetParent()
		if parent and parent.editBox and parent.which and GUILD_MEMBER_POPUP_WHICH[parent.which] then
			return parent
		end
	end
	return GetActiveGuildMemberPopup()
end

local function EnsureInviteEditBoxTracking(editBox)
	if not editBox or editBox._mgtInviteTextHooked then
		return
	end
	editBox._mgtInviteTextHooked = true
	editBox:HookScript("OnTextChanged", function(box)
		TrackInviteNameFromEditBox(box:GetParent(), box)
	end)
end

local function GuildMemberPopupOnShow(self)
	self._mgtPendingInviteName = nil
	local editBox = GetPopupEditBox(self)
	if editBox then
		editBox:SetText("")
		editBox:SetFocus()
		EnsureInviteEditBoxTracking(editBox)
	end
	if self.button1 and self.button1.Enable then
		self.button1:Enable()
	end
	local acceptBtn = self.button1
	if acceptBtn and not acceptBtn._mgtGuildInviteHooked then
		acceptBtn._mgtGuildInviteHooked = true
		acceptBtn:HookScript("OnClick", function(btn)
			local dialog = btn:GetParent()
			if not dialog or not dialog.which or not GUILD_MEMBER_POPUP_WHICH[dialog.which] then
				return
			end
			if popup and popup:IsShown() then
				return
			end
			SubmitGuildInviteFromPopup(dialog)
		end)
	end
end

local function ValidateGuildInviteName(rawName)
	local name = ParseGuildInviteName(rawName)
	if not name then
		ReportGuildInvite("Enter a player name.")
		return nil
	end
	if InCombatLockdown() then
		ReportGuildInvite("Cannot use /ginvite during combat.")
		return nil
	end
	if not AddonTable.PlayerCanGuildInvite() then
		if not IsInGuild or not IsInGuild() then
			ReportGuildInvite("You are not in a guild.")
		else
			ReportGuildInvite("You don't have permission to invite guild members.")
		end
		return nil
	end
	return name
end

local function CloseGuildMemberPopup(popupFrame)
	popupFrame = popupFrame or GetActiveGuildMemberPopup()
	if not popupFrame then
		return
	end
	if StaticPopup_Hide and popupFrame.which then
		StaticPopup_Hide(popupFrame.which)
	else
		popupFrame:Hide()
	end
end

local function SubmitGuildInviteFromPopup(popupFrame)
	local name = ValidateGuildInviteName(GetGuildInviteEditBoxText(popupFrame))
	if not name then
		return false
	end

	-- Show /ginvite on Accept while the dialog is still open (closing first broke the anchor).
	AddonTable.ShowGinviteButton(name, popupFrame and popupFrame.button1)
	-- Return true so StaticPopup stays open until /ginvite is clicked.
	return true
end

local function PatchGuildMemberPopup(which)
	local info = StaticPopupDialogs[which]
	if not info or info._mgtGuildInvitePatched then
		return
	end
	info._mgtGuildInvitePatched = true

	info._mgtOrigOnShow = info.OnShow
	info._mgtOrigOnHide = info.OnHide
	info._mgtOrigOnAccept = info.OnAccept
	info._mgtOrigEditBoxOnEnterPressed = info.EditBoxOnEnterPressed

	info.OnShow = function(self)
		if info._mgtOrigOnShow then
			info._mgtOrigOnShow(self)
		end
		GuildMemberPopupOnShow(self)
	end
	info.OnHide = function(self)
		if info._mgtOrigOnHide then
			info._mgtOrigOnHide(self)
		end
	end
	info.OnAccept = function(self)
		SubmitGuildInviteFromPopup(self)
	end
	info.EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		if self.autoCompleteParams and type(AutoCompleteEditBox_OnEnterPressed) == "function" then
			if AutoCompleteEditBox_OnEnterPressed(self) then
				TrackInviteNameFromEditBox(parent, self)
			end
		end
		SubmitGuildInviteFromPopup(parent)
	end
end

local function EnsureGuildMemberPopupsPatched()
	if StaticPopupDialogs then
		PatchGuildMemberPopup("ADD_GUILDMEMBER")
		PatchGuildMemberPopup("MGT_ADD_GUILD_MEMBER")
	end
end

local function ShowNameInvitePopup()
	if not AddonTable.PlayerCanGuildInvite() then
		if not IsInGuild or not IsInGuild() then
			ReportGuildInvite("You are not in a guild.")
		else
			ReportGuildInvite("You don't have permission to invite guild members.")
		end
		return false
	end
	if not StaticPopupDialogs or not StaticPopup_Show then
		return false
	end

	EnsureGuildMemberPopupsPatched()

	if not StaticPopupDialogs.MGT_ADD_GUILD_MEMBER then
		StaticPopupDialogs.MGT_ADD_GUILD_MEMBER = {
			text = L and L["Add Guild Member"] or "Add Guild Member",
			button1 = ACCEPT,
			button2 = CANCEL,
			hasEditBox = 1,
			maxLetters = 77,
			autoCompleteParams = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.GUILD_INVITE or nil,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			hideOnEscape = 1,
			OnShow = GuildMemberPopupOnShow,
			OnAccept = function(self)
				SubmitGuildInviteFromPopup(self)
			end,
			EditBoxOnEnterPressed = function(self)
				local parent = self:GetParent()
				if self.autoCompleteParams and type(AutoCompleteEditBox_OnEnterPressed) == "function" then
					if AutoCompleteEditBox_OnEnterPressed(self) then
						TrackInviteNameFromEditBox(parent, self)
					end
				end
				SubmitGuildInviteFromPopup(parent)
			end,
			EditBoxOnEscapePressed = function(self)
				self:GetParent():Hide()
			end,
		}
		PatchGuildMemberPopup("MGT_ADD_GUILD_MEMBER")
	end

	-- Prefer Blizzard's native dialog when available (same UI, patched handlers).
	local which = StaticPopupDialogs.ADD_GUILDMEMBER and "ADD_GUILDMEMBER" or "MGT_ADD_GUILD_MEMBER"
	local ok, popupFrame = pcall(StaticPopup_Show, which)
	return ok and popupFrame ~= nil
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

AddonTable.ResolveUnitFromPlayerName = ResolveUnitFromPlayerName

function AddonTable.PlacePopupNearCursor(popup)
	if not popup then
		return
	end
	popup:ClearAllPoints()
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	popup:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 8, (y / scale) + 8)
end

local function HideGinviteButton()
	if popup then
		popup:Hide()
	end
	if dismissFrame then
		dismissFrame:Hide()
	end
end

function AddonTable.ShowGinviteButton(playerName, anchorFrame)
	if not playerName or playerName == "" then
		return
	end
	if not AddonTable.PlayerCanGuildInvite() then
		if not IsInGuild or not IsInGuild() then
			ReportGuildInvite("You are not in a guild.")
		else
			ReportGuildInvite("You don't have permission to invite guild members.")
		end
		return
	end
	if not inviteButton or not popup then
		return
	end
	if InCombatLockdown() then
		print("|cFF0088FF[MyGuildTools]|r |cFFFF0000Cannot use /ginvite during combat.|r")
		return
	end

	inviteButton:SetParent(popup)
	inviteButton:ClearAllPoints()
	inviteButton:SetPoint("CENTER")

	local label = "/ginvite " .. playerName
	inviteButton:SetAttribute("macrotext", "/ginvite " .. playerName)
	inviteButton:SetText(label)
	inviteButton:SetWidth(math.max(140, inviteButton:GetFontString():GetStringWidth() + 24))
	popup:SetWidth(inviteButton:GetWidth() + 16)
	popup:SetHeight(36)

	AddonTable.PlacePopupNearCursor(popup)

	dismissFrame:Show()
	popup:Show()
	inviteButton:Show()
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
local function InviteTargetViaGinvite(msg)
	if not AddonTable.PlayerCanGuildInvite() then
		if not IsInGuild or not IsInGuild() then
			ReportGuildInvite("You are not in a guild.")
		else
			ReportGuildInvite("You don't have permission to invite guild members.")
		end
		return
	end
	if InCombatLockdown() then
		print("|cFF0088FF[MyGuildTools]|r |cFFFF0000Cannot use /ginvite during combat.|r")
		return
	end

	-- /mgtginvite Name
	if msg and msg:gsub("%s+", "") ~= "" then
		AddonTable.ShowGinviteButton(msg)
		return
	end

	local unit = "target"
	if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
		-- No target: show the name entry dialog.
		if not ShowNameInvitePopup() then
			print("|cFF0088FF[MyGuildTools]|r Usage: |cffffffff/mgtginvite <name>|r (or target a player).")
		end
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
	CloseGuildMemberPopup(GetActiveGuildMemberPopup())
end)

dismissFrame = CreateFrame("Button", nil, UIParent)
dismissFrame:SetAllPoints(UIParent)
dismissFrame:SetFrameStrata("FULLSCREEN_DIALOG")
dismissFrame:SetFrameLevel(popup:GetFrameLevel() - 1)
dismissFrame:EnableMouse(true)
dismissFrame:Hide()
dismissFrame:SetScript("OnClick", HideGinviteButton)

RegisterContextMenus()

local patchFrame = CreateFrame("Frame")
patchFrame:RegisterEvent("PLAYER_LOGIN")
patchFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
patchFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
patchFrame:SetScript("OnEvent", function()
	EnsureGuildMemberPopupsPatched()
end)
EnsureGuildMemberPopupsPatched()
