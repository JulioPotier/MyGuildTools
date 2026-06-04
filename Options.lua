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

-- Guild Invite options section

local guildInviteBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
guildInviteBox:SetPoint("TOPLEFT", tooltipBox, "BOTTOMLEFT", 0, -16)
guildInviteBox:SetSize(420, 112)
guildInviteBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
guildInviteBox:SetBackdropColor(0, 0, 0, 0.5)

local lblGuildInviteSection = guildInviteBox:CreateFontString(nil, nil, "GameFontNormalLarge")
lblGuildInviteSection:SetPoint("TOPLEFT", guildInviteBox, "TOPLEFT", 12, -8)
lblGuildInviteSection:SetText(L["Guild Invite"])

local guildInviteOpts = {}

guildInviteOpts.checkbox = CreateFrame("CheckButton", nil, guildInviteBox, "OptionsBaseCheckButtonTemplate")
guildInviteOpts.checkbox:SetPoint("TOPLEFT", lblGuildInviteSection, "BOTTOMLEFT", 0, -8)

guildInviteOpts.label = guildInviteBox:CreateFontString(nil, nil, "GameFontHighlight")
guildInviteOpts.label:SetPoint("LEFT", guildInviteOpts.checkbox, "RIGHT", 0, 1)
guildInviteOpts.label:SetText(L["Add a right-click menu to /ginvite"])

guildInviteOpts.hint = guildInviteBox:CreateFontString(nil, nil, "GameFontDisableSmall")
guildInviteOpts.hint:SetPoint("TOPLEFT", guildInviteOpts.checkbox, "BOTTOMLEFT", 0, -8)
guildInviteOpts.hint:SetPoint("LEFT", guildInviteBox, "LEFT", 28, 0)
guildInviteOpts.hint:SetPoint("RIGHT", guildInviteBox, "RIGHT", -12, 0)
guildInviteOpts.hint:SetJustifyH("LEFT")
guildInviteOpts.hint:SetJustifyV("TOP")
guildInviteOpts.hint:SetSpacing(4)
guildInviteOpts.hint:SetText(L["Guild invite key hint"])

local function RefreshGuildInviteOptionsUI()
	local checkbox = guildInviteOpts.checkbox
	local label = guildInviteOpts.label
	local hint = guildInviteOpts.hint
	if not checkbox or not label or not hint then
		return
	end

	local canUse = AddonTable.PlayerCanGuildInvite and AddonTable.PlayerCanGuildInvite()
	if canUse then
		checkbox:Enable()
		label:SetTextColor(1, 0.82, 0)
		hint:SetTextColor(0.5, 0.5, 0.5)
	else
		checkbox:Disable()
		checkbox:SetChecked(false)
		if MGTConfig then
			MGTConfig.GuildInviteMenu = "DISABLED"
		end
		label:SetTextColor(0.5, 0.5, 0.5)
		hint:SetTextColor(0.35, 0.35, 0.35)
	end
end

guildInviteOpts.checkbox:SetScript("OnUpdate", function(frame)
	if not MGTConfig then
		return
	end
	if not AddonTable.PlayerCanGuildInvite or not AddonTable.PlayerCanGuildInvite() then
		return
	end
	if MGTConfig.GuildInviteMenu == "ENABLED" then
		frame:SetChecked(true)
	elseif MGTConfig.GuildInviteMenu == "DISABLED" then
		frame:SetChecked(false)
	end
end)

guildInviteOpts.checkbox:SetScript("OnClick", function(frame)
	if not MGTConfig then
		return
	end
	if not AddonTable.PlayerCanGuildInvite or not AddonTable.PlayerCanGuildInvite() then
		frame:SetChecked(false)
		MGTConfig.GuildInviteMenu = "DISABLED"
		if not IsInGuild or not IsInGuild() then
			DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r " .. L["You are not in a guild."])
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r " .. L["You don't have permission to invite guild members."])
		end
		return
	end
	local tick = frame:GetChecked()
	if tick == false then
		MGTConfig.GuildInviteMenu = "DISABLED"
	elseif tick == true then
		MGTConfig.GuildInviteMenu = "ENABLED"
	end
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
honorGuildDeathBox:SetPoint("TOPLEFT", guildInviteBox, "BOTTOMLEFT", 0, -16)
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

-- Tabard Stalker

local tabardStalkerBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
tabardStalkerBox:SetPoint("TOPLEFT", honorGuildDeathBox, "BOTTOMLEFT", 0, -16)
tabardStalkerBox:SetSize(420, 196)
if tabardStalkerBox.SetClipsChildren then
	tabardStalkerBox:SetClipsChildren(true)
end
tabardStalkerBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
tabardStalkerBox:SetBackdropColor(0, 0, 0, 0.5)

local lblTabardStalkerSection = tabardStalkerBox:CreateFontString(nil, nil, "GameFontNormalLarge")
lblTabardStalkerSection:SetPoint("TOPLEFT", tabardStalkerBox, "TOPLEFT", 12, -8)
lblTabardStalkerSection:SetText(L["Tabard Stalker"])

local lblTabardStalkerHint = tabardStalkerBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblTabardStalkerHint:SetPoint("TOPLEFT", lblTabardStalkerSection, "BOTTOMLEFT", 0, -4)
lblTabardStalkerHint:SetPoint("RIGHT", tabardStalkerBox, "RIGHT", -12, 0)
lblTabardStalkerHint:SetJustifyH("LEFT")
lblTabardStalkerHint:SetText(L["Tabard scan (party/raid)"])

local chkTabardGuildOnly = CreateFrame("CheckButton", nil, tabardStalkerBox, "OptionsBaseCheckButtonTemplate")
chkTabardGuildOnly:SetPoint("TOPLEFT", lblTabardStalkerHint, "BOTTOMLEFT", 0, -8)

chkTabardGuildOnly:SetScript("OnUpdate", function(frame)
	if not MGTConfig then
		return
	end
	if MGTConfig.TabardStalkerGuildOnly == "ENABLED" then
		frame:SetChecked(true)
	elseif MGTConfig.TabardStalkerGuildOnly == "DISABLED" then
		frame:SetChecked(false)
	end
end)

chkTabardGuildOnly:SetScript("OnClick", function(frame)
	if not MGTConfig then
		return
	end
	if frame:GetChecked() then
		MGTConfig.TabardStalkerGuildOnly = "ENABLED"
	else
		MGTConfig.TabardStalkerGuildOnly = "DISABLED"
	end
end)

local chkTabardGuildOnlyText = tabardStalkerBox:CreateFontString(nil, nil, "GameFontHighlight")
chkTabardGuildOnlyText:SetPoint("LEFT", chkTabardGuildOnly, "RIGHT", 0, 1)
chkTabardGuildOnlyText:SetText(L["Only for guildies"])

local lblTabardMinLevel = tabardStalkerBox:CreateFontString(nil, nil, "GameFontHighlight")
lblTabardMinLevel:SetPoint("TOPLEFT", chkTabardGuildOnly, "BOTTOMLEFT", 0, -8)
lblTabardMinLevel:SetText(L["Minimum level:"])

local editTabardMinLevel = CreateFrame("EditBox", nil, tabardStalkerBox, "InputBoxTemplate")
editTabardMinLevel:SetSize(48, 20)
editTabardMinLevel:SetPoint("LEFT", lblTabardMinLevel, "RIGHT", 8, 0)
editTabardMinLevel:SetAutoFocus(false)
editTabardMinLevel:SetNumeric(true)
editTabardMinLevel:SetMaxLetters(2)

editTabardMinLevel:SetScript("OnShow", function(self)
	if MGTConfig and MGTConfig.TabardStalkerMinLevel then
		self:SetText(MGTConfig.TabardStalkerMinLevel)
	else
		self:SetText("40")
	end
end)

editTabardMinLevel:SetScript("OnEditFocusLost", function(self)
	if not MGTConfig then
		return
	end
	local level = tonumber(self:GetText())
	if not level or level < 1 then
		level = 1
	elseif level > 60 then
		level = 60
	end
	MGTConfig.TabardStalkerMinLevel = tostring(level)
	self:SetText(MGTConfig.TabardStalkerMinLevel)
end)

editTabardMinLevel:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end)

editTabardMinLevel:SetScript("OnEscapePressed", function(self)
	if MGTConfig and MGTConfig.TabardStalkerMinLevel then
		self:SetText(MGTConfig.TabardStalkerMinLevel)
	else
		self:SetText("40")
	end
	self:ClearFocus()
end)

local chkTabardAutoScan = CreateFrame("CheckButton", nil, tabardStalkerBox, "OptionsBaseCheckButtonTemplate")
chkTabardAutoScan:SetPoint("TOPLEFT", lblTabardMinLevel, "BOTTOMLEFT", 0, -8)

chkTabardAutoScan:SetScript("OnUpdate", function(frame)
	if not MGTConfig then
		return
	end
	if MGTConfig.TabardStalkerAutoScan == "ENABLED" then
		frame:SetChecked(true)
	elseif MGTConfig.TabardStalkerAutoScan == "DISABLED" then
		frame:SetChecked(false)
	end
end)

chkTabardAutoScan:SetScript("OnClick", function(frame)
	if not MGTConfig then
		return
	end
	if frame:GetChecked() then
		MGTConfig.TabardStalkerAutoScan = "ENABLED"
	else
		MGTConfig.TabardStalkerAutoScan = "DISABLED"
	end
end)

local chkTabardAutoScanText = tabardStalkerBox:CreateFontString(nil, nil, "GameFontHighlight")
chkTabardAutoScanText:SetPoint("LEFT", chkTabardAutoScan, "RIGHT", 0, 1)
chkTabardAutoScanText:SetText(L["Auto scan when grouping"])

local btnScanTabards = CreateFrame("Button", nil, tabardStalkerBox, "UIPanelButtonTemplate")
btnScanTabards:SetSize(160, 22)
btnScanTabards:SetPoint("TOPLEFT", chkTabardAutoScan, "BOTTOMLEFT", 0, -8)
btnScanTabards:SetText(L["Scan group tabards"])

local btnResetTabardCache = CreateFrame("Button", nil, tabardStalkerBox, "UIPanelButtonTemplate")
btnResetTabardCache:SetSize(140, 22)
btnResetTabardCache:SetPoint("LEFT", btnScanTabards, "RIGHT", 8, 0)
btnResetTabardCache:SetText(L["Reset tabard data"])

local btnAnnounceTabards = CreateFrame("Button", nil, tabardStalkerBox, "UIPanelButtonTemplate")
btnAnnounceTabards:SetSize(308, 22)
btnAnnounceTabards:SetPoint("TOPLEFT", btnScanTabards, "BOTTOMLEFT", 0, -4)
btnAnnounceTabards:SetText(L["Announce missing tabards in /say"])
btnAnnounceTabards:Disable()

local lblTabardScanStatus = tabardStalkerBox:CreateFontString(nil, nil, "GameFontDisableSmall")
lblTabardScanStatus:SetPoint("TOPLEFT", btnAnnounceTabards, "BOTTOMLEFT", 0, -4)
lblTabardScanStatus:SetPoint("RIGHT", tabardStalkerBox, "RIGHT", -12, 0)
lblTabardScanStatus:SetJustifyH("LEFT")
lblTabardScanStatus:SetHeight(28)
lblTabardScanStatus:SetText("")

local tabardScanSpinner = tabardStalkerBox:CreateTexture(nil, "ARTWORK")
tabardScanSpinner:SetSize(16, 16)
tabardScanSpinner:SetPoint("RIGHT", lblTabardScanStatus, "LEFT", -4, 0)
tabardScanSpinner:SetTexture("Interface\\ChatFrame\\UI-ChatLoadingIcon")
tabardScanSpinner:SetTexCoord(0, 0.25, 0, 1)
tabardScanSpinner:Hide()

local tabardSpinnerAnim = tabardScanSpinner:CreateAnimationGroup()
tabardSpinnerAnim:SetLooping("REPEAT")
local tabardSpinnerRotate = tabardSpinnerAnim:CreateAnimation("Rotation")
tabardSpinnerRotate:SetDegrees(360)
tabardSpinnerRotate:SetDuration(1)

local function UpdateTabardStalkerBoxHeight()
	local statusH = math.max(lblTabardScanStatus:GetStringHeight() or 0, lblTabardScanStatus:GetHeight() or 28, 28)
	local hintH = math.max(lblTabardStalkerHint:GetStringHeight() or 0, 14)
	tabardStalkerBox:SetHeight(8 + 16 + 4 + hintH + 8 + 22 + 8 + 22 + 8 + 22 + 8 + 22 + 4 + 22 + 4 + statusH + 14)
end

local function UpdateOptionsScrollHeight()
	UpdateTabardStalkerBoxHeight()
	local height = tooltipBox:GetHeight() + guildInviteBox:GetHeight() + honorGuildDeathBox:GetHeight() + tabardStalkerBox:GetHeight() + 48
	optionsScrollChild:SetHeight(height)
end

local function RefreshTabardScanUI()
	local inGroup = AddonTable.IsInGroupOrRaid and AddonTable.IsInGroupOrRaid()
	local running = AddonTable.IsTabardScanRunning and AddonTable.IsTabardScanRunning()

	if running then
		btnScanTabards:Disable()
		btnResetTabardCache:Disable()
		btnAnnounceTabards:Disable()
		tabardScanSpinner:Show()
		tabardSpinnerAnim:Play()
	else
		tabardScanSpinner:Hide()
		tabardSpinnerAnim:Stop()
		btnResetTabardCache:Enable()
		if AddonTable.HasPendingTabardAnnounce and AddonTable.HasPendingTabardAnnounce() then
			btnAnnounceTabards:Enable()
		else
			btnAnnounceTabards:Disable()
		end
		if inGroup then
			btnScanTabards:Enable()
		else
			btnScanTabards:Disable()
		end
		if lblTabardScanStatus:GetText() == "" then
			if inGroup then
				lblTabardScanStatus:SetText(L["Ready to scan your party or raid."])
			else
				lblTabardScanStatus:SetText(L["Join a party or raid to scan tabards."])
			end
		end
	end
	UpdateOptionsScrollHeight()
end

AddonTable.OnTabardScanStatus = function(text)
	if text and text ~= "" then
		lblTabardScanStatus:SetText(text)
	else
		lblTabardScanStatus:SetText("")
	end
	RefreshTabardScanUI()
end

AddonTable.OnTabardScanStarted = function()
	RefreshTabardScanUI()
end

AddonTable.OnTabardScanFinished = function(missingCount, cannotInspectCount)
	missingCount = missingCount or 0
	cannotInspectCount = cannotInspectCount or 0
	if missingCount > 0 and cannotInspectCount > 0 then
		lblTabardScanStatus:SetText(string.format(
			L["Scan finished. %d without tabard, %d not inspectable."],
			missingCount,
			cannotInspectCount
		))
	elseif missingCount > 0 then
		lblTabardScanStatus:SetText(string.format(L["Scan finished. %d without tabard."], missingCount))
	elseif cannotInspectCount > 0 then
		lblTabardScanStatus:SetText(string.format(L["Scan finished. %d not inspectable."], cannotInspectCount))
	else
		lblTabardScanStatus:SetText(L["Scan finished."])
	end
	RefreshTabardScanUI()
end

btnAnnounceTabards:SetScript("OnClick", function()
	if AddonTable.AnnounceMissingTabards then
		AddonTable.AnnounceMissingTabards()
	end
end)

btnScanTabards:SetScript("OnClick", function()
	if AddonTable.StartTabardScan then
		AddonTable.StartTabardScan()
	end
end)

btnResetTabardCache:SetScript("OnClick", function()
	if AddonTable.ResetTabardCache then
		AddonTable.ResetTabardCache()
	end
	lblTabardScanStatus:SetText(L["Tabard cache cleared."])
	RefreshTabardScanUI()
end)

local tabardScanWatcher = CreateFrame("Frame")
tabardScanWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
tabardScanWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
tabardScanWatcher:RegisterEvent("RAID_ROSTER_UPDATE")
tabardScanWatcher:SetScript("OnEvent", RefreshTabardScanUI)
RefreshTabardScanUI()

optionsScrollChild:SetScript("OnShow", function()
	UpdateOptionsScrollHeight()
	RefreshHonorGuildDeathUI()
	RefreshFontSizeDropdown()
end)
GTIOFrame:SetScript("OnShow", function()
	UpdateOptionsScrollHeight()
	RefreshHonorGuildDeathUI()
	RefreshFontSizeDropdown()
end)
UpdateOptionsScrollHeight()
RefreshHonorGuildDeathUI()

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