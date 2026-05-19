local AddonName, a = ...
a.Localize = setmetatable({}, {__index = function(_, key) return key end})
local L = a.Localize

-- English: keys are used as labels (metatable fallback).
-- French:
if GetLocale() == "frFR" then
	L["Font size changed to"] = "La taille de la police a été changée en"
	L["MyGuildTools"] = "Outils de guilde"
	L["Tooltip"] = "Info-bulle"
	L["Information unavailable"] = "Information non disponible"
	L["Select One"] = "Choisissez-en un"
	L["Show guild rank in tooltips"] = "Afficher le rang de guilde dans les info-bulles"
	L["Show healthbar under player tooltips"] = "Afficher la barre de santé sous les info-bulles des joueurs"
	L["Show player realms in tooltips"] = "Afficher les royaumes des joueurs dans les info-bulles"
	L["Show player titles in tooltips"] = "Afficher les titres des joueurs dans les info-bulles"
	L["Show rank after guild name"] = "Afficher le rang après le nom de guilde"
	L["Target out of range"] = "Cible hors de portée"
	L["Tooltip font size:"] = "Taille de la police de l'info-bulle:"
	L["Use colours"] = "Utilisez des couleurs"
	L["Guild Invite"] = "Invitation de guilde"
	L["Add a right-click menu to /ginvite"] = "Ajouter un menu contextuel pour /ginvite"
end
