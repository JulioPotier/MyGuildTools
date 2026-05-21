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
			["GuildInviteMenu"] = "DISABLED"
		}
	end
	
	if MGTConfig.HealthBar == nil then MGTConfig.HealthBar = 'ENABLED' end
	if MGTConfig.Titles == nil then MGTConfig.Titles = 'ENABLED' end
	if MGTConfig.Realms == nil then MGTConfig.Realms = 'ENABLED' end
	if MGTConfig.GuildRank == nil then MGTConfig.GuildRank = 'DISABLED' end
	if MGTConfig.FontSize == nil then MGTConfig.FontSize = '12' end
	if MGTConfig.SimpleRanks == nil then MGTConfig.SimpleRanks = 'NO' end
	if MGTConfig.GuildInviteMenu == nil then MGTConfig.GuildInviteMenu = 'DISABLED' end
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

function CreateGTTooltip(person)

GameTooltipHeaderText:SetFont("Fonts\\FRIZQT__.ttf", tonumber(MGTConfig.FontSize), "")
	local guildName, guildRankName, guildRankIndex = GetGuildInfo(person);
	local playerlevel = UnitLevel(person)
	local race = UnitRace(person)
	local localizedClass, englishClass, classIndex = UnitClass(person)
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
	
	if playerlevel == -1 then playerlevel = "??" end
	
	if MGTConfig.Colour == "ENABLED" then		
		if guildName == nil then
			GameTooltipTextLeft1:SetText("|c" .. RAID_CLASS_COLORS[englishClass].colorStr .. name .. "|r")
			GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " |c" .. RAID_CLASS_COLORS[englishClass].colorStr .. localizedClass .. "|r", 1, 1, 1, true)
		elseif guildName ~= nil then
			if MGTConfig.GuildRank == "ENABLED" then
				if MGTConfig.SimpleRanks == "YES" then
					GameTooltipTextLeft1:SetText("|c" .. RAID_CLASS_COLORS[englishClass].colorStr .. name .. "|r\n|cFF40FB40" .. guildName .. " (" .. guildRankName .. ")|r")
					GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " |c" .. RAID_CLASS_COLORS[englishClass].colorStr .. localizedClass .. "|r", 1, 1, 1, true)
				elseif MGTConfig.SimpleRanks == "NO" then
					GameTooltipTextLeft1:SetText("|c" .. RAID_CLASS_COLORS[englishClass].colorStr .. name .. "|r\n|cFF40FB40" .. guildRankName .. " of " .. guildName .. "|r")
					GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " |c" .. RAID_CLASS_COLORS[englishClass].colorStr .. localizedClass .. "|r", 1, 1, 1, true)
				end
			elseif MGTConfig.GuildRank == "DISABLED" then
				GameTooltipTextLeft1:SetText("|c" .. RAID_CLASS_COLORS[englishClass].colorStr .. name .. "|r\n|cFF40FB40" .. guildName .. "|r")
				GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " |c" .. RAID_CLASS_COLORS[englishClass].colorStr .. localizedClass .. "|r", 1, 1, 1, true)
			end
		end
	elseif MGTConfig.Colour == "DISABLED" then
		if guildName == nil then
			GameTooltipTextLeft1:SetText(name)
			GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " " .. localizedClass, 1, 1, 1, true)
		elseif guildName ~= nil then
			if MGTConfig.GuildRank == "ENABLED" then
				if MGTConfig.SimpleRanks == "YES" then
					GameTooltipTextLeft1:SetText(name .. "\n<" .. guildName .. "> (" .. guildRankName .. ")")
					GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " " .. localizedClass, 1, 1, 1, true)
				elseif MGTConfig.SimpleRanks == "NO" then
					GameTooltipTextLeft1:SetText(name .. "\n" .. guildRankName .. " of <" .. guildName .. ">")
					GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " " .. localizedClass, 1, 1, 1, true)
				end
			elseif MGTConfig.GuildRank == "DISABLED" then
				GameTooltipTextLeft1:SetText(name .. "\n<" .. guildName .. ">")
				GameTooltipTextLeft2:SetText(LEVEL .. " " .. playerlevel .. " " .. race .. " " .. localizedClass, 1, 1, 1, true)
			end
		end
	end		
		
	if MGTConfig.HealthBar == "ENABLED" then
		GameTooltipStatusBar:Show()
	elseif MGTConfig.HealthBar == "DISABLED" then
		GameTooltipStatusBar:Hide()
	end
	
	GameTooltipTextLeft3:SetText("")
end