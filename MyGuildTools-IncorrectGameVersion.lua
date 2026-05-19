local MGTWelcome = CreateFrame("Frame")
MGTWelcome:RegisterEvent("ADDON_LOADED")

function MGTEventHandler(self, event, arg1)

	if event == "ADDON_LOADED" and arg1 == "MyGuildTools" then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF0088FF[MyGuildTools]|r |cFFFF0000[Error]|r This addon is incompatible with the Retail version of WoW.")
	end

end

MGTWelcome:SetScript("OnEvent", MGTEventHandler)
