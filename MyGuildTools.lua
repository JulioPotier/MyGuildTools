local AddonName, AddonTable = ...
local L = AddonTable.Localize
local AddonTitle = select(2, C_AddOns.GetAddOnInfo(AddonName))
local PlainAddonTitle = AddonTitle:gsub("|c........", ""):gsub("|r", "")

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
			["Titles"] = "ENABLED",
			["Realms"] = "ENABLED",
			["GuildRank"] = "DISABLED",
			["FontSize"] = "12",
			["SimpleRanks"] = "NO",
			["GuildInviteMenu"] = "DISABLED",
			["GuildNotes"] = "DISABLED",
		}
	end
	
	if MGTConfig.HealthBar == nil then MGTConfig.HealthBar = 'ENABLED' end
	if MGTConfig.Titles == nil then MGTConfig.Titles = 'ENABLED' end
	if MGTConfig.Realms == nil then MGTConfig.Realms = 'ENABLED' end
	if MGTConfig.GuildRank == nil then MGTConfig.GuildRank = 'DISABLED' end
	if MGTConfig.FontSize == nil then MGTConfig.FontSize = '12' end
	if MGTConfig.SimpleRanks == nil then MGTConfig.SimpleRanks = 'NO' end
	if MGTConfig.GuildInviteMenu == nil then MGTConfig.GuildInviteMenu = 'DISABLED' end
	if MGTConfig.GuildNotes == nil then MGTConfig.GuildNotes = 'DISABLED' end
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

local function MGTBuildGuildLine(guildName, guildRankName)
	if not guildName then
		return nil
	end

	local colorPrefix = MGTGetGuildColorPrefix(guildName)
	local colorSuffix = (colorPrefix ~= "") and "|r" or ""

	if MGTConfig.GuildRank == "ENABLED" then
		if MGTConfig.SimpleRanks == "YES" then
			return colorPrefix .. guildName .. " (" .. (guildRankName or "") .. ")" .. colorSuffix
		end
		return colorPrefix .. (guildRankName or "") .. " of " .. guildName .. colorSuffix
	end

	return colorPrefix .. guildName .. colorSuffix
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
	local guildName, guildRankName = GetGuildInfo(person)
	local playerlevel = UnitLevel(person)
	local race = UnitRace(person)
	local localizedClass, englishClass = UnitClass(person)
	local myRealm = GetRealmName("player")

	local theirname, theirRealm = UnitName(person)
	local name

	if theirRealm ~= nil then
		if MGTConfig.Realms == "DISABLED" then
			if MGTConfig.Titles == "ENABLED" then
				name = UnitPVPName(person)
			elseif MGTConfig.Titles == "DISABLED" then
				name = UnitName(person)
			end
		elseif MGTConfig.Realms == "ENABLED" then
			if MGTConfig.Titles == "ENABLED" then
				name = UnitPVPName(person) .. "-" .. theirRealm
			elseif MGTConfig.Titles == "DISABLED" then
				name = UnitName(person) .. "-" .. theirRealm
			end
		end
	elseif theirRealm == myRealm or theirRealm == nil then
		if MGTConfig.Titles == "ENABLED" then
			name = UnitPVPName(person)
		elseif MGTConfig.Titles == "DISABLED" then
			name = UnitName(person)
		end
	end

	if playerlevel == -1 then
		playerlevel = "??"
	end

	local classColor = ""
	local classColorEnd = ""
	if MGTConfig.Colour == "ENABLED" and englishClass and RAID_CLASS_COLORS[englishClass] then
		classColor = "|c" .. RAID_CLASS_COLORS[englishClass].colorStr
		classColorEnd = "|r"
	end

	local levelLine = LEVEL .. " " .. playerlevel .. " " .. race .. " " .. classColor .. localizedClass .. classColorEnd

	if guildName == nil then
		GameTooltipTextLeft1:SetText(classColor .. name .. classColorEnd)
		GameTooltipTextLeft2:SetText(levelLine, 1, 1, 1, true)
	else
		local guildLine = MGTBuildGuildLine(guildName, guildRankName)
		if MGTConfig.Colour == "ENABLED" then
			GameTooltipTextLeft1:SetText(classColor .. name .. classColorEnd .. "\n" .. guildLine)
		else
			if MGTConfig.GuildRank == "ENABLED" then
				if MGTConfig.SimpleRanks == "YES" then
					guildLine = "<" .. guildName .. "> (" .. (guildRankName or "") .. ")"
				else
					guildLine = (guildRankName or "") .. " of <" .. guildName .. ">"
				end
			else
				guildLine = "<" .. guildName .. ">"
			end
			GameTooltipTextLeft1:SetText(name .. "\n" .. guildLine)
		end
		GameTooltipTextLeft2:SetText(levelLine, 1, 1, 1, true)
	end

	if MGTConfig.HealthBar == "ENABLED" then
		GameTooltipStatusBar:Show()
	elseif MGTConfig.HealthBar == "DISABLED" then
		GameTooltipStatusBar:Hide()
	end

	GameTooltipTextLeft3:SetText("")
	MGTAppendGuildNotes(person)
end