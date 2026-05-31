local AddonName, AddonTable = ...
local L = AddonTable.Localize

local DEATH_CHANNEL = "HardcoreDeaths"
local MGT_DEFAULT_HONOR_FORMAT = "F"

local honorState = {
	rosterReady = false,
	guildMembers = {},
	memberDetails = {},
	whoPending = {},
	whoDeferredRace = {},
	killerWhoPending = {},
	whoDeferredKiller = {},
	deferredDeathMessages = {},
}

local MGT_ALLIANCE_RACES = {
	["human"] = true,
	["dwarf"] = true,
	["night elf"] = true,
	["gnome"] = true,
	["humain"] = true,
	["nain"] = true,
	["elfe de la nuit"] = true,
}

local MGT_HORDE_RACES = {
	["orc"] = true,
	["troll"] = true,
	["tauren"] = true,
	["undead"] = true,
	["scourge"] = true,
	["mort-vivant"] = true,
}

local function MGTTrim(s)
	if type(s) ~= "string" then
		return ""
	end
	if strtrim then
		return strtrim(s)
	end
	return s:match("^%s*(.-)%s*$") or ""
end

local function MGTNormalizeName(name)
	name = MGTTrim(name or "")
	if name == "" then
		return ""
	end
	if Ambiguate then
		name = Ambiguate(name, "none") or name
	end
	return name
end

local function MGTStripChatCodes(msg)
	return (msg or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function MGTGetHonorFormat()
	if MGTConfig and MGTConfig.HonorGuildDeathFormat and MGTConfig.HonorGuildDeathFormat ~= "" then
		return MGTConfig.HonorGuildDeathFormat
	end
	return MGT_DEFAULT_HONOR_FORMAT
end

local function MGTIsHonorAutoEnabled()
	return MGTConfig and MGTConfig.HonorGuildDeathAuto == "ENABLED"
end

local function MGTChannelNameMatchesHardcoreDeaths(channelName)
	if type(channelName) ~= "string" then
		return false
	end
	local base = channelName:gsub("^%d+%.%s*", "")
	base = base:gsub("^#", "")
	return base:lower() == DEATH_CHANNEL:lower()
end

function AddonTable.IsHardcoreDeathsChannelJoined()
	local channels = { GetChannelList() }
	for i = 1, #channels, 2 do
		local name = channels[i + 1]
		if MGTChannelNameMatchesHardcoreDeaths(name) then
			return true
		end
	end
	return false
end

function AddonTable.JoinHardcoreDeathsChannel()
	if not MGTIsHonorAutoEnabled() then
		return false
	end
	JoinChannelByName(DEATH_CHANNEL)
	return true
end

function AddonTable.EnsureHardcoreDeathsChannel()
	if not MGTIsHonorAutoEnabled() then
		return AddonTable.IsHardcoreDeathsChannelJoined()
	end
	if not AddonTable.IsHardcoreDeathsChannelJoined() then
		JoinChannelByName(DEATH_CHANNEL)
	end
	return AddonTable.IsHardcoreDeathsChannelJoined()
end

local function MGTGetHonorRosterCache()
	if not MGTConfig then
		return nil
	end
	if MGTConfig.HonorDeathRosterCache == nil then
		MGTConfig.HonorDeathRosterCache = {}
	end
	return MGTConfig.HonorDeathRosterCache
end

local function MGTExtractGuildRosterFields(index)
	if not GetGuildRosterInfo then
		return nil, nil, nil
	end

	local results = { GetGuildRosterInfo(index) }
	local rosterName = results[1]
	local classDisplay = results[5] or results[11]
	local guid

	for j = 1, #results do
		local value = results[j]
		if type(value) == "string" and value:match("^Player%-") then
			guid = value
			break
		end
	end

	return rosterName, classDisplay, guid
end

local function MGTResolveInfoFromGuid(guid)
	if not guid or guid == "" or not GetPlayerInfoByGUID then
		return nil, nil
	end
	local _, _, localizedRace, _, sex = GetPlayerInfoByGUID(guid)
	local race = (localizedRace and localizedRace ~= "") and localizedRace or nil
	if sex ~= 2 and sex ~= 3 then
		sex = nil
	end
	return race, sex
end

local function MGTGetTitlePronouns(sex)
	if sex == 3 then
		return L["Title pronoun she cap"], L["Title pronoun she lower"]
	elseif sex == 2 then
		return L["Title pronoun he cap"], L["Title pronoun he lower"]
	end
	return "", ""
end

local function MGTStoreMemberDetails(name, class, race, sex)
	if name == "" then
		return
	end
	honorState.memberDetails[name] = {
		class = class or "",
		race = race or "",
		sex = sex,
	}
	local cache = MGTGetHonorRosterCache()
	if cache and (race ~= "" or class ~= "" or sex) then
		cache[name] = {
			class = class or (cache[name] and cache[name].class) or "",
			race = (race ~= "" and race) or (cache[name] and cache[name].race) or "",
			sex = sex or (cache[name] and cache[name].sex),
		}
	end
end

local function MGTCanSendWho()
	return not (InCombatLockdown and InCombatLockdown())
end

local function MGTSendWhoQuery(query)
	if not MGTCanSendWho() then
		return false
	end
	if C_FriendList and C_FriendList.SendWho then
		C_FriendList.SendWho(query)
	elseif SendWho then
		SendWho(query)
	else
		return false
	end
	return true
end

local function MGTFlushDeferredWhoRequests()
	if not MGTCanSendWho() then
		return
	end

	for name, query in pairs(honorState.whoDeferredRace) do
		if name == "" or honorState.whoPending[name] then
			honorState.whoDeferredRace[name] = nil
		else
			honorState.whoDeferredRace[name] = nil
			if MGTSendWhoQuery(query) then
				honorState.whoPending[name] = true
			else
				honorState.whoDeferredRace[name] = query
			end
			return
		end
	end

	for name, query in pairs(honorState.whoDeferredKiller) do
		if name == "" or honorState.killerWhoPending[name] then
			honorState.whoDeferredKiller[name] = nil
		else
			honorState.whoDeferredKiller[name] = nil
			if MGTSendWhoQuery(query) then
				honorState.killerWhoPending[name] = true
			else
				honorState.whoDeferredKiller[name] = query
			end
			return
		end
	end
end

local function MGTRequestWhoForRace(name, whoQuery)
	if name == "" or honorState.whoPending[name] then
		return
	end
	local query = whoQuery or name
	if not MGTSendWhoQuery(query) then
		honorState.whoDeferredRace[name] = query
		return
	end
	honorState.whoPending[name] = true
end

local function MGTGetPlayerCache()
	if not MGTConfig then
		return nil
	end
	if MGTConfig.HonorDeathPlayerCache == nil then
		MGTConfig.HonorDeathPlayerCache = {}
	end
	return MGTConfig.HonorDeathPlayerCache
end

local function MGTStorePlayerWhoResult(playerName, race, class)
	local cache = MGTGetPlayerCache()
	if not cache then
		return
	end
	playerName = MGTNormalizeName(playerName)
	if playerName == "" then
		return
	end
	cache[playerName] = {
		race = race or "",
		class = class or "",
		isPlayer = true,
	}
end

local function MGTUpdateRaceFromWhoList(name)
	if not GetNumWhoResults or not GetWhoInfo then
		return nil
	end

	name = MGTNormalizeName(name)
	for i = 1, GetNumWhoResults() do
		local whoName, _, _, race, class = GetWhoInfo(i)
		if MGTNormalizeName(whoName) == name then
			MGTStorePlayerWhoResult(name, race, class)
			return race, class
		end
	end
	return nil
end

local function MGTRaceToFaction(race)
	if not race or race == "" then
		return nil
	end
	local key = race:lower()
	if MGT_ALLIANCE_RACES[key] then
		return "Alliance"
	end
	if MGT_HORDE_RACES[key] then
		return "Horde"
	end
	return nil
end

local function MGTGetOnlinePlayerFaction(name)
	if not UnitExists or not UnitName or not UnitFactionGroup then
		return nil
	end

	local units = { "player", "party1", "party2", "party3", "party4" }
	if IsInRaid and IsInRaid() then
		units = {}
		for i = 1, 40 do
			units[#units + 1] = "raid" .. i
		end
	elseif IsInGroup and IsInGroup() then
		units = { "player", "party1", "party2", "party3", "party4" }
	end

	for _, unit in ipairs(units) do
		if UnitExists(unit) and UnitName(unit) then
			if MGTNormalizeName(UnitName(unit)) == name then
				return UnitFactionGroup(unit)
			end
		end
	end

	return nil
end

local function MGTGetCachedPlayerFaction(playerName)
	playerName = MGTNormalizeName(playerName)
	if playerName == "" then
		return nil
	end

	local onlineFaction = MGTGetOnlinePlayerFaction(playerName)
	if onlineFaction then
		return onlineFaction
	end

	if honorState.guildMembers[playerName] and UnitFactionGroup then
		return UnitFactionGroup("player")
	end

	local cache = MGTGetPlayerCache()
	if cache and cache[playerName] and cache[playerName].race then
		return MGTRaceToFaction(cache[playerName].race)
	end

	return nil
end

local function MGTStripKillerArticle(killer)
	killer = MGTTrim(killer or "")
	if killer:match("^an ") then
		return MGTTrim(killer:sub(4))
	end
	if killer:match("^a ") then
		return MGTTrim(killer:sub(3))
	end
	return killer
end

local function MGTRequestWhoForKiller(name, whoQuery)
	if name == "" or honorState.killerWhoPending[name] then
		return
	end
	local query = whoQuery or name
	if not MGTSendWhoQuery(query) then
		honorState.whoDeferredKiller[name] = query
		return
	end
	honorState.killerWhoPending[name] = true
end

local function MGTFormatSlainReason(killer, isPlayer, playerSuffix)
	killer = MGTStripKillerArticle(killer)
	if killer == "" then
		return "slain"
	end
	if isPlayer then
		return "slain by " .. killer .. (playerSuffix or "")
	end
	return "slain by a " .. killer
end

-- Returns %REASON% phrase and needsKillerWho (for deferred /who lookup).
local function MGTBuildKilledReason(killer)
	killer = MGTStripKillerArticle(killer)
	if killer == "" then
		return "slain", false
	end

	if killer:find("%s") then
		return MGTFormatSlainReason(killer, false, ""), false
	end

	local normalizedKiller = MGTNormalizeName(killer)
	local playerCache = MGTGetPlayerCache()
	if playerCache and playerCache[normalizedKiller] and playerCache[normalizedKiller].isPlayer == false then
		return MGTFormatSlainReason(killer, false, ""), false
	end

	local killerFaction = MGTGetCachedPlayerFaction(normalizedKiller)

	if not killerFaction then
		MGTRequestWhoForKiller(normalizedKiller, killer)
		local whoRace = MGTUpdateRaceFromWhoList(normalizedKiller)
		if whoRace then
			killerFaction = MGTRaceToFaction(whoRace)
		end
	end

	if not killerFaction then
		return "slain by " .. killer, true
	end

	local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
	if playerFaction and killerFaction ~= playerFaction then
		return MGTFormatSlainReason(killer, true, " (PvP)"), false
	end

	return MGTFormatSlainReason(killer, true, " (Mind Control)"), false
end

local function MGTRebuildHonorGuildRoster()
	wipe(honorState.guildMembers)
	wipe(honorState.memberDetails)
	honorState.rosterReady = false

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

	local cache = MGTGetHonorRosterCache()

	for i = 1, n do
		local rosterName, classDisplay, guid = MGTExtractGuildRosterFields(i)
		local name = MGTNormalizeName(rosterName)
		if name ~= "" then
			local class = classDisplay or ""
			local race, sex = MGTResolveInfoFromGuid(guid)
			race = race or ""
			if race == "" and cache and cache[name] and cache[name].race then
				race = cache[name].race
			end
			if not sex and cache and cache[name] and cache[name].sex then
				sex = cache[name].sex
			end
			if (class == "" or class == nil) and cache and cache[name] and cache[name].class then
				class = cache[name].class
			end
			MGTStoreMemberDetails(name, class, race, sex)
			honorState.guildMembers[name] = true
			if race == "" then
				MGTRequestWhoForRace(name, rosterName)
			end
		end
	end

	honorState.rosterReady = true
end

local function MGTGetGuildMemberInfo(deadName)
	if not IsInGuild or not IsInGuild() then
		return nil, nil, nil
	end

	deadName = MGTNormalizeName(deadName)
	if deadName == "" then
		return nil, nil, nil
	end

	local cached = honorState.memberDetails[deadName]

	if GuildRoster then
		GuildRoster()
	end

	if GetNumGuildMembers and GetGuildRosterInfo then
		local n = GetNumGuildMembers()
		for i = 1, n do
			local rosterName, classDisplay, guid = MGTExtractGuildRosterFields(i)
			if MGTNormalizeName(rosterName) == deadName then
				local class = classDisplay or ""
				local race, sex = MGTResolveInfoFromGuid(guid)
				race = race or ""
				if race == "" and cached and cached.race then
					race = cached.race
				end
				if not sex and cached and cached.sex then
					sex = cached.sex
				end
				if race == "" then
					local rosterCache = MGTGetHonorRosterCache()
					if rosterCache and rosterCache[deadName] and rosterCache[deadName].race then
						race = rosterCache[deadName].race
					end
				end
				if not sex then
					local rosterCache = MGTGetHonorRosterCache()
					if rosterCache and rosterCache[deadName] and rosterCache[deadName].sex then
						sex = rosterCache[deadName].sex
					end
				end
				MGTStoreMemberDetails(deadName, class, race, sex)
				if race == "" then
					MGTRequestWhoForRace(deadName, rosterName)
					local whoRace, whoClass = MGTUpdateRaceFromWhoList(deadName)
					if whoRace and whoRace ~= "" then
						race = whoRace
						if whoClass and whoClass ~= "" then
							class = whoClass
						end
						MGTStoreMemberDetails(deadName, class, race, sex)
					end
				end
				return class, race, sex
			end
		end
	end

	if cached then
		return cached.class, cached.race, cached.sex
	end

	local rosterCache = MGTGetHonorRosterCache()
	if rosterCache and rosterCache[deadName] then
		return rosterCache[deadName].class, rosterCache[deadName].race, rosterCache[deadName].sex
	end

	return nil, nil, nil
end

local KILLED_PARSE_RULES = {
	"^%[(.-)%] has been slain by a (.+) in (.+)! [Tt]hey were level (%d+)",
	"^%[(.-)%] has been slain by an (.+) in (.+)! [Tt]hey were level (%d+)",
	"^%[(.-)%] has been slain by (.+) in (.+)! [Tt]hey were level (%d+)",
}

local DEATH_PARSE_RULES = {
	{
		reason = "drown",
		pattern = "^%[(.-)%] drowned to death in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "drown",
		pattern = "^%[(.-)%] drowned to death! [Tt]hey were level (%d+)",
	},
	{
		reason = "fall",
		pattern = "^%[(.-)%] fell to their death in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fall",
		pattern = "^%[(.-)%] fell to their death! [Tt]hey were level (%d+)",
	},
	-- Fatigue (swimming exhaustion) — phrases may change; adjust when confirmed
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] succumbed to fatigue in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] died of fatigue in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] died from fatigue in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] succumbed to fatigue! [Tt]hey were level (%d+)",
	},
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] died of fatigue! [Tt]hey were level (%d+)",
	},
	-- Fire (campfire / environmental fire) — phrases may change; adjust when confirmed
	{
		reason = "fire",
		pattern = "^%[(.-)%] burned to death in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fire",
		pattern = "^%[(.-)%] burnt to death in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fire",
		pattern = "^%[(.-)%] died to fire in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
	{
		reason = "fire",
		pattern = "^%[(.-)%] burned to death! [Tt]hey were level (%d+)",
	},
	{
		reason = "fire",
		pattern = "^%[(.-)%] burnt to death! [Tt]hey were level (%d+)",
	},
}

-- Fallback when Blizzard wording differs: match keywords in the death phrase (before zone).
local ENVIRONMENTAL_KEYWORD_RULES = {
	{ reason = "fatigue", keywords = { "fatigue", "exhaustion", "épuisement", "épuisé" } },
	{ reason = "fire", keywords = { "burned to death", "burnt to death", "caught fire", "campfire", "brûlé", "brule", "feu", "burned", "burnt" } },
}

local function MGTParseEnvironmentalByKeyword(msg)
	local name, body, level = msg:match("^%[(.-)%] (.+)! [Tt]hey were level (%d+)")
	if not name then
		return nil
	end

	local zone = body:match(" in (.+)$") or ""
	local deathPart = body
	if zone ~= "" then
		deathPart = body:sub(1, #body - #zone - 4)
	end
	local deathLower = deathPart:lower()

	for _, rule in ipairs(ENVIRONMENTAL_KEYWORD_RULES) do
		for _, keyword in ipairs(rule.keywords) do
			if deathLower:find(keyword:lower(), 1, true) then
				return name, zone, level, rule.reason
			end
		end
	end

	return nil
end

local function MGTBuildEnvironmentalDeathData(name, zone, level, reason)
	name = MGTNormalizeName(name)
	local class, race, sex = MGTGetGuildMemberInfo(name)

	return {
		name = name,
		level = level and tostring(level) or "?",
		race = race or "",
		class = class or "",
		zone = zone or "",
		reason = reason,
		sex = sex,
	}
end

function AddonTable.ParseHonorDeathMessage(msg)
	if type(msg) ~= "string" then
		return nil
	end

	msg = MGTStripChatCodes(msg)
	msg = MGTTrim(msg)

	for _, pattern in ipairs(KILLED_PARSE_RULES) do
		local name, killer, zone, level = msg:match(pattern)
		if name then
			name = MGTNormalizeName(name)
			local class, race, sex = MGTGetGuildMemberInfo(name)
			local reason, needsKillerWho = MGTBuildKilledReason(killer)

			return {
				name = name,
				level = level and tostring(level) or "?",
				race = race or "",
				class = class or "",
				zone = zone or "",
				reason = reason,
				sex = sex,
				needsKillerWho = needsKillerWho,
			}
		end
	end

	for _, rule in ipairs(DEATH_PARSE_RULES) do
		local name, zone, level = msg:match(rule.pattern)
		if name then
			if not rule.hasZone then
				level = zone
				zone = ""
			end
			return MGTBuildEnvironmentalDeathData(name, zone, level, rule.reason)
		end
	end

	local name, zone, level, reason = MGTParseEnvironmentalByKeyword(msg)
	if name then
		return MGTBuildEnvironmentalDeathData(name, zone, level, reason)
	end

	return nil
end

function AddonTable.FormatHonorDeathMessage(data, format)
	if not data then
		return nil
	end

	format = format or MGTGetHonorFormat()
	local titleCap, titleLower = MGTGetTitlePronouns(data.sex)
	local text = format
	text = text:gsub("%%NAME%%", data.name or "")
	text = text:gsub("%%LEVEL%%", data.level or "?")
	text = text:gsub("%%RACE%%", data.race or "")
	text = text:gsub("%%CLASS%%", data.class or "")
	text = text:gsub("%%ZONE%%", data.zone or "")
	text = text:gsub("%%REASON%%", data.reason or "")
	text = text:gsub("%%TITLE%%", titleCap)
	text = text:gsub("%%title%%", titleLower)
	return text
end

function AddonTable.BuildHonorDeathOutput(msg)
	local data = AddonTable.ParseHonorDeathMessage(msg)
	if not data then
		return nil, nil
	end
	return AddonTable.FormatHonorDeathMessage(data), data
end

function AddonTable.TestHonorDeathMessage(msg)
	if GuildRoster then
		GuildRoster()
	end
	local output, data = AddonTable.BuildHonorDeathOutput(msg)
	if not data then
		print("|cFF0088FF[MyGuildTools]|r " .. L["Honor death parse failed"])
		return
	end
	print("|cFF0088FF[MyGuildTools]|r " .. L["Honor death test output"] .. " " .. (output or ""))
	print("|cFF0088FF[MyGuildTools]|r NAME=" .. (data.name or "")
		.. " LEVEL=" .. (data.level or "")
		.. " RACE=" .. (data.race or "")
		.. " CLASS=" .. (data.class or "")
		.. " ZONE=" .. (data.zone or "")
		.. " REASON=" .. (data.reason or ""))
	local titleCap, titleLower = MGTGetTitlePronouns(data.sex)
	if titleCap ~= "" then
		print("|cFF0088FF[MyGuildTools]|r TITLE=" .. titleCap .. " title=" .. titleLower)
	end
	if data.race == "" then
		print("|cFF0088FF[MyGuildTools]|r " .. L["Honor death race pending"])
	end
end

local function MGTIsDeathChannelEvent(...)
	local channelBaseName = select(9, ...)
	local channelName = select(4, ...)
	local base = channelBaseName or channelName or ""
	if type(base) ~= "string" then
		return false
	end
	return base:lower() == DEATH_CHANNEL:lower()
end

local function MGTSendHonorForDeathMessage(msg)
	local output, data = AddonTable.BuildHonorDeathOutput(msg)
	if not output or not data or data.name == "" then
		return false
	end

	if not honorState.guildMembers[data.name] then
		return false
	end

	if data.needsKillerWho then
		honorState.deferredDeathMessages[msg] = true
		return false
	end

	SendChatMessage(output, "GUILD")
	return true
end

local function MGTProcessDeferredHonorDeaths()
	for msg in pairs(honorState.deferredDeathMessages) do
		local _, data = AddonTable.BuildHonorDeathOutput(msg)
		if data and not data.needsKillerWho then
			MGTSendHonorForDeathMessage(msg)
			honorState.deferredDeathMessages[msg] = nil
		end
	end
end

local function MGTHandleHonorDeathMessage(msg)
	if not MGTIsHonorAutoEnabled() then
		return
	end
	if not IsInGuild or not IsInGuild() then
		return
	end
	if not AddonTable.IsHardcoreDeathsChannelJoined() then
		return
	end
	if not honorState.rosterReady then
		return
	end

	MGTSendHonorForDeathMessage(msg)
end

local function MGTScheduleChannelJoin()
	if not MGTIsHonorAutoEnabled() then
		return
	end
	AddonTable.EnsureHardcoreDeathsChannel()
	if C_Timer then
		C_Timer.After(2, AddonTable.EnsureHardcoreDeathsChannel)
		C_Timer.After(8, AddonTable.EnsureHardcoreDeathsChannel)
	end
end

local honorFrame = CreateFrame("Frame")
honorFrame:RegisterEvent("PLAYER_LOGIN")
honorFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
honorFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
honorFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
honorFrame:RegisterEvent("CHAT_MSG_CHANNEL")
honorFrame:RegisterEvent("WHO_LIST_UPDATE")
honorFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

honorFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		if MGTIsHonorAutoEnabled() then
			MGTScheduleChannelJoin()
			MGTRebuildHonorGuildRoster()
		end
		return
	end

	if event == "PLAYER_GUILD_UPDATE" then
		if MGTIsHonorAutoEnabled() then
			MGTScheduleChannelJoin()
			MGTRebuildHonorGuildRoster()
		end
		return
	end

	if event == "GUILD_ROSTER_UPDATE" then
		if MGTIsHonorAutoEnabled() then
			MGTRebuildHonorGuildRoster()
		end
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		MGTFlushDeferredWhoRequests()
		return
	end

	if event == "CHAT_MSG_CHANNEL" then
		if not MGTIsDeathChannelEvent(...) then
			return
		end
		local msg = ...
		MGTHandleHonorDeathMessage(msg)
		return
	end

	if event == "WHO_LIST_UPDATE" then
		for name in pairs(honorState.whoPending) do
			local race, class = MGTUpdateRaceFromWhoList(name)
			if race and race ~= "" then
				local existing = honorState.memberDetails[name]
				MGTStoreMemberDetails(
					name,
					class or (existing and existing.class) or "",
					race,
					existing and existing.sex
				)
			end
			honorState.whoPending[name] = nil
		end
		for name in pairs(honorState.killerWhoPending) do
			local race = MGTUpdateRaceFromWhoList(name)
			if not race or race == "" then
				local cache = MGTGetPlayerCache()
				if cache then
					cache[name] = { isPlayer = false }
				end
			end
			honorState.killerWhoPending[name] = nil
		end
		MGTProcessDeferredHonorDeaths()
		MGTFlushDeferredWhoRequests()
	end
end)

AddonTable.RefreshHonorGuildRoster = MGTRebuildHonorGuildRoster
AddonTable.RefreshHonorGuildChannel = MGTScheduleChannelJoin
