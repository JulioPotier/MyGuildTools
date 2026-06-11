local AddonName, AddonTable = ...
local L = AddonTable.Localize

local DEATH_CHANNEL = "HardcoreDeaths"
local DEATH_CHANNEL_DEBUG = "HardcoreDeathsDebug"
local MGT_DEFAULT_HONOR_FORMAT = "F %NAME% (lvl %LEVEL%) :'("

local honorState = {
	rosterReady = false,
	guildMembers = {},
	memberDetails = {},
	whoPending = {},
	killerWhoPending = {},
	deferredDeathMessages = {},
}

local pendingHonorDeathMessages = {}
local pendingHonorRetryScheduled = false

local pendingWhoQueries = {}
local pendingWhoAfterCombat = false
local whoDispatchScheduled = false

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
	msg = msg or ""
	msg = msg:gsub("|H.-|h(.-)|h", "%1")
	msg = msg:gsub("|c%x%x%x%x%x%x%x%x", "")
	msg = msg:gsub("|r", "")
	msg = msg:gsub("|h", "")
	return msg
end

local function MGTNormalizeDeathChatMessage(msg)
	msg = MGTStripChatCodes(msg)
	msg = MGTTrim(msg)
	local deathLine = msg:match("^(%[[^%]]+%].-[Tt]hey were level %d+%.?)")
		or msg:match("^(%[[^%]]+%].-[Tt]hey were level %d+)")
	return deathLine or msg
end

-- Same extraction as addon F (F.lua): first [name] + "They were level N"
local function MGTExtractDeadPlayerLikeF(msg)
	if type(msg) ~= "string" then
		return ""
	end
	return MGTNormalizeName(msg:match("%[(.-)%]"))
end

local function MGTExtractLevelLikeF(msg)
	if type(msg) ~= "string" then
		return nil
	end
	local lvl = msg:match("[Tt]hey were level%s+(%d+)")
	return lvl and tonumber(lvl) or nil
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

local function MGTIsHonorDebugEnabled()
	return MGTConfig and MGTConfig.HonorGuildDeathDebug == "ENABLED"
end

local function MGTIsHonorListeningEnabled()
	return MGTIsHonorAutoEnabled() or MGTIsHonorDebugEnabled()
end

local function MGTGetDeathChannelName()
	if MGTIsHonorAutoEnabled() then
		return DEATH_CHANNEL
	end
	if MGTIsHonorDebugEnabled() then
		return DEATH_CHANNEL_DEBUG
	end
	return DEATH_CHANNEL
end

local function MGTDebugLog(...)
	if not MGTIsHonorDebugEnabled() then
		return
	end
	local parts = { ... }
	for i = 1, #parts do
		parts[i] = tostring(parts[i])
	end
	print("|cFFFF8800[MyGuildTools Debug]|r " .. table.concat(parts, " "))
end

local function MGTNormalizeChannelLabel(channelName)
	if type(channelName) ~= "string" then
		return ""
	end
	local base = channelName:gsub("^%d+%.%s*", "")
	base = base:gsub("^#", "")
	return MGTTrim(base)
end

local function MGTChannelNameMatchesDeathChannel(channelName)
	local base = MGTNormalizeChannelLabel(channelName):lower()
	if base == "" then
		return false
	end
	return base == MGTGetDeathChannelName():lower()
end

local function MGTChannelNameMatchesHardcoreDeaths(channelName)
	return MGTChannelNameMatchesDeathChannel(channelName)
end

local function MGTIsHardcoreDeathsChannelLikeF(channelBaseName, channelString)
	local base = channelBaseName or channelString or ""
	if type(base) ~= "string" or base == "" then
		return false
	end
	if MGTIsHonorDebugEnabled() and not MGTIsHonorAutoEnabled() then
		return MGTChannelNameMatchesDeathChannel(base)
	end
	if base:lower() == DEATH_CHANNEL:lower() then
		return true
	end
	return MGTNormalizeChannelLabel(base):lower() == DEATH_CHANNEL:lower()
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
	if not MGTIsHonorListeningEnabled() then
		return false
	end
	JoinChannelByName(MGTGetDeathChannelName())
	return true
end

function AddonTable.EnsureHardcoreDeathsChannel()
	if not MGTIsHonorListeningEnabled() then
		return AddonTable.IsHardcoreDeathsChannelJoined()
	end
	if not AddonTable.IsHardcoreDeathsChannelJoined() then
		JoinChannelByName(MGTGetDeathChannelName())
	end
	return AddonTable.IsHardcoreDeathsChannelJoined()
end

function AddonTable.IsHonorGuildDeathDebugEnabled()
	return MGTIsHonorDebugEnabled()
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

local function MGTCanSendWhoNow()
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	if issecure and not issecure() then
		return false
	end
	return true
end

local function MGTExecuteSendWho(query)
	if not query or query == "" or not MGTCanSendWhoNow() then
		return false
	end
	if C_FriendList and C_FriendList.SendWho then
		return pcall(C_FriendList.SendWho, query)
	end
	if SendWho then
		return pcall(SendWho, query)
	end
	return false
end

local function MGTDispatchNextWho()
	whoDispatchScheduled = false
	if #pendingWhoQueries == 0 then
		pendingWhoAfterCombat = false
		return
	end

	if not MGTCanSendWhoNow() then
		pendingWhoAfterCombat = true
		if not whoDispatchScheduled and C_Timer and C_Timer.After then
			whoDispatchScheduled = true
			C_Timer.After(0.5, MGTDispatchNextWho)
		end
		return
	end

	local query = table.remove(pendingWhoQueries, 1)
	local ok = MGTExecuteSendWho(query)
	if not ok then
		table.insert(pendingWhoQueries, 1, query)
		if MGTIsHonorDebugEnabled() then
			MGTDebugLog("SendWho blocked or failed for:", query)
		end
		if C_Timer and C_Timer.After then
			whoDispatchScheduled = true
			C_Timer.After(1, MGTDispatchNextWho)
		end
		return
	end

	if #pendingWhoQueries > 0 then
		if C_Timer and C_Timer.After then
			whoDispatchScheduled = true
			C_Timer.After(0.6, MGTDispatchNextWho)
		end
	else
		pendingWhoAfterCombat = false
	end
end

local function MGTStartWhoDispatch()
	if #pendingWhoQueries == 0 then
		return
	end
	if whoDispatchScheduled then
		return
	end
	whoDispatchScheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0.05, MGTDispatchNextWho)
	else
		MGTDispatchNextWho()
	end
end

local function MGTSafeSendWho(query)
	if not query or query == "" then
		return
	end
	table.insert(pendingWhoQueries, query)
	if InCombatLockdown and InCombatLockdown() then
		pendingWhoAfterCombat = true
		return
	end
	MGTStartWhoDispatch()
end

local function MGTProcessWhoQueue()
	MGTStartWhoDispatch()
end

local function MGTRequestWhoForRace(name, whoQuery)
	if name == "" or honorState.whoPending[name] then
		return
	end
	honorState.whoPending[name] = true
	MGTSafeSendWho(whoQuery or name)
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
	honorState.killerWhoPending[name] = true
	MGTSafeSendWho(whoQuery or name)
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
		-- Unknown single-word killer: send immediately (mob-style), like addon F.
		return MGTFormatSlainReason(killer, false, ""), false
	end

	local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
	if playerFaction and killerFaction ~= playerFaction then
		return MGTFormatSlainReason(killer, true, " (PvP)"), false
	end

	return MGTFormatSlainReason(killer, true, " (Mind Control)"), false
end

local function MGTScheduleHonorDeathRetry()
	if pendingHonorRetryScheduled or not C_Timer or not C_Timer.After then
		return
	end
	pendingHonorRetryScheduled = true
	C_Timer.After(2, function()
		pendingHonorRetryScheduled = false
		MGTProcessPendingHonorDeaths()
	end)
	C_Timer.After(8, function()
		MGTProcessPendingHonorDeaths()
	end)
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
		MGTScheduleHonorDeathRetry()
		return
	end

	local cache = MGTGetHonorRosterCache()

	for i = 1, n do
		local rosterName = GetGuildRosterInfo and GetGuildRosterInfo(i)
		local classDisplay, guid
		if not rosterName or rosterName == "" then
			rosterName, classDisplay, guid = MGTExtractGuildRosterFields(i)
		else
			_, classDisplay, guid = MGTExtractGuildRosterFields(i)
		end
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
	MGTProcessPendingHonorDeaths()
end

local function MGTIsGuildMember(name)
	name = MGTNormalizeName(name)
	if name == "" then
		return false
	end
	if honorState.guildMembers[name] then
		return true
	end
	if not IsInGuild or not IsInGuild() then
		return false
	end
	if GuildRoster then
		GuildRoster()
	end
	local n = GetNumGuildMembers and GetNumGuildMembers()
	if not n or n <= 0 then
		return false
	end
	for i = 1, n do
		local rosterName = GetGuildRosterInfo and GetGuildRosterInfo(i)
		if not rosterName or rosterName == "" then
			rosterName = MGTExtractGuildRosterFields(i)
		end
		local memberName = MGTNormalizeName(rosterName)
		if memberName == name then
			local _, classDisplay, guid = MGTExtractGuildRosterFields(i)
			local class = classDisplay or ""
			local race, sex = MGTResolveInfoFromGuid(guid)
			MGTStoreMemberDetails(name, class, race or "", sex)
			honorState.guildMembers[name] = true
			return true
		end
	end
	return false
end

local function MGTQueueHonorDeathMessage(msg)
	msg = MGTNormalizeDeathChatMessage(msg)
	if not msg or msg == "" then
		return
	end
	for i = 1, #pendingHonorDeathMessages do
		if pendingHonorDeathMessages[i] == msg then
			return
		end
	end
	table.insert(pendingHonorDeathMessages, msg)
end

local function MGTCanProcessHonorDeathNow()
	if MGTIsHonorDebugEnabled() then
		return true
	end
	if not MGTIsHonorAutoEnabled() then
		return false
	end
	if not IsInGuild or not IsInGuild() then
		return false
	end
	if not honorState.rosterReady then
		return false
	end
	return true
end

local function MGTPrepareHonorDeathProcessing()
	if not MGTIsHonorAutoEnabled() then
		return
	end
	if not IsInGuild or not IsInGuild() then
		return
	end
	AddonTable.EnsureHardcoreDeathsChannel()
	if not honorState.rosterReady then
		if GuildRoster then
			GuildRoster()
		end
		MGTRebuildHonorGuildRoster()
	end
end

local function MGTSendHonorToGuild(output)
	if not output or output == "" then
		return false
	end
	return pcall(SendChatMessage, output, "GUILD")
end

local function MGTGetGuildMemberInfo(deadName)
	if not IsInGuild or not IsInGuild() then
		return nil, nil, nil
	end

	deadName = MGTNormalizeName(deadName)
	if deadName == "" then
		return nil, nil, nil
	end

	if not honorState.guildMembers[deadName] then
		local rosterCache = MGTGetHonorRosterCache()
		if rosterCache and rosterCache[deadName] then
			return rosterCache[deadName].class, rosterCache[deadName].race, rosterCache[deadName].sex
		end
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
	-- Fatigue (swimming exhaustion)
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] died from fatigue! [Tt]hey were level (%d+)",
	},
	{
		reason = "fatigue",
		pattern = "^%[(.-)%] died from fatigue in (.+)! [Tt]hey were level (%d+)",
		hasZone = true,
	},
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

local function MGTBuildHonorOutputForMessage(msg)
	msg = MGTNormalizeDeathChatMessage(msg)
	local output, data = AddonTable.BuildHonorDeathOutput(msg)
	if output and output ~= "" and data and data.name ~= "" then
		return output, data
	end

	local dead = MGTExtractDeadPlayerLikeF(msg)
	if dead == "" then
		return nil, nil
	end

	local lvl = MGTExtractLevelLikeF(msg)
	data = {
		name = dead,
		level = tostring(lvl or "?"),
		race = "",
		class = "",
		zone = "",
		reason = "",
		sex = nil,
	}
	local class, race, sex = MGTGetGuildMemberInfo(dead)
	data.class = class or ""
	data.race = race or ""
	data.sex = sex
	output = AddonTable.FormatHonorDeathMessage(data)
	return output, data
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

local function MGTSendHonorForDeathMessage(msg)
	local debug = MGTIsHonorDebugEnabled()
	local auto = MGTIsHonorAutoEnabled()
	msg = MGTNormalizeDeathChatMessage(msg)

	local dead = MGTExtractDeadPlayerLikeF(msg)
	if dead == "" then
		if debug then
			MGTDebugLog("F extract: no name in brackets for:", msg)
		end
		return false
	end

	if auto and not honorState.rosterReady then
		MGTQueueHonorDeathMessage(msg)
		MGTPrepareHonorDeathProcessing()
		MGTScheduleHonorDeathRetry()
		if debug then
			MGTDebugLog("roster not ready, queued for:", dead)
		end
		return false
	end

	if not honorState.guildMembers[dead] and not MGTIsGuildMember(dead) then
		if debug then
			MGTDebugLog("guild member?", "no", dead, "rosterReady=", honorState.rosterReady and "yes" or "no")
		end
		if auto and not honorState.rosterReady then
			MGTQueueHonorDeathMessage(msg)
			MGTPrepareHonorDeathProcessing()
			MGTScheduleHonorDeathRetry()
		end
		return false
	end

	local output, data = MGTBuildHonorOutputForMessage(msg)
	if not output or output == "" or not data then
		if debug then
			MGTDebugLog("no honor output for:", dead)
		end
		return false
	end

	if debug then
		MGTDebugLog("processing msg:", msg)
		MGTDebugLog(
			"parsed NAME=", data.name or "",
			"LEVEL=", data.level or "",
			"RACE=", data.race or "",
			"CLASS=", data.class or "",
			"ZONE=", data.zone or "",
			"REASON=", data.reason or ""
		)
		MGTDebugLog("guild member?", "yes", "rosterReady=", honorState.rosterReady and "yes" or "no")
		MGTDebugLog("honor output:", output)
		print("|cFF0088FF[MyGuildTools]|r " .. L["Honor death test output"] .. " " .. output)
	end

	if auto then
		local sent = MGTSendHonorToGuild(output)
		if debug then
			MGTDebugLog("guild send:", sent and "ok" or "failed")
		end
	end

	return auto or debug
end

local function MGTProcessHardcoreDeathChannelMessage(rawMsg, channelBaseName, channelString)
	if not MGTIsHonorListeningEnabled() then
		return
	end

	if MGTIsHonorDebugEnabled() and not MGTIsHonorAutoEnabled() then
		if not MGTIsHardcoreDeathsChannelLikeF(channelBaseName, channelString) then
			return
		end
		local msg = MGTNormalizeDeathChatMessage(rawMsg)
		if msg == "" then
			return
		end
		MGTHandleHonorDeathMessage(msg)
		return
	end

	if not MGTIsHonorAutoEnabled() then
		return
	end

	if not MGTIsHardcoreDeathsChannelLikeF(channelBaseName, channelString) then
		return
	end

	local msg = MGTStripChatCodes(rawMsg)
	msg = MGTTrim(msg)
	if msg == "" then
		return
	end

	if MGTIsHonorDebugEnabled() then
		MGTDebugLog("HardcoreDeaths channel msg:", msg)
	end

	MGTSendHonorForDeathMessage(msg)
end

function MGTProcessPendingHonorDeaths()
	if #pendingHonorDeathMessages == 0 then
		return
	end
	if not MGTCanProcessHonorDeathNow() and not MGTIsHonorDebugEnabled() then
		MGTPrepareHonorDeathProcessing()
		MGTScheduleHonorDeathRetry()
		return
	end
	local queued = pendingHonorDeathMessages
	pendingHonorDeathMessages = {}
	for i = 1, #queued do
		MGTSendHonorForDeathMessage(queued[i])
	end
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
	msg = MGTNormalizeDeathChatMessage(msg)
	if not msg or msg == "" or not MGTIsHonorListeningEnabled() then
		return
	end

	if MGTIsHonorDebugEnabled() and not MGTIsHonorAutoEnabled() then
		MGTDebugLog("HandleHonorDeathMessage raw:", msg)
		MGTDebugLog("stripped:", MGTStripChatCodes(msg))
		MGTDebugLog("in guild:", (IsInGuild and IsInGuild()) and "yes" or "no")
		MGTDebugLog("channel joined:", AddonTable.IsHardcoreDeathsChannelJoined() and "yes" or "no")
		MGTDebugLog("roster ready:", honorState.rosterReady and "yes" or "no")
		if not honorState.rosterReady then
			MGTRebuildHonorGuildRoster()
		end
		MGTSendHonorForDeathMessage(msg)
		return
	end

	if not MGTIsHonorAutoEnabled() then
		return
	end

	if MGTIsHonorDebugEnabled() then
		MGTDebugLog("auto honor msg:", msg)
	end

	if not MGTCanProcessHonorDeathNow() then
		MGTQueueHonorDeathMessage(msg)
		MGTPrepareHonorDeathProcessing()
		MGTScheduleHonorDeathRetry()
		return
	end

	MGTSendHonorForDeathMessage(msg)
end

local function MGTScheduleChannelJoin()
	if not MGTIsHonorListeningEnabled() then
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
honorFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
honorFrame:RegisterEvent("WHO_LIST_UPDATE")

honorFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		if MGTIsHonorListeningEnabled() then
			MGTScheduleChannelJoin()
			MGTRebuildHonorGuildRoster()
		end
		return
	end

	if event == "PLAYER_GUILD_UPDATE" then
		if MGTIsHonorListeningEnabled() then
			MGTScheduleChannelJoin()
			MGTRebuildHonorGuildRoster()
		end
		return
	end

	if event == "GUILD_ROSTER_UPDATE" then
		if MGTIsHonorListeningEnabled() then
			MGTRebuildHonorGuildRoster()
		end
		return
	end

	if event == "CHAT_MSG_CHANNEL" then
		local rawMsg, _, _, channelString = ...
		local channelBaseName = select(9, ...)
		MGTProcessHardcoreDeathChannelMessage(rawMsg, channelBaseName, channelString)
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		if pendingWhoAfterCombat then
			MGTProcessWhoQueue()
		end
		MGTProcessPendingHonorDeaths()
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
	end
end)

AddonTable.RefreshHonorGuildRoster = MGTRebuildHonorGuildRoster
AddonTable.RefreshHonorGuildChannel = MGTScheduleChannelJoin
