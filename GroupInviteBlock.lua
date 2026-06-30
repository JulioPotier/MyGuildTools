local AddonName, AddonTable = ...
local L = AddonTable.Localize

AddonTable.GROUP_INVITE_BLOCK_NONE = "NONE"
AddonTable.GROUP_INVITE_BLOCK_COMBAT = "COMBAT"
AddonTable.GROUP_INVITE_BLOCK_ALWAYS = "ALWAYS"

local MINIMAP_ANGLE = 225
local MINIMAP_RADIUS = 80
local MINIMAP_DRAG_THRESHOLD = 4
local WHISPER_KEYWORD_WAIT_SECONDS = 1
local GROUP_INVITE_KEYWORD_MAX_STORED = 128

local blockFrame
local pendingInvite
local pendingInviteGeneration = 0
local minimapButton
local minimapBg
local minimapBorder
local minimapLetter
local minimapDragActive = false
local minimapDragMoved = false
local minimapMenuFrame

local MINIMAP_BLOCK_MENU_MODES = {
	AddonTable.GROUP_INVITE_BLOCK_NONE,
	AddonTable.GROUP_INVITE_BLOCK_COMBAT,
	AddonTable.GROUP_INVITE_BLOCK_ALWAYS,
}

local partyInvitePopupHookInstalled = false
local lastPartyInviterName
local guildMemberNames = {}

local BLOCK_MODE_LABELS = {
	[AddonTable.GROUP_INVITE_BLOCK_NONE] = function()
		return L["Not blocked"]
	end,
	[AddonTable.GROUP_INVITE_BLOCK_COMBAT] = function()
		return L["Only blocked during combat"]
	end,
	[AddonTable.GROUP_INVITE_BLOCK_ALWAYS] = function()
		return L["Always blocked"]
	end,
}

local function NormalizeBlockMode(mode)
	if mode == "INVITE_BACK" then
		return AddonTable.GROUP_INVITE_BLOCK_ALWAYS
	end
	if mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT
		or mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS then
		return mode
	end
	return AddonTable.GROUP_INVITE_BLOCK_NONE
end

function AddonTable.EnsureMGTGroupInviteConfig()
	MGTConfig = MGTConfig or {}
	if MGTConfig.BlockGroupInvites == nil then
		MGTConfig.BlockGroupInvites = "ENABLED"
	end
	if MGTConfig.GroupInviteBlockMode == nil then
		MGTConfig.GroupInviteBlockMode = AddonTable.GROUP_INVITE_BLOCK_NONE
	end
	if MGTConfig.MinimapBlockButton == nil then
		MGTConfig.MinimapBlockButton = "DISABLED"
	end
	if MGTConfig.MinimapBlockAngle == nil then
		MGTConfig.MinimapBlockAngle = MINIMAP_ANGLE
	end
	if MGTConfig.GroupInviteAllowGuildies == nil then
		MGTConfig.GroupInviteAllowGuildies = "ENABLED"
	end
	MGTConfig.GroupInviteBlockMode = NormalizeBlockMode(MGTConfig.GroupInviteBlockMode)
	if not MGTConfig.GroupInviteAlwaysOnMigrated then
		MGTConfig.BlockGroupInvites = "ENABLED"
		MGTConfig.GroupInviteAlwaysOnMigrated = true
	end
end

local function TrimString(s)
	if type(s) ~= "string" then
		return ""
	end
	if strtrim then
		return strtrim(s)
	end
	return s:match("^%s*(.-)%s*$") or ""
end

local function NormalizeInviterName(name)
	name = TrimString(name or "")
	if name == "" then
		return ""
	end
	if Ambiguate then
		name = Ambiguate(name, "none") or name
	end
	return name:match("^([^%-]+)") or name
end

local function ExtractGuildRosterName(index)
	if not GetGuildRosterInfo then
		return nil
	end
	local rosterName = GetGuildRosterInfo(index)
	if type(rosterName) ~= "string" or rosterName == "" then
		local results = { GetGuildRosterInfo(index) }
		rosterName = results[1]
	end
	if type(rosterName) ~= "string" or rosterName == "" then
		return nil
	end
	return rosterName
end

local function RememberGuildMemberName(rosterName)
	rosterName = TrimString(rosterName)
	if rosterName == "" then
		return
	end
	guildMemberNames[rosterName] = true
	local nameOnly = rosterName:match("^([^%-]+)")
	if nameOnly and nameOnly ~= rosterName then
		guildMemberNames[nameOnly] = true
	end
end

local function RebuildGuildMemberCache()
	for key in pairs(guildMemberNames) do
		guildMemberNames[key] = nil
	end
	if not IsInGuild or not IsInGuild() then
		return
	end
	if GuildRoster then
		GuildRoster()
	end
	local n = GetNumGuildMembers and GetNumGuildMembers()
	if not n or n <= 0 then
		return
	end
	for i = 1, n do
		local rosterName = ExtractGuildRosterName(i)
		if rosterName then
			RememberGuildMemberName(rosterName)
		end
	end
end

-- Exact name match; only strips -Realm when one side includes a realm suffix.
local function SameGuildPlayerName(inviterName, rosterName)
	inviterName = TrimString(inviterName)
	rosterName = TrimString(rosterName)
	if inviterName == "" or rosterName == "" then
		return false
	end
	if inviterName == rosterName then
		return true
	end
	local inviterBase = inviterName:match("^([^%-]+)") or inviterName
	local rosterBase = rosterName:match("^([^%-]+)") or rosterName
	if inviterBase ~= rosterBase then
		return false
	end
	return inviterName:find("-", 1, true) ~= nil or rosterName:find("-", 1, true) ~= nil
end

local function IsInviterGuildMember(inviterName)
	if not IsInGuild or not IsInGuild() then
		return false
	end
	inviterName = TrimString(inviterName)
	if inviterName == "" then
		return false
	end
	if guildMemberNames[inviterName] then
		return true
	end
	local inviterBase = inviterName:match("^([^%-]+)")
	if inviterBase and guildMemberNames[inviterBase] then
		return true
	end
	if not next(guildMemberNames) then
		RebuildGuildMemberCache()
		if guildMemberNames[inviterName] then
			return true
		end
		if inviterBase and guildMemberNames[inviterBase] then
			return true
		end
	end
	if GuildRoster then
		GuildRoster()
	end
	local n = GetNumGuildMembers and GetNumGuildMembers()
	if not n or n <= 0 then
		return false
	end
	for i = 1, n do
		local rosterName = ExtractGuildRosterName(i)
		if rosterName and SameGuildPlayerName(inviterName, rosterName) then
			RememberGuildMemberName(rosterName)
			return true
		end
	end
	return false
end
	local mode = AddonTable.GetGroupInviteBlockMode()
	return mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT
		or mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS
end

function AddonTable.IsGroupInviteBlockActive()
	AddonTable.EnsureMGTGroupInviteConfig()
	return MGTConfig.BlockGroupInvites == "ENABLED"
end

function AddonTable.SetGroupInviteBlockActive(enabled)
	AddonTable.EnsureMGTGroupInviteConfig()
	MGTConfig.BlockGroupInvites = "ENABLED"
	if not enabled then
		MGTConfig.GroupInviteBlockMode = AddonTable.GROUP_INVITE_BLOCK_NONE
	end
	AddonTable.RefreshGroupInviteBlocker()
	AddonTable.RefreshGroupInviteMinimapButton()
	if AddonTable.RefreshInvitationsOptionsUI then
		AddonTable.RefreshInvitationsOptionsUI()
	end
end

function AddonTable.GetGroupInviteBlockMode()
	AddonTable.EnsureMGTGroupInviteConfig()
	return MGTConfig.GroupInviteBlockMode
end

function AddonTable.SetGroupInviteBlockMode(mode)
	AddonTable.EnsureMGTGroupInviteConfig()
	mode = NormalizeBlockMode(mode)
	MGTConfig.GroupInviteBlockMode = mode
	MGTConfig.BlockGroupInvites = "ENABLED"
	AddonTable.UpdateGroupInviteMinimapIcon()
	AddonTable.RefreshGroupInviteMinimapButton()
	AddonTable.RefreshGroupInviteBlocker()
	if AddonTable.RefreshInvitationsOptionsUI then
		AddonTable.RefreshInvitationsOptionsUI()
	end
end

function AddonTable.IsMinimapBlockButtonEnabled()
	AddonTable.EnsureMGTGroupInviteConfig()
	return MGTConfig.MinimapBlockButton == "ENABLED"
end

function AddonTable.SetMinimapBlockButtonEnabled(enabled)
	AddonTable.EnsureMGTGroupInviteConfig()
	MGTConfig.MinimapBlockButton = enabled and "ENABLED" or "DISABLED"
	AddonTable.RefreshGroupInviteMinimapButton()
	if AddonTable.RefreshInvitationsOptionsUI then
		AddonTable.RefreshInvitationsOptionsUI()
	end
end

function AddonTable.IsGroupInviteAllowGuildiesEnabled()
	AddonTable.EnsureMGTGroupInviteConfig()
	return MGTConfig.GroupInviteAllowGuildies == "ENABLED"
end

function AddonTable.SetGroupInviteAllowGuildiesEnabled(enabled)
	AddonTable.EnsureMGTGroupInviteConfig()
	MGTConfig.GroupInviteAllowGuildies = enabled and "ENABLED" or "DISABLED"
	if AddonTable.RefreshInvitationsOptionsUI then
		AddonTable.RefreshInvitationsOptionsUI()
	end
end

function AddonTable.GetGroupInviteBlockModeLabel(mode)
	mode = NormalizeBlockMode(mode or AddonTable.GetGroupInviteBlockMode())
	local fn = BLOCK_MODE_LABELS[mode]
	return fn and fn() or L["Not blocked"]
end

local function ShouldDeclinePartyInvite(inviterName)
	if not AddonTable.IsGroupInviteBlockActive() then
		return false
	end
	local mode = AddonTable.GetGroupInviteBlockMode()
	local wouldBlock = false
	if mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS then
		wouldBlock = true
	elseif mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT and InCombatLockdown() then
		wouldBlock = true
	end
	if not wouldBlock then
		return false
	end
	if AddonTable.IsGroupInviteAllowGuildiesEnabled()
		and inviterName
		and IsInviterGuildMember(inviterName) then
		return false
	end
	return true
end

local function MessageContainsKeyword(message, keyword)
	if not message or keyword == "" then
		return false
	end
	return message:lower():find(keyword:lower(), 1, true) ~= nil
end

local function ShouldFilterAutoLayerWhispers()
	if not AddonTable.IsGroupInviteBlockActive or not AddonTable.IsGroupInviteBlockActive() then
		return false
	end
	local mode = AddonTable.GetGroupInviteBlockMode and AddonTable.GetGroupInviteBlockMode()
	return mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS
		or mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT
end

local function WhisperFilter_AutoLayer(_, _, message)
	if not ShouldFilterAutoLayerWhispers() then
		return false
	end
	if type(message) ~= "string" then
		return false
	end
	-- Suppress AutoLayer whispers when blocking is enabled.
	return message:sub(1, 11) == "[AutoLayer]"
end

local function HidePartyInvitePopups()
	if StaticPopup_Hide then
		StaticPopup_Hide("PARTY_INVITE")
		StaticPopup_Hide("PARTY_INVITE_XREALM")
	end
	if LFGInvitePopup and StaticPopupSpecial_Hide then
		StaticPopupSpecial_Hide(LFGInvitePopup)
	end
end

-- DeclineGroup must run during PARTY_INVITE_REQUEST (not next frame). Popup hide can wait.
local function DeclinePartyInvite()
	if DeclineGroup then
		DeclineGroup()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, HidePartyInvitePopups)
	else
		HidePartyInvitePopups()
	end
end

local function ClearPendingInvite()
	pendingInvite = nil
end

local function StartPendingInvite(inviterName)
	inviterName = NormalizeInviterName(inviterName)
	if inviterName == "" then
		return
	end

	pendingInviteGeneration = pendingInviteGeneration + 1
	local generation = pendingInviteGeneration
	pendingInvite = {
		inviter = inviterName,
	}

	if C_Timer and C_Timer.After then
		C_Timer.After(WHISPER_KEYWORD_WAIT_SECONDS, function()
			if pendingInvite and pendingInviteGeneration == generation then
				ClearPendingInvite()
			end
		end)
	end
end

local function TryDeclinePendingInvite(inviterName)
	if not pendingInvite or not ShouldDeclinePartyInvite(inviterName or pendingInvite.inviter) then
		return
	end
	if NormalizeInviterName(inviterName) ~= pendingInvite.inviter then
		return
	end
	DeclinePartyInvite()
	ClearPendingInvite()
end

local function OnPartyInviteRequest(inviterName)
	lastPartyInviterName = inviterName
	if not ShouldDeclinePartyInvite(inviterName) then
		return
	end
	DeclinePartyInvite()
end

local function InstallPartyInvitePopupHook()
	if partyInvitePopupHookInstalled or not hooksecurefunc then
		return
	end
	partyInvitePopupHookInstalled = true
	hooksecurefunc("StaticPopup_Show", function(which, inviterName)
		if which ~= "PARTY_INVITE" and which ~= "PARTY_INVITE_XREALM" then
			return
		end
		if type(inviterName) == "string" and inviterName ~= "" then
			lastPartyInviterName = inviterName
		end
		if not ShouldDeclinePartyInvite(inviterName or lastPartyInviterName) then
			return
		end
		if DeclineGroup then
			DeclineGroup()
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0, HidePartyInvitePopups)
		else
			HidePartyInvitePopups()
		end
	end)
end

function AddonTable.RefreshGroupInviteBlocker()
	if not blockFrame then
		return
	end
	if not AddonTable.IsGroupInviteBlockActive() then
		ClearPendingInvite()
	end
end

local function GetMinimapBlockAngle()
	AddonTable.EnsureMGTGroupInviteConfig()
	return MGTConfig.MinimapBlockAngle or MINIMAP_ANGLE
end

local function UpdateMinimapPosition()
	if not minimapButton then
		return
	end
	local angle = math.rad(GetMinimapBlockAngle())
	local x = math.cos(angle) * MINIMAP_RADIUS
	local y = math.sin(angle) * MINIMAP_RADIUS
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateMinimapPositionFromCursor()
	if not minimapButton or not Minimap then
		return
	end
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	local angle = math.deg(math.atan2(cy - my, cx - mx))
	MGTConfig.MinimapBlockAngle = angle
	UpdateMinimapPosition()
end

function AddonTable.UpdateGroupInviteMinimapIcon()
	if not minimapBg or not minimapLetter then
		return
	end
	local mode = AddonTable.GetGroupInviteBlockMode()
	local r, g, b = 0.3, 1, 0.3
	local letter = "N"
	if mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT then
		r, g, b = 1, 0.65, 0.1
		letter = "C"
	elseif mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS then
		r, g, b = 1, 0.2, 0.2
		letter = "B"
	end
	minimapBg:SetVertexColor(r, g, b)
	minimapLetter:SetText(letter)
	minimapLetter:SetTextColor(r, g, b)
end

function AddonTable.RefreshGroupInviteMinimapButton()
	if not minimapButton then
		return
	end
	-- Visible only when group invite blocking and the minimap shortcut are both enabled.
	local show = AddonTable.IsGroupInviteBlockActive() and AddonTable.IsMinimapBlockButtonEnabled()
	if show then
		UpdateMinimapPosition()
		AddonTable.UpdateGroupInviteMinimapIcon()
		minimapButton:Show()
	else
		minimapButton:Hide()
	end
end

local function OnMinimapBlockMenuClick(_, mode)
	AddonTable.SetGroupInviteBlockMode(mode)
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
end

local function InitMinimapBlockMenu(_, level)
	local current = AddonTable.GetGroupInviteBlockMode()

	-- Fresh info per row: AddButton sets info.disabled on titles and mutates the table.
	local titleInfo = UIDropDownMenu_CreateInfo()
	titleInfo.isTitle = true
	titleInfo.text = L["Group invite block mode:"]
	titleInfo.notCheckable = true
	UIDropDownMenu_AddButton(titleInfo)

	for _, mode in ipairs(MINIMAP_BLOCK_MENU_MODES) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = AddonTable.GetGroupInviteBlockModeLabel(mode)
		info.arg1 = mode
		info.checked = (mode == current)
		info.func = OnMinimapBlockMenuClick
		UIDropDownMenu_AddButton(info)
	end
end

local function ToggleMinimapBlockMenu()
	if not minimapButton then
		return
	end
	if not minimapMenuFrame then
		minimapMenuFrame = CreateFrame("Frame", "MGTMinimapBlockMenu", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(minimapMenuFrame, InitMinimapBlockMenu, "MENU")
	-- Classic: ToggleDropDownMenu(level, value, dropDownFrame, anchor, x, y)
	ToggleDropDownMenu(1, nil, minimapMenuFrame, minimapButton, 0, 0)
end

local function ShowMinimapTooltip()
	GameTooltip:SetOwner(minimapButton, "ANCHOR_LEFT")
	GameTooltip:AddLine(L["Minimap block menu click"], 1, 0.82, 0)
	GameTooltip:AddLine(L["Minimap block menu drag"], 0.7, 0.7, 0.7)
	GameTooltip:Show()
end

local function CreateMinimapButton()
	if minimapButton then
		return
	end

	minimapButton = CreateFrame("Button", "MGTGroupBlockMinimapButton", Minimap)
	minimapButton:SetSize(31, 31)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetFrameLevel(8)
	minimapButton:RegisterForClicks("LeftButtonUp")
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	minimapBg = minimapButton:CreateTexture(nil, "BACKGROUND")
	minimapBg:SetSize(20, 20)
	minimapBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	minimapBg:SetPoint("TOPLEFT", 7, -5)

	minimapLetter = minimapButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	minimapLetter:SetPoint("CENTER", 0, 0)
	minimapLetter:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

	minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
	minimapBorder:SetSize(53, 53)
	minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	minimapBorder:SetPoint("TOPLEFT")

	minimapButton:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		minimapDragActive = true
		minimapDragMoved = false
		local startX, startY = GetCursorPosition()
		self.dragStartX = startX
		self.dragStartY = startY
		self:SetScript("OnUpdate", function(frame)
			if not minimapDragActive then
				return
			end
			if not IsMouseButtonDown("LeftButton") then
				minimapDragActive = false
				frame:SetScript("OnUpdate", nil)
				return
			end
			local cx, cy = GetCursorPosition()
			if not minimapDragMoved then
				local dx = cx - frame.dragStartX
				local dy = cy - frame.dragStartY
				if (dx * dx + dy * dy) >= (MINIMAP_DRAG_THRESHOLD * MINIMAP_DRAG_THRESHOLD) then
					minimapDragMoved = true
					GameTooltip:Hide()
				end
			end
			if minimapDragMoved then
				UpdateMinimapPositionFromCursor()
			end
		end)
	end)

	minimapButton:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			minimapDragActive = false
			self:SetScript("OnUpdate", nil)
		end
	end)

	minimapButton:SetScript("OnClick", function(_, mouseButton)
		if mouseButton ~= "LeftButton" or minimapDragMoved then
			return
		end
		ToggleMinimapBlockMenu()
	end)

	minimapButton:SetScript("OnEnter", ShowMinimapTooltip)
	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	AddonTable.RefreshGroupInviteMinimapButton()
end

blockFrame = CreateFrame("Frame")
blockFrame:RegisterEvent("ADDON_LOADED")
blockFrame:RegisterEvent("PLAYER_LOGIN")
blockFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
blockFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
blockFrame:RegisterEvent("PARTY_INVITE_REQUEST")
blockFrame:SetScript("OnEvent", function(_, event, arg1, ...)
	if event == "ADDON_LOADED" and arg1 ~= AddonName then
		return
	end
	if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
		AddonTable.EnsureMGTGroupInviteConfig()
		InstallPartyInvitePopupHook()
		if ChatFrame_AddMessageEventFilter then
			ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", WhisperFilter_AutoLayer)
		end
		CreateMinimapButton()
		AddonTable.RefreshGroupInviteBlocker()
		AddonTable.RefreshGroupInviteMinimapButton()
		RebuildGuildMemberCache()
	elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
		RebuildGuildMemberCache()
	elseif event == "PARTY_INVITE_REQUEST" then
		OnPartyInviteRequest(...)
	end
end)

AddonTable.EnsureMGTGroupInviteConfig()
