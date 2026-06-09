local AddonName, AddonTable = ...
local L = AddonTable.Localize
local AddonTitle = select(2, C_AddOns.GetAddOnInfo(AddonName))
local PlainAddonTitle = AddonTitle:gsub("|c........", ""):gsub("|r", "")

local GTOptions = CreateFrame("Frame")
GTOptions:RegisterEvent("ADDON_LOADED")
GTOptions:RegisterEvent("VARIABLES_LOADED")

local function GTOptionsHandler(self, event, arg1)

if event == "VARIABLES_LOADED" then
	if C_AddOns.IsAddOnLoaded("GuildTradeskills") == true then
		SlashCmdList["MGTCONFIG"] = mgtconfiguration;
			SLASH_MGTCONFIG1 = "/mgtool"
			
		DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r MyGuildTools has detected that you are also using the Guild Tradeskills addon; to prevent interference, the command to access MyGuildTools's options window has been changed to /mgtool.")
	elseif C_AddOns.IsAddOnLoaded("GuildTradeskills") == false then
		SlashCmdList["MGTCONFIG"] = mgtconfiguration;
			SLASH_MGTCONFIG1 = "/mgt"
	end
end

end

GTOptions:SetScript("OnEvent", GTOptionsHandler)

-- INTERFACE OPTIONS

local GTIOFrame = CreateFrame("Frame")
GTIOFrame.name = L["MyGuildTools"]

-- Header

local lblTitle = GTIOFrame:CreateFontString(nil, nil, "GameFontHighlight")
lblTitle:SetFont("Fonts\\FRIZQT__.TTF", 12)
lblTitle:SetPoint("TOPLEFT", GTIOFrame, "TOPLEFT", 12, -12)
lblTitle:SetText(L["MyGuildTools"] .. " v" .. C_AddOns.GetAddOnMetadata(AddonName, "Version"))

local lblTip = GTIOFrame:CreateFontString(nil, nil, "GameFontDisableSmall")
lblTip:SetPoint("BOTTOMLEFT", GTIOFrame, "BOTTOMLEFT", 12, 12)
lblTip:SetPoint("BOTTOMRIGHT", GTIOFrame, "BOTTOMRIGHT", -12, 12)
lblTip:SetJustifyH("CENTER")
lblTip:SetText(L["Tip line"])

local optionsScroll = CreateFrame("ScrollFrame", "MGTOptionsScroll", GTIOFrame, "UIPanelScrollFrameTemplate")
optionsScroll:SetPoint("TOPLEFT", lblTitle, "BOTTOMLEFT", -4, -12)
optionsScroll:SetPoint("BOTTOMRIGHT", GTIOFrame, "BOTTOMRIGHT", -28, 36)

local optionsScrollChild = CreateFrame("Frame", nil, optionsScroll)
optionsScrollChild:SetWidth(420)
optionsScroll:SetScrollChild(optionsScrollChild)

if optionsScroll.SetClipsChildren then
	optionsScroll:SetClipsChildren(true)
end
if optionsScrollChild.SetClipsChildren then
	optionsScrollChild:SetClipsChildren(true)
end

-- Tooltip options section

local tooltipBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
tooltipBox:SetPoint("TOPLEFT", optionsScrollChild, "TOPLEFT", 0, 0)
tooltipBox:SetSize(420, 268)
tooltipBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
tooltipBox:SetBackdropColor(0, 0, 0, 0.5)

local lblTooltipSection = tooltipBox:CreateFontString(nil, nil, "GameFontNormalLarge")
lblTooltipSection:SetPoint("TOPLEFT", tooltipBox, "TOPLEFT", 12, -8)
lblTooltipSection:SetText(L["Tooltip"])

-- Use Colours

local chkIOUseColours = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOUseColours:SetPoint("TOPLEFT", lblTooltipSection, "BOTTOMLEFT", 0, -8)

chkIOUseColours:SetScript("OnUpdate", function(frame)
	if MGTConfig.Colour == "ENABLED" then
		chkIOUseColours:SetChecked(true)
	elseif MGTConfig.Colour == "DISABLED" then
		chkIOUseColours:SetChecked(false)
	end
end)

chkIOUseColours:SetScript("OnClick", function(frame)
local tick = frame:GetChecked()

	if tick == false then
		MGTConfig.Colour = 'DISABLED'
	elseif tick == true then
		MGTConfig.Colour = 'ENABLED'
	end
end)

local chkIOUseColoursText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkIOUseColoursText:SetPoint("LEFT", chkIOUseColours, "RIGHT", 0, 1)
chkIOUseColoursText:SetText(L["Use colours"])

-- Show Healthbar

local chkIOShowHPBar = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOShowHPBar:SetPoint("TOPLEFT", chkIOUseColours, "BOTTOMLEFT", 0, -8)

chkIOShowHPBar:SetScript("OnUpdate", function(frame)
	if MGTConfig.HealthBar == "ENABLED" then
		chkIOShowHPBar:SetChecked(true)
	elseif MGTConfig.HealthBar == "DISABLED" then
		chkIOShowHPBar:SetChecked(false)
	end
end)

chkIOShowHPBar:SetScript("OnClick", function(frame)
local tick = frame:GetChecked()

	if tick == false then
		MGTConfig.HealthBar = 'DISABLED'
	elseif tick == true then
		MGTConfig.HealthBar = 'ENABLED'
	end
end)

local chkIOShowHPBarText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkIOShowHPBarText:SetPoint("LEFT", chkIOShowHPBar, "RIGHT", 0, 1)
chkIOShowHPBarText:SetText(L["Show healthbar under player tooltips"])

-- Tooltip format

local lblTooltipFormat = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
lblTooltipFormat:SetPoint("TOPLEFT", chkIOShowHPBar, "BOTTOMLEFT", 0, -12)
lblTooltipFormat:SetText(L["Tooltip format:"])

local editTooltipFormatBg = CreateFrame("Frame", nil, tooltipBox, "BackdropTemplate")
editTooltipFormatBg:SetPoint("TOPLEFT", lblTooltipFormat, "BOTTOMLEFT", -4, 4)
editTooltipFormatBg:SetSize(388, 68)
editTooltipFormatBg:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
editTooltipFormatBg:SetBackdropColor(0, 0, 0, 0.35)

local editTooltipFormat = CreateFrame("EditBox", nil, editTooltipFormatBg)
editTooltipFormat:SetPoint("TOPLEFT", editTooltipFormatBg, "TOPLEFT", 6, -6)
editTooltipFormat:SetPoint("BOTTOMRIGHT", editTooltipFormatBg, "BOTTOMRIGHT", -6, 6)
editTooltipFormat:SetFontObject(ChatFontNormal)
editTooltipFormat:SetMultiLine(true)
editTooltipFormat:SetAutoFocus(false)
editTooltipFormat:SetMaxLetters(512)
editTooltipFormat:EnableMouse(true)

local function GetTooltipFormatDefault()
	return "%GUILD% %RANK%"
end

local function MigrateTooltipFormat(text)
	if not text or text == "" then
		return GetTooltipFormatDefault()
	end
	if not text:find("%%NAME%%", 1, true)
		and not text:find("%%LEVEL%%", 1, true)
		and not text:find("%%RACE%%", 1, true)
		and not text:find("%%CLASS%%", 1, true) then
		return text
	end
	local lines = {}
	for line in text:gmatch("[^\n]+") do
		if not line:find("%%NAME%%", 1, true)
			and not line:find("%%LEVEL%%", 1, true)
			and not line:find("%%RACE%%", 1, true)
			and not line:find("%%CLASS%%", 1, true) then
			lines[#lines + 1] = line
		end
	end
	if #lines > 0 then
		return table.concat(lines, "\n")
	end
	return GetTooltipFormatDefault()
end

local function TrimTooltipFormat(text)
	if strtrim then
		return strtrim(text or "")
	end
	return (text or ""):match("^%s*(.-)%s*$") or ""
end

editTooltipFormat:SetScript("OnShow", function(self)
	if MGTConfig and MGTConfig.TooltipFormat and MGTConfig.TooltipFormat ~= "" then
		self:SetText(MigrateTooltipFormat(MGTConfig.TooltipFormat))
	else
		self:SetText(GetTooltipFormatDefault())
	end
end)

editTooltipFormat:SetScript("OnEditFocusLost", function(self)
	if not MGTConfig then
		return
	end
	local text = MigrateTooltipFormat(TrimTooltipFormat(self:GetText() or ""))
	if text == "" then
		text = GetTooltipFormatDefault()
	end
	MGTConfig.TooltipFormat = text
	self:SetText(text)
end)

editTooltipFormat:SetScript("OnEscapePressed", function(self)
	if MGTConfig and MGTConfig.TooltipFormat then
		self:SetText(MGTConfig.TooltipFormat)
	else
		self:SetText(GetTooltipFormatDefault())
	end
	self:ClearFocus()
end)

local lblTooltipFormatLegend = tooltipBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblTooltipFormatLegend:SetPoint("TOPLEFT", editTooltipFormatBg, "BOTTOMLEFT", 0, -4)
lblTooltipFormatLegend:SetWidth(380)
lblTooltipFormatLegend:SetJustifyH("LEFT")
lblTooltipFormatLegend:SetText(L["Tooltip format legend"])

-- Guild notes (our guild roster only)

local chkIOGuildNotes = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOGuildNotes:SetPoint("TOPLEFT", lblTooltipFormatLegend, "BOTTOMLEFT", 0, -8)

chkIOGuildNotes:SetScript("OnUpdate", function(frame)
	if MGTConfig.GuildNotes == "ENABLED" then
		chkIOGuildNotes:SetChecked(true)
	elseif MGTConfig.GuildNotes == "DISABLED" then
		chkIOGuildNotes:SetChecked(false)
	end
end)

chkIOGuildNotes:SetScript("OnClick", function(frame)
	local tick = frame:GetChecked()
	if tick == false then
		MGTConfig.GuildNotes = "DISABLED"
	elseif tick == true then
		MGTConfig.GuildNotes = "ENABLED"
	end
end)

local chkIOGuildNotesText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkIOGuildNotesText:SetPoint("LEFT", chkIOGuildNotes, "RIGHT", 0, 1)
chkIOGuildNotesText:SetText(L["Add guild notes when available"])

-- Font Size

local lblIOFontSizeText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
lblIOFontSizeText:SetPoint("TOPLEFT", chkIOGuildNotes, "BOTTOMLEFT", 0, -8)
lblIOFontSizeText:SetText(L["Tooltip font size:"])

--local ddFontSize = CreateFrame("Frame", "GTFontSize", GTIOFrame, "UIDropDownMenuTemplate")

-- Create the dropdown, and configure its appearance
local ddFontSize = CreateFrame("FRAME", "MGTFontSize", tooltipBox, "UIDropDownMenuTemplate")
ddFontSize:SetPoint("LEFT", lblIOFontSizeText, "RIGHT", 0, 1)
if GetLocale() == "frFR" then
	UIDropDownMenu_SetWidth(ddFontSize, 128)
else
	UIDropDownMenu_SetWidth(ddFontSize, 96)
end
local MGT_FONT_SIZE_OPTIONS = { 12, 14, 16, 18, 20 }

local function MGTNormalizeFontSize(size)
	local n = tonumber(size)
	for _, option in ipairs(MGT_FONT_SIZE_OPTIONS) do
		if n == option then
			return tostring(option)
		end
	end
	return "14"
end

local function RefreshFontSizeDropdown()
	if not ddFontSize or not MGTConfig then
		return
	end
	local size = MGTNormalizeFontSize(MGTConfig.FontSize)
	MGTConfig.FontSize = size
	UIDropDownMenu_SetText(ddFontSize, size)
end

UIDropDownMenu_Initialize(ddFontSize, function(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo()
	local current = MGTNormalizeFontSize(MGTConfig and MGTConfig.FontSize)
	info.func = self.SetValue
	for _, size in ipairs(MGT_FONT_SIZE_OPTIONS) do
		info.text = tostring(size)
		info.arg1 = size
		info.checked = (tostring(size) == current)
		UIDropDownMenu_AddButton(info)
	end
end)

function ddFontSize:SetValue(newValue)
	if not MGTConfig then
		return
	end
	MGTConfig.FontSize = tostring(newValue)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[" .. L["MyGuildTools"] .. "]|r " .. L["Font size changed to"] .. " " .. MGTConfig.FontSize .. ".")
	UIDropDownMenu_SetText(ddFontSize, MGTConfig.FontSize)
	CloseDropDownMenus()
end

ddFontSize:SetScript("OnShow", RefreshFontSizeDropdown)
RefreshFontSizeDropdown()

-- Invitations options section

local invitationsBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
invitationsBox:SetPoint("TOPLEFT", tooltipBox, "BOTTOMLEFT", 0, -16)
invitationsBox:SetSize(420, 112)
invitationsBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
invitationsBox:SetBackdropColor(0, 0, 0, 0.5)

local lblInvitationsSection = invitationsBox:CreateFontString(nil, nil, "GameFontNormalLarge")
lblInvitationsSection:SetPoint("TOPLEFT", invitationsBox, "TOPLEFT", 12, -8)
lblInvitationsSection:SetText(L["Invitations"])

local guildInviteOpts = {}

guildInviteOpts.checkbox = CreateFrame("CheckButton", nil, invitationsBox, "OptionsBaseCheckButtonTemplate")
guildInviteOpts.checkbox:SetPoint("TOPLEFT", lblInvitationsSection, "BOTTOMLEFT", 0, -8)

guildInviteOpts.label = invitationsBox:CreateFontString(nil, nil, "GameFontHighlight")
guildInviteOpts.label:SetPoint("LEFT", guildInviteOpts.checkbox, "RIGHT", 0, 1)
guildInviteOpts.label:SetText(L["Add a right-click menu to /ginvite"])

guildInviteOpts.hint = invitationsBox:CreateFontString(nil, nil, "GameFontDisableSmall")
guildInviteOpts.hint:SetPoint("TOPLEFT", guildInviteOpts.checkbox, "BOTTOMLEFT", 16, -8)
guildInviteOpts.hint:SetPoint("RIGHT", invitationsBox, "RIGHT", -12, 0)
guildInviteOpts.hint:SetJustifyH("LEFT")
guildInviteOpts.hint:SetJustifyV("TOP")
guildInviteOpts.hint:SetSpacing(4)
guildInviteOpts.hint:SetText(L["Guild invite key hint"])

local chkBlockGroupInvites = CreateFrame("CheckButton", nil, invitationsBox, "OptionsBaseCheckButtonTemplate")
chkBlockGroupInvites:SetPoint("TOPLEFT", guildInviteOpts.hint, "BOTTOMLEFT", -16, -8)

local lblBlockGroupInvites = invitationsBox:CreateFontString(nil, nil, "GameFontHighlight")
lblBlockGroupInvites:SetPoint("LEFT", chkBlockGroupInvites, "RIGHT", 0, 1)
lblBlockGroupInvites:SetText(L["Block Group Invitations"])

local chkMinimapBlockButton = CreateFrame("CheckButton", nil, invitationsBox, "OptionsBaseCheckButtonTemplate")
chkMinimapBlockButton:SetPoint("TOPLEFT", chkBlockGroupInvites, "BOTTOMLEFT", 0, -4)

local lblMinimapBlockButton = invitationsBox:CreateFontString(nil, nil, "GameFontHighlight")
lblMinimapBlockButton:SetPoint("LEFT", chkMinimapBlockButton, "RIGHT", 0, 1)
lblMinimapBlockButton:SetText(L["Add minimap shortcut button"])

local lblGroupBlockMode = invitationsBox:CreateFontString(nil, nil, "GameFontHighlight")
lblGroupBlockMode:SetPoint("TOPLEFT", chkMinimapBlockButton, "BOTTOMLEFT", 0, -8)
lblGroupBlockMode:SetPoint("RIGHT", invitationsBox, "RIGHT", -12, 0)
lblGroupBlockMode:SetJustifyH("LEFT")
lblGroupBlockMode:SetText(L["Group invite block mode:"])

local ddGroupBlockMode = CreateFrame("FRAME", "MGTGroupBlockMode", invitationsBox, "UIDropDownMenuTemplate")
ddGroupBlockMode:SetPoint("TOPLEFT", lblGroupBlockMode, "BOTTOMLEFT", -16, -4)
if GetLocale() == "frFR" then
	UIDropDownMenu_SetWidth(ddGroupBlockMode, 220)
else
	UIDropDownMenu_SetWidth(ddGroupBlockMode, 200)
end

local GROUP_BLOCK_MODE_OPTIONS = {
	AddonTable.GROUP_INVITE_BLOCK_NONE,
	AddonTable.GROUP_INVITE_BLOCK_COMBAT,
	AddonTable.GROUP_INVITE_BLOCK_ALWAYS,
}

local groupBlockDropdownInitialized = false

local function OnGroupBlockModeSelected(_, mode)
	ddGroupBlockMode:SetValue(mode)
end

local function InitGroupBlockModeDropdown()
	if groupBlockDropdownInitialized then
		return
	end
	groupBlockDropdownInitialized = true
	if AddonTable.EnsureMGTGroupInviteConfig then
		AddonTable.EnsureMGTGroupInviteConfig()
	end
	UIDropDownMenu_Initialize(ddGroupBlockMode, function(_, level, menuList)
		local current = AddonTable.GetGroupInviteBlockMode and AddonTable.GetGroupInviteBlockMode()
		for _, mode in ipairs(GROUP_BLOCK_MODE_OPTIONS) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = AddonTable.GetGroupInviteBlockModeLabel(mode)
			info.arg1 = mode
			info.checked = (mode == current)
			info.func = OnGroupBlockModeSelected
			UIDropDownMenu_AddButton(info)
		end
	end)
end

local function RefreshGroupBlockModeDropdown()
	if not ddGroupBlockMode or not AddonTable.GetGroupInviteBlockMode then
		return
	end
	InitGroupBlockModeDropdown()
	local mode = AddonTable.GetGroupInviteBlockMode()
	UIDropDownMenu_SetText(ddGroupBlockMode, AddonTable.GetGroupInviteBlockModeLabel(mode))
end

local groupBlockDropdownInit = CreateFrame("Frame")
groupBlockDropdownInit:RegisterEvent("ADDON_LOADED")
groupBlockDropdownInit:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon == AddonName then
		InitGroupBlockModeDropdown()
		self:UnregisterAllEvents()
	end
end)

local function UpdateInvitationsBoxHeight()
	local hintH = math.max(guildInviteOpts.hint:GetStringHeight() or 0, 14)
	local h = 8 + 16 + 4 + 22 + 8 + hintH + 8 + 22 + 14
	if AddonTable.IsGroupInviteBlockActive and AddonTable.IsGroupInviteBlockActive() then
		h = h + 22 + 8 + 22 + 8 + 14 + 8 + 32 + 14
	end
	invitationsBox:SetHeight(h)
end

local function RefreshInvitationsBlockControls()
	local blockActive = AddonTable.IsGroupInviteBlockActive and AddonTable.IsGroupInviteBlockActive()
	if blockActive then
		chkMinimapBlockButton:Show()
		lblMinimapBlockButton:Show()
		lblGroupBlockMode:Show()
		ddGroupBlockMode:Show()
	else
		chkMinimapBlockButton:Hide()
		lblMinimapBlockButton:Hide()
		lblGroupBlockMode:Hide()
		ddGroupBlockMode:Hide()
	end
	UpdateInvitationsBoxHeight()
end

function ddGroupBlockMode:SetValue(newMode)
	if AddonTable.SetGroupInviteBlockMode then
		AddonTable.SetGroupInviteBlockMode(newMode)
	end
	RefreshGroupBlockModeDropdown()
	RefreshInvitationsBlockControls()
	CloseDropDownMenus()
end

function AddonTable.RefreshInvitationsOptionsUI()
	if AddonTable.IsGroupInviteBlockActive then
		chkBlockGroupInvites:SetChecked(AddonTable.IsGroupInviteBlockActive())
	end
	if AddonTable.IsMinimapBlockButtonEnabled then
		chkMinimapBlockButton:SetChecked(AddonTable.IsMinimapBlockButtonEnabled())
	end
	RefreshGroupBlockModeDropdown()
	RefreshInvitationsBlockControls()
	if UpdateOptionsScrollHeight then
		UpdateOptionsScrollHeight()
	end
end

chkBlockGroupInvites:SetScript("OnClick", function(frame)
	if not AddonTable.SetGroupInviteBlockActive then
		return
	end
	AddonTable.SetGroupInviteBlockActive(frame:GetChecked() == true)
	RefreshInvitationsBlockControls()
end)

chkMinimapBlockButton:SetScript("OnClick", function(frame)
	if not AddonTable.SetMinimapBlockButtonEnabled then
		return
	end
	AddonTable.SetMinimapBlockButtonEnabled(frame:GetChecked() == true)
end)

local function RefreshGuildInviteOptionsUI()
	local checkbox = guildInviteOpts.checkbox
	local label = guildInviteOpts.label
	local hint = guildInviteOpts.hint
	if not checkbox or not label or not hint then
		return
	end

	if AddonTable.SyncGuildInviteMenuForCharacter then
		AddonTable.SyncGuildInviteMenuForCharacter()
	end

	local setting = AddonTable.GetGuildInviteMenuSetting and AddonTable.GetGuildInviteMenuSetting()
	local wantsEnabled = setting == "ENABLED"
	local canUse = AddonTable.PlayerCanGuildInvite and AddonTable.PlayerCanGuildInvite()
	checkbox:SetChecked(wantsEnabled)
	if canUse then
		checkbox:Enable()
		label:SetTextColor(1, 0.82, 0)
		hint:SetTextColor(0.5, 0.5, 0.5)
	else
		checkbox:Disable()
		label:SetTextColor(0.5, 0.5, 0.5)
		hint:SetTextColor(0.35, 0.35, 0.35)
	end
end

AddonTable.RefreshGuildInviteOptionsUI = RefreshGuildInviteOptionsUI

guildInviteOpts.checkbox:SetScript("OnClick", function(frame)
	if not AddonTable.SetGuildInviteMenuSetting then
		return
	end
	if not AddonTable.PlayerCanGuildInvite or not AddonTable.PlayerCanGuildInvite() then
		local setting = AddonTable.GetGuildInviteMenuSetting and AddonTable.GetGuildInviteMenuSetting()
		frame:SetChecked(setting == "ENABLED")
		if not IsInGuild or not IsInGuild() then
			DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r " .. L["You are not in a guild."])
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r " .. L["You don't have permission to invite guild members."])
		end
		return
	end
	AddonTable.SetGuildInviteMenuSetting(frame:GetChecked() and "ENABLED" or "DISABLED")
end)

local guildInviteOptionsWatcher = CreateFrame("Frame")
guildInviteOptionsWatcher:RegisterEvent("ADDON_LOADED")
guildInviteOptionsWatcher:RegisterEvent("PLAYER_GUILD_UPDATE")
guildInviteOptionsWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
guildInviteOptionsWatcher:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 ~= AddonName then
		return
	end
	RefreshGuildInviteOptionsUI()
end)

-- Honor Guild Death

local honorGuildDeathBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
honorGuildDeathBox:SetPoint("TOPLEFT", invitationsBox, "BOTTOMLEFT", 0, -16)
honorGuildDeathBox:SetSize(420, 272)
honorGuildDeathBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
honorGuildDeathBox:SetBackdropColor(0, 0, 0, 0.5)

local lblHonorGuildDeathSection = honorGuildDeathBox:CreateFontString(nil, nil, "GameFontNormalLarge")
lblHonorGuildDeathSection:SetPoint("TOPLEFT", honorGuildDeathBox, "TOPLEFT", 12, -8)
lblHonorGuildDeathSection:SetText(L["Honor Guild Death"])

local chkHonorGuildDeathAuto = CreateFrame("CheckButton", nil, honorGuildDeathBox, "OptionsBaseCheckButtonTemplate")
chkHonorGuildDeathAuto:SetPoint("TOPLEFT", lblHonorGuildDeathSection, "BOTTOMLEFT", 0, -8)

chkHonorGuildDeathAuto:SetScript("OnUpdate", function(frame)
	if MGTConfig and MGTConfig.HonorGuildDeathAuto == "ENABLED" then
		frame:SetChecked(true)
	elseif MGTConfig and MGTConfig.HonorGuildDeathAuto == "DISABLED" then
		frame:SetChecked(false)
	end
end)

chkHonorGuildDeathAuto:SetScript("OnClick", function(frame)
	if not MGTConfig then
		return
	end
	if frame:GetChecked() then
		MGTConfig.HonorGuildDeathAuto = "ENABLED"
		if AddonTable.RefreshHonorGuildChannel then
			AddonTable.RefreshHonorGuildChannel()
		end
		if AddonTable.RefreshHonorGuildRoster then
			AddonTable.RefreshHonorGuildRoster()
		end
	else
		MGTConfig.HonorGuildDeathAuto = "DISABLED"
	end
	RefreshHonorGuildDeathUI()
end)

local chkHonorGuildDeathAutoText = honorGuildDeathBox:CreateFontString(nil, nil, "GameFontHighlight")
chkHonorGuildDeathAutoText:SetPoint("LEFT", chkHonorGuildDeathAuto, "RIGHT", 0, 1)
chkHonorGuildDeathAutoText:SetText(L["Automatically honor fallen heroes"])

local chkHonorGuildDeathDebug = CreateFrame("CheckButton", nil, honorGuildDeathBox, "OptionsBaseCheckButtonTemplate")
chkHonorGuildDeathDebug:SetPoint("TOPLEFT", chkHonorGuildDeathAuto, "BOTTOMLEFT", 0, -8)

chkHonorGuildDeathDebug:SetScript("OnUpdate", function(frame)
	if not MGTConfig then
		return
	end
	if MGTConfig.HonorGuildDeathDebug == "ENABLED" then
		frame:SetChecked(true)
	elseif MGTConfig.HonorGuildDeathDebug == "DISABLED" then
		frame:SetChecked(false)
	end
end)

chkHonorGuildDeathDebug:SetScript("OnClick", function(frame)
	if not MGTConfig then
		return
	end
	if frame:GetChecked() then
		MGTConfig.HonorGuildDeathDebug = "ENABLED"
	else
		MGTConfig.HonorGuildDeathDebug = "DISABLED"
	end
	if AddonTable.RefreshHonorGuildChannel then
		AddonTable.RefreshHonorGuildChannel()
	end
	if AddonTable.RefreshHonorGuildRoster then
		AddonTable.RefreshHonorGuildRoster()
	end
	RefreshHonorGuildDeathUI()
end)

local chkHonorGuildDeathDebugText = honorGuildDeathBox:CreateFontString(nil, nil, "GameFontHighlight")
chkHonorGuildDeathDebugText:SetPoint("LEFT", chkHonorGuildDeathDebug, "RIGHT", 0, 1)
chkHonorGuildDeathDebugText:SetText(L["Debug (HardcoreDeathsDebug + print)"])

local lblHonorChannelStatus = honorGuildDeathBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblHonorChannelStatus:SetPoint("TOPLEFT", chkHonorGuildDeathDebug, "BOTTOMLEFT", 0, -4)
lblHonorChannelStatus:SetPoint("RIGHT", honorGuildDeathBox, "RIGHT", -12, 0)
lblHonorChannelStatus:SetJustifyH("LEFT")
lblHonorChannelStatus:SetHeight(28)

local lblHonorGuildDeathFormat = honorGuildDeathBox:CreateFontString(nil, nil, "GameFontHighlight")
lblHonorGuildDeathFormat:SetPoint("TOPLEFT", lblHonorChannelStatus, "BOTTOMLEFT", 0, -4)
lblHonorGuildDeathFormat:SetText(L["Honor message format:"])

local editHonorFormatBg = CreateFrame("Frame", nil, honorGuildDeathBox, "BackdropTemplate")
editHonorFormatBg:SetPoint("TOPLEFT", lblHonorGuildDeathFormat, "BOTTOMLEFT", -4, 4)
editHonorFormatBg:SetSize(388, 68)
editHonorFormatBg:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
editHonorFormatBg:SetBackdropColor(0, 0, 0, 0.35)

local editHonorFormat = CreateFrame("EditBox", nil, editHonorFormatBg)
editHonorFormat:SetPoint("TOPLEFT", editHonorFormatBg, "TOPLEFT", 6, -6)
editHonorFormat:SetPoint("BOTTOMRIGHT", editHonorFormatBg, "BOTTOMRIGHT", -6, 6)
editHonorFormat:SetFontObject(ChatFontNormal)
editHonorFormat:SetMultiLine(true)
editHonorFormat:SetAutoFocus(false)
editHonorFormat:SetMaxLetters(512)
editHonorFormat:EnableMouse(true)

local function GetHonorFormatDefault()
	return "F"
end

local function TrimHonorFormat(text)
	if strtrim then
		return strtrim(text or "")
	end
	return (text or ""):match("^%s*(.-)%s*$") or ""
end

editHonorFormat:SetScript("OnShow", function(self)
	if MGTConfig and MGTConfig.HonorGuildDeathFormat and MGTConfig.HonorGuildDeathFormat ~= "" then
		self:SetText(MGTConfig.HonorGuildDeathFormat)
	else
		self:SetText(GetHonorFormatDefault())
	end
end)

editHonorFormat:SetScript("OnEditFocusLost", function(self)
	if not MGTConfig then
		return
	end
	local text = TrimHonorFormat(self:GetText() or "")
	if text == "" then
		text = GetHonorFormatDefault()
	end
	MGTConfig.HonorGuildDeathFormat = text
	self:SetText(text)
end)

editHonorFormat:SetScript("OnEscapePressed", function(self)
	if MGTConfig and MGTConfig.HonorGuildDeathFormat then
		self:SetText(MGTConfig.HonorGuildDeathFormat)
	else
		self:SetText(GetHonorFormatDefault())
	end
	self:ClearFocus()
end)

local lblHonorFormatLegend = honorGuildDeathBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblHonorFormatLegend:SetPoint("TOPLEFT", editHonorFormatBg, "BOTTOMLEFT", 0, -4)
lblHonorFormatLegend:SetWidth(380)
lblHonorFormatLegend:SetJustifyH("LEFT")
lblHonorFormatLegend:SetText(L["Honor format legend"])

function RefreshHonorGuildDeathUI()
	if not lblHonorChannelStatus then
		return
	end
	local debugEnabled = MGTConfig and MGTConfig.HonorGuildDeathDebug == "ENABLED"
	if not IsInGuild or not IsInGuild() then
		if debugEnabled then
			lblHonorChannelStatus:SetText(L["Honor death debug channel (guild not required for parse logs)"])
		else
			lblHonorChannelStatus:SetText(L["Honor death requires guild"])
		end
		if debugEnabled and AddonTable.EnsureHardcoreDeathsChannel then
			AddonTable.EnsureHardcoreDeathsChannel()
		end
		return
	end
	if debugEnabled then
		if AddonTable.EnsureHardcoreDeathsChannel then
			AddonTable.EnsureHardcoreDeathsChannel()
		end
		if AddonTable.IsHardcoreDeathsChannelJoined and AddonTable.IsHardcoreDeathsChannelJoined() then
			lblHonorChannelStatus:SetText(L["HardcoreDeathsDebug channel joined (print mode)"])
		else
			lblHonorChannelStatus:SetText(L["Join HardcoreDeathsDebug channel"])
		end
		return
	end
	if MGTConfig and MGTConfig.HonorGuildDeathAuto == "ENABLED" then
		if AddonTable.IsHardcoreDeathsChannelJoined and AddonTable.IsHardcoreDeathsChannelJoined() then
			lblHonorChannelStatus:SetText(L["HardcoreDeaths channel joined"])
		else
			if AddonTable.EnsureHardcoreDeathsChannel then
				AddonTable.EnsureHardcoreDeathsChannel()
			end
			if AddonTable.IsHardcoreDeathsChannelJoined and AddonTable.IsHardcoreDeathsChannelJoined() then
				lblHonorChannelStatus:SetText(L["HardcoreDeaths channel joined"])
			else
				lblHonorChannelStatus:SetText(L["Join HardcoreDeaths channel"])
			end
		end
	else
		lblHonorChannelStatus:SetText(L["Honor death auto disabled"])
	end
end

local honorGuildDeathWatcher = CreateFrame("Frame")
honorGuildDeathWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
honorGuildDeathWatcher:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
honorGuildDeathWatcher:SetScript("OnEvent", RefreshHonorGuildDeathUI)

-- Blacklist section

local BLACKLIST_BOX_BOTTOM_PAD = 16
local BLACKLIST_DETAIL_CHECKBOX_COUNT = 10
local BLACKLIST_SYNC_EXTRA_ROWS = 3
local BLACKLIST_CHECKBOX_ROW = 26
local BLACKLIST_BTN_HEIGHT = 22
local BLACKLIST_BTN_TOP_GAP = 12
local BLACKLIST_SYNC_TOP_GAP = 10
local BLACKLIST_MIN_BOX_HEIGHT = 580

local blacklistBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
blacklistBox:SetPoint("TOPLEFT", honorGuildDeathBox, "BOTTOMLEFT", 0, -16)
blacklistBox:SetSize(420, BLACKLIST_MIN_BOX_HEIGHT)
blacklistBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
blacklistBox:SetBackdropColor(0, 0, 0, 0.5)

local lblBlacklistSection = blacklistBox:CreateFontString(nil, nil, "GameFontNormalLarge")
lblBlacklistSection:SetPoint("TOPLEFT", blacklistBox, "TOPLEFT", 12, -8)
lblBlacklistSection:SetText(L["Blacklist"])

local lblBlacklistHint = blacklistBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblBlacklistHint:SetPoint("TOPLEFT", lblBlacklistSection, "BOTTOMLEFT", 0, -4)
lblBlacklistHint:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
lblBlacklistHint:SetJustifyH("LEFT")
lblBlacklistHint:SetSpacing(3)
lblBlacklistHint:SetWordWrap(true)
lblBlacklistHint:SetText(L["Blacklist hint"])

local blacklistDetailControls = {}

local function BindBlacklistCheckbox(checkbox, configKey, onChange)
	checkbox:SetScript("OnUpdate", function(frame)
		if not MGTConfig then
			return
		end
		frame:SetChecked(MGTConfig[configKey] == "ENABLED")
	end)
	checkbox:SetScript("OnClick", function(frame)
		if not MGTConfig then
			return
		end
		MGTConfig[configKey] = frame:GetChecked() and "ENABLED" or "DISABLED"
		if onChange then
			onChange()
		end
	end)
end

local function ScrollBlacklistIntoView()
	if not optionsScroll or not blacklistBox then
		return
	end
	local scrollRange = optionsScroll:GetVerticalScrollRange()
	if scrollRange and scrollRange > 0 then
		optionsScroll:SetVerticalScroll(scrollRange)
	end
end

local chkBlacklistEnabled = CreateFrame("CheckButton", nil, blacklistBox, "OptionsBaseCheckButtonTemplate")
chkBlacklistEnabled:SetPoint("TOPLEFT", lblBlacklistHint, "BOTTOMLEFT", 0, -8)
BindBlacklistCheckbox(chkBlacklistEnabled, "BlacklistEnabled", function()
	if AddonTable.SetBlacklistActive then
		AddonTable.SetBlacklistActive(MGTConfig.BlacklistEnabled == "ENABLED")
	end
	if AddonTable.RefreshBlacklistOptionsUI then
		AddonTable.RefreshBlacklistOptionsUI()
	end
	if MGTConfig.BlacklistEnabled == "ENABLED" then
		ScrollBlacklistIntoView()
	end
end)

local lblBlacklistEnabled = blacklistBox:CreateFontString(nil, nil, "GameFontHighlight")
lblBlacklistEnabled:SetPoint("LEFT", chkBlacklistEnabled, "RIGHT", 0, 1)
lblBlacklistEnabled:SetText(L["Enable blacklist"])

local function CreateBlacklistDetailCheckbox(anchor, configKey, labelText, onChange)
	local checkbox = CreateFrame("CheckButton", nil, blacklistBox, "OptionsBaseCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
	BindBlacklistCheckbox(checkbox, configKey, onChange)
	local label = blacklistBox:CreateFontString(nil, nil, "GameFontHighlight")
	label:SetPoint("LEFT", checkbox, "RIGHT", 0, 1)
	label:SetText(labelText)
	blacklistDetailControls[#blacklistDetailControls + 1] = checkbox
	blacklistDetailControls[#blacklistDetailControls + 1] = label
	return checkbox
end

local chkBlacklistAlertWhisper = CreateBlacklistDetailCheckbox(chkBlacklistEnabled, "BlacklistAlertWhisper", L["Blacklist alert whisper"])
local chkBlacklistAlertGroup = CreateBlacklistDetailCheckbox(chkBlacklistAlertWhisper, "BlacklistAlertGroup", L["Blacklist alert group"])
local chkBlacklistAlertTrade = CreateBlacklistDetailCheckbox(chkBlacklistAlertGroup, "BlacklistAlertTrade", L["Blacklist alert trade"])
local chkBlacklistAlertProximity = CreateBlacklistDetailCheckbox(chkBlacklistAlertTrade, "BlacklistAlertProximity", L["Blacklist alert proximity"])
local chkBlacklistPlaySound = CreateBlacklistDetailCheckbox(chkBlacklistAlertProximity, "BlacklistPlaySound", L["Blacklist play sound"])
local chkBlacklistChatAlert = CreateBlacklistDetailCheckbox(chkBlacklistPlaySound, "BlacklistChatAlert", L["Blacklist chat alert"])
local chkBlacklistRaidScreenAlert = CreateBlacklistDetailCheckbox(chkBlacklistChatAlert, "BlacklistRaidScreenAlert", L["Blacklist raid screen alert"])
local chkBlacklistAutoBlock = CreateBlacklistDetailCheckbox(chkBlacklistRaidScreenAlert, "BlacklistAutoBlock", L["Blacklist auto block"])
local chkBlacklistAlertNameplate = CreateBlacklistDetailCheckbox(chkBlacklistAutoBlock, "BlacklistAlertNameplate", L["Blacklist alert nameplate"], function()
	if AddonTable.RefreshBlacklistWatcher then
		AddonTable.RefreshBlacklistWatcher()
	end
end)

local lblBlacklistNameplateHint = blacklistBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblBlacklistNameplateHint:SetPoint("TOPLEFT", chkBlacklistAlertNameplate, "BOTTOMLEFT", 16, -4)
lblBlacklistNameplateHint:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
lblBlacklistNameplateHint:SetJustifyH("LEFT")
lblBlacklistNameplateHint:SetSpacing(3)
lblBlacklistNameplateHint:SetWordWrap(true)
lblBlacklistNameplateHint:SetText(L["Blacklist nameplate hint"])
blacklistDetailControls[#blacklistDetailControls + 1] = lblBlacklistNameplateHint

local chkBlacklistFuzzy = CreateFrame("CheckButton", nil, blacklistBox, "OptionsBaseCheckButtonTemplate")
chkBlacklistFuzzy:SetPoint("TOPLEFT", lblBlacklistNameplateHint, "BOTTOMLEFT", -16, -6)
BindBlacklistCheckbox(chkBlacklistFuzzy, "BlacklistFuzzyMatch")
local lblBlacklistFuzzy = blacklistBox:CreateFontString(nil, nil, "GameFontHighlight")
lblBlacklistFuzzy:SetPoint("LEFT", chkBlacklistFuzzy, "RIGHT", 0, 1)
lblBlacklistFuzzy:SetText(L["Blacklist fuzzy match"])
blacklistDetailControls[#blacklistDetailControls + 1] = chkBlacklistFuzzy
blacklistDetailControls[#blacklistDetailControls + 1] = lblBlacklistFuzzy

local lblBlacklistFuzzyHint = blacklistBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblBlacklistFuzzyHint:SetPoint("TOPLEFT", chkBlacklistFuzzy, "BOTTOMLEFT", 16, -4)
lblBlacklistFuzzyHint:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
lblBlacklistFuzzyHint:SetJustifyH("LEFT")
lblBlacklistFuzzyHint:SetSpacing(3)
lblBlacklistFuzzyHint:SetWordWrap(true)
lblBlacklistFuzzyHint:SetText(L["Blacklist fuzzy hint"])
blacklistDetailControls[#blacklistDetailControls + 1] = lblBlacklistFuzzyHint

local btnBlacklistOpenIgnore = CreateFrame("Button", nil, blacklistBox, "UIPanelButtonTemplate")
btnBlacklistOpenIgnore:SetSize(200, 22)
btnBlacklistOpenIgnore:SetPoint("TOPLEFT", lblBlacklistFuzzyHint, "BOTTOMLEFT", -16, -10)
btnBlacklistOpenIgnore:SetText(L["Blacklist open ignore list"])
btnBlacklistOpenIgnore:SetScript("OnClick", function()
	if AddonTable.OpenIgnoreList then
		AddonTable.OpenIgnoreList()
	end
end)

local chkIgnoreListSync = CreateFrame("CheckButton", nil, blacklistBox, "OptionsBaseCheckButtonTemplate")
chkIgnoreListSync:SetPoint("TOPLEFT", btnBlacklistOpenIgnore, "BOTTOMLEFT", 0, -BLACKLIST_SYNC_TOP_GAP)
chkIgnoreListSync:SetScript("OnClick", function(frame)
	if not MGTConfig or not AddonTable.SetIgnoreListSyncEnabled then
		return
	end
	AddonTable.SetIgnoreListSyncEnabled(frame:GetChecked())
end)

local lblIgnoreListSync = blacklistBox:CreateFontString(nil, nil, "GameFontHighlight")
lblIgnoreListSync:SetPoint("LEFT", chkIgnoreListSync, "RIGHT", 0, 1)
lblIgnoreListSync:SetText(L["Ignore list sync main"])

local lblIgnoreListSyncAlt = blacklistBox:CreateFontString(nil, nil, "GameFontDisable")
lblIgnoreListSyncAlt:SetPoint("TOPLEFT", btnBlacklistOpenIgnore, "BOTTOMLEFT", 0, -BLACKLIST_SYNC_TOP_GAP)
lblIgnoreListSyncAlt:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
lblIgnoreListSyncAlt:SetJustifyH("LEFT")
lblIgnoreListSyncAlt:Hide()

local chkIgnoreListSyncLoginApply = CreateFrame("CheckButton", nil, blacklistBox, "OptionsBaseCheckButtonTemplate")
chkIgnoreListSyncLoginApply:SetPoint("TOPLEFT", chkIgnoreListSync, "BOTTOMLEFT", 0, -4)
BindBlacklistCheckbox(chkIgnoreListSyncLoginApply, "IgnoreListSyncLoginApply", function()
	if AddonTable.RefreshIgnoreListSyncUI then
		AddonTable.RefreshIgnoreListSyncUI()
	end
end)

local lblIgnoreListSyncLoginApply = blacklistBox:CreateFontString(nil, nil, "GameFontHighlight")
lblIgnoreListSyncLoginApply:SetPoint("LEFT", chkIgnoreListSyncLoginApply, "RIGHT", 0, 1)
lblIgnoreListSyncLoginApply:SetText(L["Ignore list sync login apply"])

local lblIgnoreListSyncStatus = blacklistBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblIgnoreListSyncStatus:SetPoint("TOPLEFT", chkIgnoreListSyncLoginApply, "BOTTOMLEFT", 16, -4)
lblIgnoreListSyncStatus:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
lblIgnoreListSyncStatus:SetJustifyH("LEFT")
lblIgnoreListSyncStatus:SetSpacing(2)
lblIgnoreListSyncStatus:SetWordWrap(true)

local lblIgnoreListSyncAltHint = blacklistBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblIgnoreListSyncAltHint:SetPoint("TOPLEFT", lblIgnoreListSyncStatus, "BOTTOMLEFT", 0, -4)
lblIgnoreListSyncAltHint:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
lblIgnoreListSyncAltHint:SetJustifyH("LEFT")
lblIgnoreListSyncAltHint:SetSpacing(2)
lblIgnoreListSyncAltHint:SetWordWrap(true)
lblIgnoreListSyncAltHint:SetText(L["Ignore list sync alt reset hint"])
lblIgnoreListSyncAltHint:Hide()

function AddonTable.RefreshIgnoreListSyncUI()
	if AddonTable.EnsureMGTBlacklistConfig then
		AddonTable.EnsureMGTBlacklistConfig()
	end
	if not MGTConfig then
		return
	end

	local isAlt = AddonTable.IsCurrentCharacterIgnoreListSyncAlt and AddonTable.IsCurrentCharacterIgnoreListSyncAlt()
	local syncEnabled = MGTConfig.IgnoreListSyncEnabled == "ENABLED"

	if isAlt then
		chkIgnoreListSync:Hide()
		lblIgnoreListSync:Hide()
		lblIgnoreListSyncAlt:Show()
		local mainName = AddonTable.GetIgnoreListSyncMainDisplayName and AddonTable.GetIgnoreListSyncMainDisplayName() or "?"
		lblIgnoreListSyncAlt:SetText(string.format(L["Ignore list sync alt readonly"], mainName))
		chkIgnoreListSyncLoginApply:Hide()
		lblIgnoreListSyncLoginApply:Hide()
		lblIgnoreListSyncAltHint:SetShown(syncEnabled)
	else
		lblIgnoreListSyncAltHint:Hide()
		chkIgnoreListSync:Show()
		lblIgnoreListSync:Show()
		lblIgnoreListSyncAlt:Hide()
		chkIgnoreListSync:SetChecked(syncEnabled)
		local showLoginApply = syncEnabled
		chkIgnoreListSyncLoginApply:SetShown(showLoginApply)
		lblIgnoreListSyncLoginApply:SetShown(showLoginApply)
		if showLoginApply then
			chkIgnoreListSyncLoginApply:SetChecked(MGTConfig.IgnoreListSyncLoginApply == "ENABLED")
		end
	end

	if AddonTable.GetIgnoreListSyncStatusText then
		lblIgnoreListSyncStatus:SetText(AddonTable.GetIgnoreListSyncStatusText())
	end
	lblIgnoreListSyncStatus:SetShown(syncEnabled)
	if syncEnabled then
		lblIgnoreListSyncStatus:ClearAllPoints()
		if isAlt then
			lblIgnoreListSyncStatus:SetPoint("TOPLEFT", lblIgnoreListSyncAlt, "BOTTOMLEFT", 0, -4)
			if syncEnabled then
				lblIgnoreListSyncAltHint:ClearAllPoints()
				lblIgnoreListSyncAltHint:SetPoint("TOPLEFT", lblIgnoreListSyncStatus, "BOTTOMLEFT", 0, -4)
				lblIgnoreListSyncAltHint:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
			end
		else
			lblIgnoreListSyncStatus:SetPoint("TOPLEFT", chkIgnoreListSyncLoginApply, "BOTTOMLEFT", 16, -4)
		end
		lblIgnoreListSyncStatus:SetPoint("RIGHT", blacklistBox, "RIGHT", -12, 0)
	end

	if UpdateBlacklistBoxHeight then
		UpdateBlacklistBoxHeight()
	end
end

local UpdateBlacklistBoxHeight

local function RefreshBlacklistDetailVisibility()
	local active = MGTConfig and MGTConfig.BlacklistEnabled == "ENABLED"
	for _, control in ipairs(blacklistDetailControls) do
		control:Show()
		if control.SetAlpha then
			control:SetAlpha(active and 1 or 0.85)
		end
	end
	btnBlacklistOpenIgnore:Show()
	if btnBlacklistOpenIgnore.SetAlpha then
		btnBlacklistOpenIgnore:SetAlpha(1)
	end
	btnBlacklistOpenIgnore:Enable()
end

function AddonTable.RefreshBlacklistOptionsUI()
	if AddonTable.EnsureMGTBlacklistConfig then
		AddonTable.EnsureMGTBlacklistConfig()
	end
	if MGTConfig then
		chkBlacklistEnabled:SetChecked(MGTConfig.BlacklistEnabled == "ENABLED")
	end
	RefreshBlacklistDetailVisibility()
	if AddonTable.RefreshIgnoreListSyncUI then
		AddonTable.RefreshIgnoreListSyncUI()
	end
	if UpdateBlacklistBoxHeight then
		UpdateBlacklistBoxHeight()
	end
	if UpdateOptionsScrollHeight then
		UpdateOptionsScrollHeight()
	end
end

UpdateBlacklistBoxHeight = function()
	local function ApplyHeight()
		if not blacklistBox or not btnBlacklistOpenIgnore then
			return
		end
		local hintH = math.max(lblBlacklistHint:GetStringHeight() or 0, lblBlacklistHint:GetHeight() or 14, 14)
		local nameplateHintH = math.max(lblBlacklistNameplateHint:GetStringHeight() or 0, lblBlacklistNameplateHint:GetHeight() or 14, 14)
		local fuzzyHintH = math.max(lblBlacklistFuzzyHint:GetStringHeight() or 0, lblBlacklistFuzzyHint:GetHeight() or 14, 14)
		local syncStatusH = 0
		if lblIgnoreListSyncStatus and lblIgnoreListSyncStatus:IsShown() then
			syncStatusH = math.max(lblIgnoreListSyncStatus:GetStringHeight() or 0, lblIgnoreListSyncStatus:GetHeight() or 14, 14)
		end
		local syncAltHintH = 0
		if lblIgnoreListSyncAltHint and lblIgnoreListSyncAltHint:IsShown() then
			syncAltHintH = math.max(lblIgnoreListSyncAltHint:GetStringHeight() or 0, lblIgnoreListSyncAltHint:GetHeight() or 14, 14) + 4
		end
		local syncBlockH = BLACKLIST_SYNC_TOP_GAP
			+ (BLACKLIST_SYNC_EXTRA_ROWS * BLACKLIST_CHECKBOX_ROW)
			+ 4 + syncStatusH + syncAltHintH

		local computed = 8 + 16 + 4 + hintH + 8 + BLACKLIST_CHECKBOX_ROW
			+ (BLACKLIST_DETAIL_CHECKBOX_COUNT * BLACKLIST_CHECKBOX_ROW)
			+ 4 + nameplateHintH + 10 + fuzzyHintH + BLACKLIST_BTN_TOP_GAP + BLACKLIST_BTN_HEIGHT
			+ syncBlockH + BLACKLIST_BOX_BOTTOM_PAD

		local measured = 0
		if blacklistBox:IsVisible() then
			local boxTop = blacklistBox:GetTop()
			local bottomRef = lblIgnoreListSyncAltHint
			if not bottomRef:IsShown() then
				bottomRef = lblIgnoreListSyncStatus
			end
			if not bottomRef:IsShown() then
				bottomRef = lblIgnoreListSyncAlt:IsShown() and lblIgnoreListSyncAlt or btnBlacklistOpenIgnore
			end
			local refBottom = bottomRef:GetBottom()
			if boxTop and refBottom then
				local scale = blacklistBox:GetEffectiveScale() or 1
				measured = (boxTop - refBottom) / scale + BLACKLIST_BOX_BOTTOM_PAD
			end
		end

		blacklistBox:SetHeight(math.max(computed, measured, BLACKLIST_MIN_BOX_HEIGHT))
		if UpdateOptionsScrollHeight then
			UpdateOptionsScrollHeight()
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, ApplyHeight)
		C_Timer.After(0.05, ApplyHeight)
	else
		ApplyHeight()
	end
end

blacklistBox:SetScript("OnShow", function()
	UpdateBlacklistBoxHeight()
end)

local function UpdateOptionsScrollHeight()
	local height = tooltipBox:GetHeight() + invitationsBox:GetHeight() + honorGuildDeathBox:GetHeight() + blacklistBox:GetHeight() + 64
	optionsScrollChild:SetHeight(height)
end

optionsScrollChild:SetScript("OnShow", function()
	UpdateOptionsScrollHeight()
	RefreshHonorGuildDeathUI()
	RefreshFontSizeDropdown()
	RefreshGuildInviteOptionsUI()
	if AddonTable.RefreshInvitationsOptionsUI then
		AddonTable.RefreshInvitationsOptionsUI()
	end
	if AddonTable.RefreshBlacklistOptionsUI then
		AddonTable.RefreshBlacklistOptionsUI()
	end
end)
GTIOFrame:SetScript("OnShow", function()
	UpdateOptionsScrollHeight()
	RefreshHonorGuildDeathUI()
	RefreshFontSizeDropdown()
	RefreshGuildInviteOptionsUI()
	if AddonTable.RefreshInvitationsOptionsUI then
		AddonTable.RefreshInvitationsOptionsUI()
	end
	if AddonTable.RefreshBlacklistOptionsUI then
		AddonTable.RefreshBlacklistOptionsUI()
	end
end)
UpdateOptionsScrollHeight()
RefreshHonorGuildDeathUI()
RefreshGuildInviteOptionsUI()
if AddonTable.RefreshBlacklistOptionsUI then
	AddonTable.RefreshBlacklistOptionsUI()
end

local category, layout = Settings.RegisterCanvasLayoutCategory(GTIOFrame, "MyGuildTools")
Settings.RegisterAddOnCategory(category)
GTIOFrame.Category = category

-- Config Sash Command Handler

function mgtconfiguration(msg, editbox)

if msg == "" or msg == nil then
	local category = GTIOFrame.Category
	if category then
		Settings.OpenToCategory(category:GetID())
	else
		print("Category not found")
	end
elseif msg == "help" then
	DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r The following arguments are valid:\ncolour/color - Toggle colouring of player name and class\nhp/health/bar - Toggle the HP bar under the tooltip\ngnotes/guildnotes - Toggle guild notes on tooltips\ntest \"...\" - Test Honor Guild Death parsing\n\nFormats are configured in the addon options (Settings).")
elseif msg == "colour" or msg == "color" then
	if MGTConfig.Colour == "ENABLED" then
		MGTConfig.Colour = 'DISABLED'
	elseif MGTConfig.Colour == "DISABLED" then
		MGTConfig.Colour = 'ENABLED'
	end
elseif msg == "hp" or msg == "health" or msg == "bar" then
	if MGTConfig.HealthBar == "ENABLED" then
		MGTConfig.HealthBar = 'DISABLED'
	elseif MGTConfig.HealthBar == "DISABLED" then
		MGTConfig.HealthBar = 'ENABLED'
	end
elseif msg == "gnotes" or msg == "guildnotes" then
	if MGTConfig.GuildNotes == "ENABLED" then
		MGTConfig.GuildNotes = "DISABLED"
	elseif MGTConfig.GuildNotes == "DISABLED" then
		MGTConfig.GuildNotes = "ENABLED"
	end
elseif msg:lower() == "blacklist reset" then
	if AddonTable.ResetIgnoreListSync then
		AddonTable.ResetIgnoreListSync()
	end
elseif msg:match("^test ") then
	local testMsg = msg:match('^test "(.*)"$') or msg:match("^test (.+)$")
	if not testMsg or testMsg == "" then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r " .. L["Honor death test usage"])
	else
		if AddonTable.TestHonorDeathMessage then
			AddonTable.TestHonorDeathMessage(testMsg)
		end
	end
end

end