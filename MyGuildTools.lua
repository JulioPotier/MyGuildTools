local AddonName, AddonTable = ...
local L = AddonTable.Localize
local AddonTitle = select(2, C_AddOns.GetAddOnInfo(AddonName))
local PlainAddonTitle = AddonTitle:gsub("|c........", ""):gsub("|r", "")

local MGT_DEFAULT_TOOLTIP_FORMAT = "%GUILD% %RANK%"

local function MGTMigrateTooltipFormat(format)
	if not format or format == "" then
		return MGT_DEFAULT_TOOLTIP_FORMAT
	end
	if not format:find("%%NAME%%", 1, true)
		and not format:find("%%LEVEL%%", 1, true)
		and not format:find("%%RACE%%", 1, true)
		and not format:find("%%CLASS%%", 1, true) then
		return format
	end

	local lines = {}
	for line in format:gmatch("[^\n]+") do
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
	return MGT_DEFAULT_TOOLTIP_FORMAT
end

local GTWelcome = CreateFrame("Frame")
GTWelcome:RegisterEvent("ADDON_LOADED")
GTWelcome:RegisterEvent("PLAYER_TARGET_CHANGED")

local function GTEventHandler(self, event, arg1)

if event == "ADDON_LOADED" and arg1 == AddonName then
	if MGTConfig == nil and GTConfig ~= nil then
		MGTConfig = GTConfig
		GTConfig = nil
	end
	if MGTConfig == nil or MGTConfig == "" then
		MGTConfig = {
			["Colour"] = "ENABLED",
			["HealthBar"] = "ENABLED",
			["TooltipFormat"] = "%GUILD% %RANK%",
			["FontSize"] = "14",
			["GuildInviteMenu"] = "DISABLED",
			["GuildNotes"] = "DISABLED",
			["TabardStalkerGuildOnly"] = "ENABLED",
			["TabardStalkerMinLevel"] = "40",
			["TabardStalkerAutoScan"] = "DISABLED",
			["HonorGuildDeathAuto"] = "DISABLED",
			["HonorGuildDeathFormat"] = "F",
			["HonorDeathRosterCache"] = {},
			["HonorDeathPlayerCache"] = {},
		}
	end
	
	if MGTConfig.HealthBar == nil then MGTConfig.HealthBar = 'ENABLED' end
	if MGTConfig.FontSize == nil or MGTConfig.FontSize == "" then MGTConfig.FontSize = '14' end
	if MGTConfig.TooltipFormat == nil then
		if MGTConfig.GuildRank == "ENABLED" then
			if MGTConfig.SimpleRanks == "YES" then
				MGTConfig.TooltipFormat = "%GUILDNAME% %RANK%"
			else
				MGTConfig.TooltipFormat = "%RANK% of %GUILDNAME%"
			end
		else
			MGTConfig.TooltipFormat = "%GUILDNAME%"
		end
	end
	if MGTConfig.GuildInviteMenu == nil then MGTConfig.GuildInviteMenu = 'DISABLED' end
	if MGTConfig.GuildNotes == nil then MGTConfig.GuildNotes = 'DISABLED' end
	if MGTConfig.TabardStalkerGuildOnly == nil then MGTConfig.TabardStalkerGuildOnly = 'ENABLED' end
	if MGTConfig.TabardStalkerMinLevel == nil then MGTConfig.TabardStalkerMinLevel = '40' end
	if MGTConfig.TabardStalkerAutoScan == nil then MGTConfig.TabardStalkerAutoScan = 'DISABLED' end
	if MGTConfig.HonorGuildDeathAuto == nil then MGTConfig.HonorGuildDeathAuto = 'DISABLED' end
	if MGTConfig.HonorGuildDeathFormat == nil then MGTConfig.HonorGuildDeathFormat = 'F' end
	if MGTConfig.HonorDeathRosterCache == nil then MGTConfig.HonorDeathRosterCache = {} end
	if MGTConfig.HonorDeathPlayerCache == nil then MGTConfig.HonorDeathPlayerCache = {} end
	if MGTConfig.TooltipFormat then
		MGTConfig.TooltipFormat = MGTMigrateTooltipFormat(MGTConfig.TooltipFormat)
	end
elseif event == "PLAYER_TARGET_CHANGED" then
	if C_AddOns.IsAddOnLoaded("ShadowedUnitFrames") == true then
		SUFUnittarget:SetScript("OnEnter", function(self)
			if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
				GameTooltip:Show()
				CreateGTTooltip("target")
			end
		end)
		
		SUFUnittarget:SetScript("OnLeave", function(self)
			if MGTConfig.HealthBar == "ENABLED" then
				GameTooltipStatusBar:Hide()
			elseif MGTConfig.HealthBar == "DISABLED" then
				GameTooltipStatusBar:Hide()
			end
	
			GameTooltipHeaderText:SetFont("Fonts\\FRIZQT__.ttf", 14, "")
		end)
	end
end

end

GTWelcome:SetScript("OnEvent", GTEventHandler)

-- Game Tooltip

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
	if UnitIsPlayer("mouseover") and not UnitIsUnit("mouseover", "player") then
		CreateGTTooltip("mouseover")
	end
end)

GameTooltip:HookScript("OnTooltipCleared", function(self)
	if MGTConfig.HealthBar == "ENABLED" then
		GameTooltipStatusBar:Hide()
	elseif MGTConfig.HealthBar == "DISABLED" then
		GameTooltipStatusBar:Hide()
	end
	
	GameTooltipHeaderText:SetFont("Fonts\\FRIZQT__.ttf", 14, "")
end)

-- Target Frame

TargetFrame:HookScript("OnEnter", function(self)
	if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
		if UnitInRange("target") == false then
			return
		elseif UnitInRange("target") == true then
			CreateGTTooltip("target")
		end
	end
end)

TargetFrame:HookScript("OnLeave", function(self)
	if MGTConfig.HealthBar == "ENABLED" then
		GameTooltipStatusBar:Hide()
	elseif MGTConfig.HealthBar == "DISABLED" then
		GameTooltipStatusBar:Hide()
	end
	
	GameTooltipHeaderText:SetFont("Fonts\\FRIZQT__.ttf", 14, "")
	GameTooltip:Show()
end)

-- Tooltip Creation

local MGT_COLOR_GUILD_OURS = "FF66FF66"
local MGT_COLOR_GUILD_OTHER = "FF66CCFF"
local MGT_COLOR_NOTE = "FFAAAAAA"

local rosterFrame = CreateFrame("Frame")
rosterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rosterFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
rosterFrame:SetScript("OnEvent", function()
	if IsInGuild and IsInGuild() and GuildRoster then
		GuildRoster()
	end
end)

local function MGTGetOurGuildName()
	if not IsInGuild or not IsInGuild() then
		return nil
	end
	return GetGuildInfo("player")
end

local function MGTIsOurGuild(guildName)
	local ourGuild = MGTGetOurGuildName()
	return guildName ~= nil and ourGuild ~= nil and guildName == ourGuild
end

local function MGTGetGuildColorPrefix(guildName)
	if MGTConfig.Colour ~= "ENABLED" or not guildName then
		return ""
	end
	if MGTIsOurGuild(guildName) then
		return "|c" .. MGT_COLOR_GUILD_OURS
	end
	return "|c" .. MGT_COLOR_GUILD_OTHER
end

local function MGTCanViewOfficerNote()
	if C_GuildInfo and C_GuildInfo.CanViewOfficerNote then
		return C_GuildInfo.CanViewOfficerNote()
	end
	return IsInGuild and IsInGuild()
end

local function MGTNamesMatch(nameA, nameB)
	if not nameA or not nameB then
		return false
	end
	if Ambiguate then
		return Ambiguate(nameA, "none") == Ambiguate(nameB, "none")
	end
	return nameA == nameB
end

local function MGTRequestGuildRoster()
	if IsInGuild and IsInGuild() and GuildRoster then
		GuildRoster()
	end
end

local function MGTGetGuildRosterNotes(unit)
	if not IsInGuild or not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo then
		return nil, nil
	end

	local unitName = GetUnitName(unit, true)
	if not unitName then
		return nil, nil
	end

	MGTRequestGuildRoster()

	local numMembers = GetNumGuildMembers()
	if not numMembers or numMembers == 0 then
		return nil, nil
	end

	for i = 1, numMembers do
		local rosterName, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(i)
		if MGTNamesMatch(unitName, rosterName) then
			return publicNote, officerNote
		end
	end

	return nil, nil
end

local function MGTStripColorCodes(text)
	return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function MGTIsTooltipLineEmpty(line)
	local plain = MGTStripColorCodes(line):gsub("%s+", ""):gsub("%(", ""):gsub("%)", "")
	return plain == ""
end

local function MGTCleanTooltipText(text)
	local lines = {}
	for line in (text or ""):gmatch("[^\n]+") do
		if not MGTIsTooltipLineEmpty(line) then
			lines[#lines + 1] = line
		end
	end
	if #lines == 0 then
		return text or ""
	end
	return table.concat(lines, "\n")
end

local function MGTColoredGuildText(guildName, text)
	if not text or text == "" then
		return ""
	end
	if not guildName or guildName == "" then
		return text
	end
	local colorPrefix = MGTGetGuildColorPrefix(guildName)
	if colorPrefix == "" then
		return text
	end
	return colorPrefix .. text .. "|r"
end

local function MGTStripNativeGuildLine()
	local line1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
	if not line1 or not line1:find("\n", 1, true) then
		return
	end
	local nameOnly = line1:match("^([^\n]+)")
	if nameOnly then
		GameTooltipTextLeft1:SetText(nameOnly)
	end
end

local function MGTBuildTooltipExtraText(person)
	local format = MGTMigrateTooltipFormat(MGTConfig.TooltipFormat or MGT_DEFAULT_TOOLTIP_FORMAT)
	if format == "" then
		return nil
	end

	local guildName, guildRankName = GetGuildInfo(person)
	local _, theirRealm = UnitName(person)

	local guildToken = ""
	if guildName and guildName ~= "" then
		guildToken = MGTColoredGuildText(guildName, "<" .. guildName .. ">")
	end
	local rankToken = ""
	if guildRankName and guildRankName ~= "" then
		rankToken = MGTColoredGuildText(guildName, "(" .. guildRankName .. ")")
	end
	local text = format
	text = text:gsub("%%GUILDNAME%%", guildToken)
	text = text:gsub("%%GUILD%%", guildToken)
	text = text:gsub("%%RANK%%", rankToken)
	text = text:gsub("%%REALM%%", theirRealm or "")

	text = MGTCleanTooltipText(text)
	if text == "" then
		return nil
	end
	return text
end

local function MGTAppendTooltipFormatLines(person)
	local extra = MGTBuildTooltipExtraText(person)
	if not extra then
		return
	end

	if GetGuildInfo(person) then
		MGTStripNativeGuildLine()
	end

	for line in extra:gmatch("[^\n]+") do
		if line ~= "" then
			GameTooltip:AddLine(line, 1, 1, 1, true)
		end
	end
end

local function MGTAppendGuildNotes(person)
	if MGTConfig.GuildNotes ~= "ENABLED" then
		return
	end

	local guildName = GetGuildInfo(person)
	if not MGTIsOurGuild(guildName) then
		return
	end

	local publicNote, officerNote = MGTGetGuildRosterNotes(person)
	local added = false

	if publicNote and publicNote ~= "" then
		GameTooltip:AddLine("|c" .. MGT_COLOR_NOTE .. L["Note:"] .. " " .. publicNote .. "|r", 0.67, 0.67, 0.67, true)
		added = true
	end

	if MGTCanViewOfficerNote() and officerNote and officerNote ~= "" then
		GameTooltip:AddLine("|c" .. MGT_COLOR_NOTE .. L["Officer:"] .. " " .. officerNote .. "|r", 0.67, 0.67, 0.67, true)
		added = true
	end

	if added then
		GameTooltip:Show()
	end
end

function CreateGTTooltip(person)

GameTooltipHeaderText:SetFont("Fonts\\FRIZQT__.ttf", tonumber(MGTConfig.FontSize), "")
	MGTAppendTooltipFormatLines(person)

	if MGTConfig.HealthBar == "ENABLED" then
		GameTooltipStatusBar:Show()
	elseif MGTConfig.HealthBar == "DISABLED" then
		GameTooltipStatusBar:Hide()
	end

	MGTAppendGuildNotes(person)
end