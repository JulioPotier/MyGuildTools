local AddonName, AddonTable = ...
local L = AddonTable.Localize

local exportButton
local exportFrame
local exportMessageFrame
local exportMessageScroll
local exportEditBox
local exportEditScroll
local exportStatusText
local unwrapHolder
local unwrapFont
local hookedCommunitiesFrame
local hookedGuildMessageFrame
local hookedScrollingMixin
local hookedChatMixin
local chatEventsRegistered = false
local displayCaptureLog = {}
local exportCaptureReplayActive = false

local exportBufferCount = 0
local exportCaptureCount = 0
local exportPlainLineCount = 0
local lastExportPlainText = ""
local MAX_EXPORT_LINES = 10000
local MAX_EDITBOX_CHARS = 28000
local EDITBOX_MAX_LETTERS = 32000

local function EnsureGuildChatLog()
	if type(MGTGuildChatLog) ~= "table" then
		MGTGuildChatLog = {}
	end
	return MGTGuildChatLog
end

local function EnsureUnwrapFont()
	if unwrapFont then
		return
	end
	unwrapHolder = CreateFrame("Frame", "MGTGuildChatExportUnwrapHolder", UIParent)
	unwrapHolder:SetSize(2, 2)
	unwrapHolder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	unwrapHolder:SetAlpha(0)
	unwrapHolder:Show()
	unwrapFont = unwrapHolder:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	unwrapFont:SetPoint("TOPLEFT", unwrapHolder, "TOPLEFT", 0, 0)
	unwrapFont:Show()
end

local function ApplyFontFromMessageFrame(messageFrame, fontString)
	if not messageFrame or not fontString then
		return
	end
	if messageFrame.GetFontObject then
		local fontObject = messageFrame:GetFontObject()
		if fontObject then
			fontString:SetFontObject(fontObject)
			return
		end
	end
	if messageFrame.GetFont then
		local font, size, flags = messageFrame:GetFont()
		if font then
			fontString:SetFont(font, size, flags)
		end
	end
end

local function StripMarkup(text)
	if type(text) ~= "string" or text == "" then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|h", "")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|A.-|a", "")
	if strtrim then
		return strtrim(text)
	end
	return text:match("^%s*(.-)%s*$") or ""
end

local function UnwrapDisplayString(value, sourceFrame)
	if value == nil then
		return ""
	end

	EnsureUnwrapFont()
	ApplyFontFromMessageFrame(sourceFrame, unwrapFont)
	unwrapFont:Show()

	local ok = pcall(unwrapFont.SetFormattedText, unwrapFont, "%s", value)
	if not ok then
		pcall(unwrapFont.SetText, unwrapFont, tostring(value))
	end

	local plain = unwrapFont:GetText() or ""
	unwrapFont:Hide()
	plain = StripMarkup(plain)

	if plain ~= "" then
		return plain
	end

	unwrapFont:Show()
	pcall(unwrapFont.SetText, unwrapFont, tostring(value))
	plain = StripMarkup(unwrapFont:GetText() or "")
	unwrapFont:Hide()
	return plain
end

local function ClearDisplayCapture()
	wipe(displayCaptureLog)
	exportCaptureCount = 0
end

local function TrimDisplayCapture()
	while #displayCaptureLog > MAX_EXPORT_LINES do
		table.remove(displayCaptureLog, 1)
	end
	exportCaptureCount = #displayCaptureLog
end

local function AppendDisplayCapture(line)
	line = StripMarkup(line)
	if line == "" then
		return
	end
	displayCaptureLog[#displayCaptureLog + 1] = line
	TrimDisplayCapture()
end

local function CaptureIncomingMessage(message, sourceFrame)
	if message == nil then
		return ""
	end
	if type(message) == "string" and message ~= "" then
		return StripMarkup(message)
	end
	return UnwrapDisplayString(message, sourceFrame)
end

local function ApplyEditBoxText(editBox, text)
	if not editBox then
		return
	end
	text = text or ""
	editBox:SetMaxLetters(EDITBOX_MAX_LETTERS)
	editBox:EnableMouse(true)
	editBox:Show()
	editBox:SetText("")
	editBox:SetText(text)
	editBox:SetMaxLetters(EDITBOX_MAX_LETTERS)
	editBox:SetCursorPosition(0)
	editBox:ClearFocus()
end

local function AppendSessionLogLine(line)
	line = StripMarkup(line)
	if line == "" then
		return
	end
	local log = EnsureGuildChatLog()
	log[#log + 1] = line
	if #log > MAX_EXPORT_LINES then
		table.remove(log, 1)
	end
end

local function GetCommunitiesChat()
	if not CommunitiesFrame then
		return nil
	end
	return CommunitiesFrame.Chat
end

local function IsGuildChatMessageFrame(messageFrame)
	local resolved = ResolveGuildChatMessageFrame()
	return resolved ~= nil and messageFrame == resolved
end

local function ResolveGuildChatMessageFrame()
	local chat = GetCommunitiesChat()
	if not chat then
		return nil
	end
	if chat.MessageFrame and chat.MessageFrame.GetNumMessages then
		return chat.MessageFrame
	end
	if _G["CommunitiesFrameChatMessageFrame"] and _G["CommunitiesFrameChatMessageFrame"].GetNumMessages then
		return _G["CommunitiesFrameChatMessageFrame"]
	end
	return nil
end

local function IsClubMessageId(value)
	return type(value) == "table" and type(value.epoch) == "number" and type(value.position) == "number"
end

local function PlainLineFromMessageIndex(sourceFrame, chat, index)
	if not sourceFrame.GetMessageInfo then
		return ""
	end

	local formatted, _, _, clubId, streamId, messageId = sourceFrame:GetMessageInfo(index)
	local plain = UnwrapDisplayString(formatted, sourceFrame)

	if plain ~= "" then
		return plain
	end

	if not chat or not C_Club or not C_Club.GetMessageInfo or not IsClubMessageId(messageId) then
		return ""
	end

	local ok, clubMessage = pcall(C_Club.GetMessageInfo, clubId, streamId, messageId)
	if not ok or type(clubMessage) ~= "table" then
		return ""
	end

	if chat.FormatMessage then
		local okFormat, rebuilt = pcall(chat.FormatMessage, chat, clubId, streamId, clubMessage)
		if okFormat and rebuilt then
			plain = UnwrapDisplayString(rebuilt, sourceFrame)
		end
	end

	return plain
end

local function CollectPlainLinesFromBuffer(sourceFrame, chat)
	local lines = {}
	if not sourceFrame or not sourceFrame.GetNumMessages then
		return lines
	end

	if sourceFrame.RefreshIfNecessary then
		sourceFrame:RefreshIfNecessary()
	end

	exportBufferCount = sourceFrame:GetNumMessages() or 0
	for index = exportBufferCount, 1, -1 do
		local plain = PlainLineFromMessageIndex(sourceFrame, chat, index)
		if plain ~= "" then
			lines[#lines + 1] = plain
		end
	end

	return lines
end

local function CollectPlainLinesFromVisible(sourceFrame)
	local lines = {}
	if not sourceFrame or not sourceFrame.ForEachVisibleLineText then
		return lines
	end

	sourceFrame:ForEachVisibleLineText(function(text)
		local plain = StripMarkup(text or "")
		if plain ~= "" then
			lines[#lines + 1] = plain
		end
	end)

	-- API iterates bottom-up; export oldest-first.
	for left, right = 1, math.floor(#lines / 2) do
		lines[left], lines[right] = lines[right], lines[left]
		right = #lines - left + 1
	end

	return lines
end

local function CopyCaptureLog()
	local lines = {}
	for index = 1, #displayCaptureLog do
		lines[index] = displayCaptureLog[index]
	end
	return lines
end

local function ResolveExportLines(sourceFrame, chat, bufferLines)
	exportCaptureCount = #displayCaptureLog

	if exportCaptureCount > 0 and exportCaptureCount >= exportBufferCount * 0.5 then
		return CopyCaptureLog(), L["Guild chat export from capture"]
	end

	if #bufferLines > 0 then
		return bufferLines, L["Guild chat export from display"]
	end

	if exportCaptureCount > 0 then
		return CopyCaptureLog(), L["Guild chat export from capture"]
	end

	local visibleLines = CollectPlainLinesFromVisible(sourceFrame)
	if #visibleLines > 0 then
		return visibleLines, L["Guild chat export from visible"]
	end

	local merged = MergeSessionLogLines(bufferLines)
	if #merged > 0 then
		return merged, L["Guild chat export from log"]
	end

	return bufferLines, L["Guild chat export from display"]
end

local function HookGuildChatMessageFrame(messageFrame)
	if hookedGuildMessageFrame or not messageFrame or not hooksecurefunc then
		return
	end
	if messageFrame == exportMessageFrame then
		return
	end
	hookedGuildMessageFrame = true

	hooksecurefunc(messageFrame, "AddMessage", function(self, message)
		local plain = CaptureIncomingMessage(message, self)
		if plain ~= "" then
			AppendDisplayCapture(plain)
		end
	end)

	hooksecurefunc(messageFrame, "BackFillMessage", function(self, message)
		local plain = CaptureIncomingMessage(message, self)
		if plain ~= "" then
			AppendDisplayCapture(plain)
		end
	end)

	hooksecurefunc(messageFrame, "Clear", function()
		if exportCaptureReplayActive then
			return
		end
		ClearDisplayCapture()
	end)
end

local function HookScrollingMessageFrameMixin()
	if hookedScrollingMixin or not ScrollingMessageFrameMixin or not hooksecurefunc then
		return
	end
	hookedScrollingMixin = true

	hooksecurefunc(ScrollingMessageFrameMixin, "AddMessage", function(self, message)
		if not IsGuildChatMessageFrame(self) then
			return
		end
		local plain = CaptureIncomingMessage(message, self)
		if plain ~= "" then
			AppendDisplayCapture(plain)
		end
	end)

	hooksecurefunc(ScrollingMessageFrameMixin, "BackFillMessage", function(self, message)
		if not IsGuildChatMessageFrame(self) then
			return
		end
		local plain = CaptureIncomingMessage(message, self)
		if plain ~= "" then
			AppendDisplayCapture(plain)
		end
	end)
end

local function HookCommunitiesChatMixin()
	if hookedChatMixin or not CommunitiesChatMixin or not hooksecurefunc then
		return
	end
	hookedChatMixin = true

	if CommunitiesChatMixin.FormatMessage then
		hooksecurefunc(CommunitiesChatMixin, "FormatMessage", function(_, _, _, message)
			if type(message) ~= "table" or not exportCaptureReplayActive then
				return
			end
			local content = message.content
			if type(content) == "string" and content ~= "" then
				AppendDisplayCapture(StripMarkup(content))
			end
		end)
	end
end

local function TryCaptureByReplay(chat, messageFrame)
	if not chat or not messageFrame then
		return false
	end
	if (messageFrame:GetNumMessages() or 0) == 0 then
		return false
	end
	if #displayCaptureLog > 0 then
		return true
	end

	HookGuildChatMessageFrame(messageFrame)
	HookScrollingMessageFrameMixin()

	exportCaptureReplayActive = true
	ClearDisplayCapture()

	if chat.DisplayChat then
		pcall(chat.DisplayChat, chat)
	end
	if chat.BackfillMessages then
		pcall(chat.BackfillMessages, chat)
	end
	if #displayCaptureLog == 0 and chat.RefreshChat then
		pcall(chat.RefreshChat, chat)
	end

	exportCaptureReplayActive = false
	return #displayCaptureLog > 0
end

local function CloneBufferToMessageFrame(sourceFrame, destFrame)
	if not sourceFrame or not destFrame then
		return 0
	end

	destFrame:Clear()
	if sourceFrame.RefreshIfNecessary then
		sourceFrame:RefreshIfNecessary()
	end

	local copied = 0
	local count = sourceFrame:GetNumMessages() or 0
	exportBufferCount = count

	for index = count, 1, -1 do
		local message, r, g, b, e1, e2, e3, e4, e5, e6, e7, e8 = sourceFrame:GetMessageInfo(index)
		if message ~= nil then
			if e8 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2, e3, e4, e5, e6, e7, e8)
			elseif e7 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2, e3, e4, e5, e6, e7)
			elseif e6 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2, e3, e4, e5, e6)
			elseif e5 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2, e3, e4, e5)
			elseif e4 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2, e3, e4)
			elseif e3 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2, e3)
			elseif e2 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1, e2)
			elseif e1 ~= nil then
				destFrame:AddMessage(message, r, g, b, e1)
			else
				destFrame:AddMessage(message, r or 1, g or 0.82, b or 0)
			end
			copied = copied + 1
		end
	end

	if destFrame.RefreshIfNecessary then
		destFrame:RefreshIfNecessary()
	end

	return copied
end

local function BuildEditBoxText(lines)
	local parts = {}
	local totalChars = 0
	local included = 0
	local truncated = false

	for index = 1, #lines do
		local line = lines[index]
		local add = #line + (index > 1 and 1 or 0)
		if totalChars + add > MAX_EDITBOX_CHARS then
			truncated = true
			break
		end
		parts[#parts + 1] = line
		totalChars = totalChars + add
		included = index
	end

	local text = table.concat(parts, "\n")
	if truncated then
		text = string.format(L["Guild chat export truncated"], included, #lines) .. "\n\n" .. text
	end

	return text, truncated, included, #text
end

local function MergeSessionLogLines(bufferLines)
	local seen = {}
	local merged = {}

	for index = 1, #bufferLines do
		local line = bufferLines[index]
		if not seen[line] then
			seen[line] = true
			merged[#merged + 1] = line
		end
	end

	local log = EnsureGuildChatLog()
	for index = 1, #log do
		local line = log[index]
		if not seen[line] then
			seen[line] = true
			merged[#merged + 1] = line
		end
	end

	return merged
end

local function FillExportFrame(sourceFrame)
	local chat = GetCommunitiesChat()

	TryCaptureByReplay(chat, sourceFrame)

	local cloned = CloneBufferToMessageFrame(sourceFrame, exportMessageFrame)
	if exportMessageFrame and exportMessageFrame.ScrollToBottom then
		exportMessageFrame:ScrollToBottom()
	end

	local bufferLines = CollectPlainLinesFromBuffer(sourceFrame, chat)
	local lines, sourceLabel = ResolveExportLines(sourceFrame, chat, bufferLines)

	if #lines < math.min(50, math.max(1, exportBufferCount * 0.05)) then
		lines = MergeSessionLogLines(bufferLines)
		if #lines > 0 then
			sourceLabel = L["Guild chat export from log"]
		end
	end

	exportPlainLineCount = #lines
	local text, truncated, included, charCount = BuildEditBoxText(lines)

	if text == "" then
		text = L["Guild chat export empty"] .. "\n" .. L["Guild chat export reload hint"]
		if cloned > 0 then
			text = L["Guild chat export use chat view"] .. "\n\n" .. text
		end
	end

	lastExportPlainText = text
	ApplyEditBoxText(exportEditBox, text)

	if exportStatusText then
		if exportPlainLineCount > 0 or cloned > 0 or exportCaptureCount > 0 then
			exportStatusText:SetText(string.format(
				L["Guild chat export full status"],
				exportPlainLineCount,
				exportBufferCount,
				cloned,
				charCount,
				truncated and "+" or "-"
			) .. " | " .. string.format(L["Guild chat export capture status"], exportCaptureCount) .. " — " .. sourceLabel)
		else
			exportStatusText:SetText(string.format(
				L["Guild chat export debug status"],
				exportBufferCount,
				#EnsureGuildChatLog()
			) .. " | " .. string.format(L["Guild chat export capture status"], exportCaptureCount))
		end
	end

	local editLines = math.min(exportPlainLineCount, 40)
	exportEditBox:SetHeight(math.max(120, editLines * 14 + 16))
	exportEditScroll:UpdateScrollChildRect()
end

local function CreateExportFrame()
	if exportFrame then
		return
	end

	exportFrame = CreateFrame("Frame", "MGTGuildChatExportFrame", UIParent, "BackdropTemplate")
	exportFrame:SetSize(700, 520)
	exportFrame:SetPoint("CENTER")
	exportFrame:SetFrameStrata("DIALOG")
	exportFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	exportFrame:Hide()
	exportFrame:EnableMouse(true)

	local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -14)
	title:SetText(L["Guild chat export title"])

	exportStatusText = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	exportStatusText:SetPoint("TOP", 0, -32)
	exportStatusText:SetWidth(660)

	local closeButton = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -4, -4)

	local selectAllButton = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
	selectAllButton:SetSize(160, 22)
	selectAllButton:SetPoint("BOTTOMRIGHT", -16, 14)
	selectAllButton:SetText(L["Select all"])
	selectAllButton:SetScript("OnClick", function()
		if exportEditBox then
			exportEditBox:SetFocus()
			if exportEditBox.HighlightText then
				exportEditBox:HighlightText(0, -1)
			else
				exportEditBox:HighlightText()
			end
			print("|cFF0088FF[MyGuildTools]|r " .. L["Guild chat export selected"])
		end
	end)

	local chatViewLabel = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	chatViewLabel:SetPoint("TOPLEFT", 16, -48)
	chatViewLabel:SetText(L["Guild chat export chat view label"])

	exportMessageScroll = CreateFrame("ScrollFrame", "MGTGuildChatExportMessageScroll", exportFrame, "UIPanelScrollFrameTemplate")
	exportMessageScroll:SetPoint("TOPLEFT", 16, -64)
	exportMessageScroll:SetPoint("RIGHT", exportFrame, "RIGHT", -32, 0)
	exportMessageScroll:SetHeight(220)

	exportMessageFrame = CreateFrame("ScrollingMessageFrame", "MGTGuildChatExportMessageFrame", exportMessageScroll)
	exportMessageFrame:SetSize(620, 220)
	exportMessageFrame:SetFontObject(ChatFontNormal)
	exportMessageFrame:SetJustifyH("LEFT")
	exportMessageFrame:SetFading(false)
	exportMessageFrame:SetHyperlinksEnabled(true)
	if exportMessageFrame.SetIndentedWordWrap then
		exportMessageFrame:SetIndentedWordWrap(true)
	end
	if exportMessageFrame.SetTextCopyable then
		exportMessageFrame:SetTextCopyable(true)
	end
	if exportMessageFrame.SetMaxLines then
		exportMessageFrame:SetMaxLines(MAX_EXPORT_LINES + 50)
	end
	exportMessageFrame:SetScript("OnMouseWheel", function(frame, delta)
		if frame.ScrollByAmount then
			frame:ScrollByAmount(delta * 3)
		end
	end)
	exportMessageScroll:SetScrollChild(exportMessageFrame)

	local plainLabel = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	plainLabel:SetPoint("TOPLEFT", exportMessageScroll, "BOTTOMLEFT", 0, -6)
	plainLabel:SetText(L["Guild chat export plain label"])

	exportEditScroll = CreateFrame("ScrollFrame", "MGTGuildChatExportEditScroll", exportFrame, "UIPanelScrollFrameTemplate")
	exportEditScroll:SetPoint("TOPLEFT", plainLabel, "BOTTOMLEFT", 0, -4)
	exportEditScroll:SetPoint("BOTTOMRIGHT", -36, 40)
	exportEditScroll:SetHeight(160)

	exportEditBox = CreateFrame("EditBox", "MGTGuildChatExportEditBox", exportEditScroll)
	exportEditBox:SetMultiLine(true)
	exportEditBox:SetAutoFocus(false)
	exportEditBox:SetFontObject(ChatFontNormal)
	exportEditBox:SetTextColor(1, 0.82, 0)
	exportEditBox:SetMaxLetters(EDITBOX_MAX_LETTERS)
	exportEditBox:SetWidth(600)
	exportEditBox:SetHeight(160)
	if exportEditBox.SetTextInsets then
		exportEditBox:SetTextInsets(6, 6, 6, 6)
	end
	exportEditBox:EnableMouse(true)
	exportEditBox:Show()
	exportEditBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	exportEditScroll:SetScrollChild(exportEditBox)

	local hint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOM", 0, 36)
	hint:SetWidth(660)
	hint:SetText(L["Guild chat export copy hint dual"])
end

function AddonTable.ShowGuildChatExportDialog()
	if not CommunitiesFrame or not CommunitiesFrame:IsShown() then
		print("|cFF0088FF[MyGuildTools]|r " .. L["Guild chat export no guild chat"])
		return
	end

	local sourceFrame = ResolveGuildChatMessageFrame()
	if not sourceFrame then
		print("|cFF0088FF[MyGuildTools]|r " .. L["Guild chat export unavailable"])
		return
	end

	CreateExportFrame()
	HookGuildChatMessageFrame(sourceFrame)

	if sourceFrame.GetFontObject then
		if exportMessageFrame.SetFontObject then
			exportMessageFrame:SetFontObject(sourceFrame:GetFontObject() or ChatFontNormal)
		end
		if exportEditBox.SetFontObject then
			exportEditBox:SetFontObject(sourceFrame:GetFontObject() or ChatFontNormal)
		end
	end

	exportFrame:Show()
	FillExportFrame(sourceFrame)

	if exportPlainLineCount == 0 and exportBufferCount > 0 then
		print(string.format(
			"|cFF0088FF[MyGuildTools]|r %s (buffer=%d, plain=0, chars=%d, log=%d)",
			L["Guild chat export empty"],
			exportBufferCount,
			#lastExportPlainText,
			#EnsureGuildChatLog()
		))
	end
end

local function OnChatEvent(_, event, msg, author)
	if event ~= "CHAT_MSG_GUILD" and event ~= "CHAT_MSG_OFFICER" then
		return
	end
	local text = StripMarkup(msg)
	if text == "" then
		return
	end
	author = StripMarkup(author or "")
	if author ~= "" and not text:find(author, 1, true) then
		AppendSessionLogLine("[" .. author .. "]: " .. text)
	else
		AppendSessionLogLine(text)
	end
end

local function RegisterChatEvents()
	if chatEventsRegistered then
		return
	end
	chatEventsRegistered = true

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_GUILD")
	frame:RegisterEvent("CHAT_MSG_OFFICER")
	frame:SetScript("OnEvent", OnChatEvent)

	if ChatFrame_AddMessageEventFilter then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", function(_, _, msg, author)
			OnChatEvent(nil, "CHAT_MSG_GUILD", msg, author)
			return false
		end)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", function(_, _, msg, author)
			OnChatEvent(nil, "CHAT_MSG_OFFICER", msg, author)
			return false
		end)
	end
end

local function IsGuildChatVisible()
	if not CommunitiesFrame or not CommunitiesFrame:IsShown() then
		return false
	end
	if not COMMUNITIES_FRAME_DISPLAY_MODES or not CommunitiesFrame.GetDisplayMode then
		return false
	end
	return CommunitiesFrame:GetDisplayMode() == COMMUNITIES_FRAME_DISPLAY_MODES.CHAT
end

local function RefreshExportButton()
	if not exportButton then
		return
	end
	if IsGuildChatVisible() then
		exportButton:Show()
	else
		exportButton:Hide()
	end
end

local function HookCommunitiesFrame()
	if hookedCommunitiesFrame or not CommunitiesFrame then
		return
	end
	hookedCommunitiesFrame = true

	if not exportButton then
		exportButton = CreateFrame("Button", "MGTGuildChatExportButton", CommunitiesFrame, "UIPanelButtonTemplate")
		exportButton:SetSize(80, 22)
		exportButton:SetText(L["Export"])
		exportButton:SetScript("OnClick", AddonTable.ShowGuildChatExportDialog)
		exportButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(L["Guild chat export tooltip"] .. "\n" .. L["Guild chat export scroll capture hint"], 1, 1, 1, true)
			GameTooltip:Show()
		end)
		exportButton:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		if CommunitiesFrame.StreamDropdown then
			exportButton:SetPoint("LEFT", CommunitiesFrame.StreamDropdown, "RIGHT", 8, 0)
		elseif CommunitiesFrame.Chat then
			exportButton:SetPoint("TOPRIGHT", CommunitiesFrame.Chat, "TOPRIGHT", -8, 8)
		else
			exportButton:SetPoint("TOPRIGHT", CommunitiesFrame, "TOPRIGHT", -48, -32)
		end
	end

	if hooksecurefunc and CommunitiesFrame.SetDisplayMode then
		hooksecurefunc(CommunitiesFrame, "SetDisplayMode", RefreshExportButton)
	end

	CommunitiesFrame:HookScript("OnShow", RefreshExportButton)
	CommunitiesFrame:HookScript("OnHide", RefreshExportButton)
	RefreshExportButton()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_Communities" then
		HookCommunitiesFrame()
		HookScrollingMessageFrameMixin()
		HookCommunitiesChatMixin()
		HookGuildChatMessageFrame(ResolveGuildChatMessageFrame())
	elseif event == "PLAYER_LOGIN" then
		EnsureGuildChatLog()
		RegisterChatEvents()
		HookCommunitiesFrame()
		HookScrollingMessageFrameMixin()
		HookCommunitiesChatMixin()
		HookGuildChatMessageFrame(ResolveGuildChatMessageFrame())
	end
end)

EnsureGuildChatLog()
RegisterChatEvents()
HookCommunitiesFrame()
HookScrollingMessageFrameMixin()
HookCommunitiesChatMixin()
HookGuildChatMessageFrame(ResolveGuildChatMessageFrame())