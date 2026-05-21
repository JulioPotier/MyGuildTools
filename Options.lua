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
tooltipBox:SetSize(420, 296)
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

-- Show Titles

local chkIOShowTitles = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOShowTitles:SetPoint("TOPLEFT", chkIOShowHPBar, "BOTTOMLEFT", 0, -8)

chkIOShowTitles:SetScript("OnUpdate", function(frame)
	if MGTConfig.Titles == "ENABLED" then
		chkIOShowTitles:SetChecked(true)
	elseif MGTConfig.Titles == "DISABLED" then
		chkIOShowTitles:SetChecked(false)
	end
end)

chkIOShowTitles:SetScript("OnClick", function(frame)
local tick = frame:GetChecked()

	if tick == false then
		MGTConfig.Titles = 'DISABLED'
	elseif tick == true then
		MGTConfig.Titles = 'ENABLED'
	end
end)

local chkIOShowTitlesText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkIOShowTitlesText:SetPoint("LEFT", chkIOShowTitles, "RIGHT", 0, 1)
chkIOShowTitlesText:SetText(L["Show player titles in tooltips"])

-- Show Realms

local chkIOShowRealms = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOShowRealms:SetPoint("TOPLEFT", chkIOShowTitles, "BOTTOMLEFT", 0, -8)

chkIOShowRealms:SetScript("OnUpdate", function(frame)
	if MGTConfig.Realms == "ENABLED" then
		chkIOShowRealms:SetChecked(true)
	elseif MGTConfig.Realms == "DISABLED" then
		chkIOShowRealms:SetChecked(false)
	end
end)

chkIOShowRealms:SetScript("OnClick", function(frame)
local tick = frame:GetChecked()

	if tick == false then
		MGTConfig.Realms = 'DISABLED'
	elseif tick == true then
		MGTConfig.Realms = 'ENABLED'
	end
end)

local chkShowRealmsText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkShowRealmsText:SetPoint("LEFT", chkIOShowRealms, "RIGHT", 0, 1)
chkShowRealmsText:SetText(L["Show player realms in tooltips"])

-- Show Guild Rank

local chkIOShowGuildRank = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOShowGuildRank:SetPoint("TOPLEFT", chkIOShowRealms, "BOTTOMLEFT", 0, -8)

chkIOShowGuildRank:SetScript("OnUpdate", function(frame)
	if MGTConfig.GuildRank == "ENABLED" then
		chkIOShowGuildRank:SetChecked(true)
	elseif MGTConfig.GuildRank == "DISABLED" then
		chkIOShowGuildRank:SetChecked(false)
	end
end)

chkIOShowGuildRank:SetScript("OnClick", function(frame)
local tick = frame:GetChecked()

	if tick == false then
		MGTConfig.GuildRank = 'DISABLED'
	elseif tick == true then
		MGTConfig.GuildRank = 'ENABLED'
	end
end)

local chkIOShowGuildRankText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkIOShowGuildRankText:SetPoint("LEFT", chkIOShowGuildRank, "RIGHT", 0, 1)
chkIOShowGuildRankText:SetText(L["Show guild rank in tooltips"])

-- Show Rank Second

local chkShowGuildRankSecond = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkShowGuildRankSecond:SetPoint("TOPLEFT", chkIOShowGuildRank, "BOTTOMLEFT", 0, -8)

chkShowGuildRankSecond:SetScript("OnUpdate", function(frame)
	if MGTConfig.SimpleRanks == "YES" then
		chkShowGuildRankSecond:SetChecked(true)
	elseif MGTConfig.SimpleRanks == "NO" then
		chkShowGuildRankSecond:SetChecked(false)
	end
end)

chkShowGuildRankSecond:SetScript("OnClick", function(frame)
local tick = frame:GetChecked()

	if tick == false then
		MGTConfig.SimpleRanks = 'NO'
	elseif tick == true then
		MGTConfig.SimpleRanks = 'YES'
	end
end)

local chkShowGuildRankSecondText = tooltipBox:CreateFontString(nil, nil, "GameFontHighlight")
chkShowGuildRankSecondText:SetPoint("LEFT", chkShowGuildRankSecond, "RIGHT", 0, 1)
chkShowGuildRankSecondText:SetText(L["Show rank after guild name"])

-- Guild notes (our guild roster only)

local chkIOGuildNotes = CreateFrame("CheckButton", nil, tooltipBox, "OptionsBaseCheckButtonTemplate")
chkIOGuildNotes:SetPoint("TOPLEFT", chkShowGuildRankSecond, "BOTTOMLEFT", 0, -8)

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
UIDropDownMenu_SetText(ddFontSize, L["Select One"])

-- Create and bind the initialization function to the dropdown menu
UIDropDownMenu_Initialize(ddFontSize, function(self, level, menuList)
local info = UIDropDownMenu_CreateInfo()
	info.func = self.SetValue
	info.text, info.arg1 = "12", 12
	UIDropDownMenu_AddButton(info)
	info.text, info.arg1 = "14", 14
	UIDropDownMenu_AddButton(info)
	info.text, info.arg1 = "16", 16
	UIDropDownMenu_AddButton(info)
	info.text, info.arg1 = "18", 18
	UIDropDownMenu_AddButton(info)
	info.text, info.arg1 = "20", 20
	UIDropDownMenu_AddButton(info)
end)

-- Implement the function to change the font size
function ddFontSize:SetValue(newValue)
	MGTConfig.FontSize = newValue
	DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[" .. L["MyGuildTools"] .. "]|r " .. L["Font size changed to"] .. " " .. newValue .. ".")
	-- Update the text; if we merely wanted it to display newValue, we would not need to do this
	UIDropDownMenu_SetText(ddFontSize, MGTConfig.FontSize)
	-- Because this is called from a sub-menu, only that menu level is closed by default.
	-- Close the entire menu with this next call
	CloseDropDownMenus()
end

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
		MGTConfig.GuildInviteMenu = "DISABLED"
		label:SetTextColor(0.5, 0.5, 0.5)
		hint:SetTextColor(0.35, 0.35, 0.35)
	end
end

guildInviteOpts.checkbox:SetScript("OnUpdate", function(frame)
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
guildInviteOptionsWatcher:RegisterEvent("PLAYER_GUILD_UPDATE")
guildInviteOptionsWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
guildInviteOptionsWatcher:SetScript("OnEvent", RefreshGuildInviteOptionsUI)
RefreshGuildInviteOptionsUI()

-- Tabard Stalker

local tabardStalkerBox = CreateFrame("Frame", nil, optionsScrollChild, "BackdropTemplate")
tabardStalkerBox:SetPoint("TOPLEFT", guildInviteBox, "BOTTOMLEFT", 0, -16)
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

local btnScanTabards = CreateFrame("Button", nil, tabardStalkerBox, "UIPanelButtonTemplate")
btnScanTabards:SetSize(160, 22)
btnScanTabards:SetPoint("TOPLEFT", lblTabardStalkerHint, "BOTTOMLEFT", 0, -8)
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
	tabardStalkerBox:SetHeight(8 + 16 + 4 + hintH + 8 + 22 + 4 + 22 + 4 + statusH + 14)
end

local function UpdateOptionsScrollHeight()
	UpdateTabardStalkerBoxHeight()
	local height = tooltipBox:GetHeight() + guildInviteBox:GetHeight() + tabardStalkerBox:GetHeight() + 48
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

AddonTable.OnTabardScanFinished = function(missingCount)
	missingCount = missingCount or 0
	if missingCount > 0 then
		lblTabardScanStatus:SetText(string.format(L["Scan finished. %d without tabard."], missingCount))
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

optionsScrollChild:SetScript("OnShow", UpdateOptionsScrollHeight)
GTIOFrame:SetScript("OnShow", UpdateOptionsScrollHeight)
UpdateOptionsScrollHeight()

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
	DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r The following arguments are valid:\ncolour/color - Toggle colouring of player name and class\nhp/health/bar - Toggle the HP bar under the tooltip\ntitles - Toggle showing of player titles\nrealms - Toggle showing of player realms\ngrank/guildrank - Toggle showing of player guild ranks\ngnotes/guildnotes - Toggle guild notes on tooltips")
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
elseif msg == "titles" then
	if MGTConfig.Titles == "ENABLED" then
		MGTConfig.Titles = 'DISABLED'
	elseif MGTConfig.Titles == "DISABLED" then
		MGTConfig.Titles = 'ENABLED'
	end
elseif msg == "realms" then
	if MGTConfig.Realms == "ENABLED" then
		MGTConfig.Realms = 'DISABLED'
	elseif MGTConfig.Realms == "DISABLED" then
		MGTConfig.Realms = 'ENABLED'
	end
elseif msg == "grank" or msg == "guildrank" then
	if MGTConfig.GuildRank == "ENABLED" then
		MGTConfig.GuildRank = 'DISABLED'
	elseif MGTConfig.GuildRank == "DISABLED" then
		MGTConfig.GuildRank = 'ENABLED'
	end
elseif msg == "gnotes" or msg == "guildnotes" then
	if MGTConfig.GuildNotes == "ENABLED" then
		MGTConfig.GuildNotes = "DISABLED"
	elseif MGTConfig.GuildNotes == "DISABLED" then
		MGTConfig.GuildNotes = "ENABLED"
	end
end

end