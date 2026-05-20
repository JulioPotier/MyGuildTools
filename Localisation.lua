local AddonName, a = ...
a.Localize = setmetatable({}, {__index = function(_, key) return key end})
local L = a.Localize

L["Guild invite key hint"] =
	"Keybind: create a macro with |cffffffff/mgtginvite|r, put it on an action bar, then bind a key to that slot."

L["Tip line"] = "Tip me golds on |cFFFF69B4Kirbybank-Soulseeker|r"
L["Add Guild Member"] = "Add Guild Member"

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
	L["Guild invite key hint"] = "Raccourci : créez une macro avec |cffffffff/mgtginvite|r, placez-la sur une barre d'action, puis assignez une touche à cet emplacement."
	L["Tip line"] = "Offrez moi de l'or sur |cFFFF69B4Kirbybank-Soulseeker|r"
	L["Add Guild Member"] = "Ajouter un membre de guilde"
end
