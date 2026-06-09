local AddonName, AddonTable = ...
local L = AddonTable.Localize

AddonTable.GROUP_INVITE_BLOCK_NONE = "NONE"
AddonTable.GROUP_INVITE_BLOCK_COMBAT = "COMBAT"
AddonTable.GROUP_INVITE_BLOCK_ALWAYS = "ALWAYS"

local BLOCK_ICON = "Interface\\Icons\\INV_Misc_Banner_01"
local MINIMAP_ANGLE = 225
local MINIMAP_RADIUS = 80
local MINIMAP_DRAG_THRESHOLD = 4
local WHISPER_KEYWORD_WAIT_SECONDS = 1
local GROUP_INVITE_KEYWORD_MAX_STORED = 128

local blockFrame
local pendingInvite
local pendingInviteGeneration = 0
local minimapButton
local minimapIcon
local minimapLetterBgOuter
local minimapLetterBgInner
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
		MGTConfig.BlockGroupInvites = "DISABLED"
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
	MGTConfig.GroupInviteBlockMode = NormalizeBlockMode(MGTConfig.GroupInviteBlockMode)
	if not MGTConfig.GroupInviteLegacyModeMigrated then
		if MGTConfig.BlockGroupInvites == "ENABLED"
			and MGTConfig.GroupInviteBlockMode == AddonTable.GROUP_INVITE_BLOCK_NONE then
			MGTConfig.GroupInviteBlockMode = AddonTable.GROUP_INVITE_BLOCK_ALWAYS
		end
		MGTConfig.GroupInviteLegacyModeMigrated = true
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

function AddonTable.IsGroupInviteKeywordMode()
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
	MGTConfig.BlockGroupInvites = enabled and "ENABLED" or "DISABLED"
	if enabled and MGTConfig.GroupInviteBlockMode == AddonTable.GROUP_INVITE_BLOCK_NONE then
		MGTConfig.GroupInviteBlockMode = AddonTable.GROUP_INVITE_BLOCK_ALWAYS
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
	if mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT
		or mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS then
		MGTConfig.BlockGroupInvites = "ENABLED"
	elseif mode == AddonTable.GROUP_INVITE_BLOCK_NONE then
		MGTConfig.BlockGroupInvites = "DISABLED"
	end
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

function AddonTable.GetGroupInviteBlockModeLabel(mode)
	mode = NormalizeBlockMode(mode or AddonTable.GetGroupInviteBlockMode())
	local fn = BLOCK_MODE_LABELS[mode]
	return fn and fn() or L["Not blocked"]
end

-- Same logic as v0.4.0 (before whisper keyword): checkbox on + mode decides blocking.
local function ShouldDeclinePartyInvite()
	if not AddonTable.IsGroupInviteBlockActive() then
		return false
	end
	local mode = AddonTable.GetGroupInviteBlockMode()
	if mode == AddonTable.GROUP_INVITE_BLOCK_ALWAYS then
		return true
	end
	if mode == AddonTable.GROUP_INVITE_BLOCK_COMBAT and InCombatLockdown() then
		return true
	end
	return false
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
	if not pendingInvite or not ShouldDeclinePartyInvite() then
		return
	end
	if NormalizeInviterName(inviterName) ~= pendingInvite.inviter then
		return
	end
	DeclinePartyInvite()
	ClearPendingInvite()
end

local function OnPartyInviteRequest(inviterName)
	if not ShouldDeclinePartyInvite() then
		return
	end
	DeclinePartyInvite()
end

local function InstallPartyInvitePopupHook()
	if partyInvitePopupHookInstalled or not hooksecurefunc then
		return
	end
	partyInvitePopupHookInstalled = true
	hooksecurefunc("StaticPopup_Show", function(which)
		if which ~= "PARTY_INVITE" and which ~= "PARTY_INVITE_XREALM" then
			return
		end
		if not ShouldDeclinePartyInvite() then
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
	if not minimapIcon or not minimapLetter then
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
	minimapIcon:SetVertexColor(r, g, b)
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
	minimapButton:SetSize(32, 32)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetFrameLevel(8)
	minimapButton:RegisterForClicks("LeftButtonUp")

	minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
	minimapIcon:SetSize(24, 24)
	minimapIcon:SetPoint("CENTER")
	minimapIcon:SetTexture(BLOCK_ICON)
	minimapIcon:SetAlpha(0.35)

	minimapLetterBgOuter = minimapButton:CreateTexture(nil, "BORDER")
	minimapLetterBgOuter:SetSize(26, 26)
	minimapLetterBgOuter:SetPoint("CENTER")
	minimapLetterBgOuter:SetTexture("Interface\\Minimap\\Ping\\ping5")
	minimapLetterBgOuter:SetVertexColor(0.55, 0.55, 0.55, 1)

	minimapLetterBgInner = minimapButton:CreateTexture(nil, "ARTWORK")
	minimapLetterBgInner:SetSize(20, 20)
	minimapLetterBgInner:SetPoint("CENTER")
	minimapLetterBgInner:SetTexture("Interface\\Minimap\\Ping\\ping5")
	minimapLetterBgInner:SetVertexColor(0.98, 0.98, 0.98, 0.96)

	minimapLetter = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	minimapLetter:SetPoint("CENTER", 0, 0)
	minimapLetter:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

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
	elseif event == "PARTY_INVITE_REQUEST" then
		OnPartyInviteRequest(...)
	end
end)

AddonTable.EnsureMGTGroupInviteConfig()
