QuickHoP_Version = "1.2"
SLASH_QUICKHOP1 = "/qhop"
SLASH_QUICKHOP2 = "/quickhop"

-- Register slash command handler immediately
SlashCmdList["QUICKHOP"] = function(msg)
    if QuickHoP_SlashHandler then
        QuickHoP_SlashHandler(msg)
    end
end

-- English (Default)
QuickHoP_BoPSpellName = "Hand of Protection"
QuickHoP_BoPTargetSet = "HoP target set to: %s"
QuickHoP_BoPTargetCleared = "HoP target cleared"
QuickHoP_BoPCastSuccess = "Casting HoP on %s"
QuickHoP_BoPTargetNotInRange = "HoP target not in range!"
QuickHoP_BoPTargetNotSet = "No HoP target set!"
QuickHoP_NoValidTarget = "No valid target selected!"
QuickHoP_TargetNotFound = "%s not found in raid/party!"
QuickHoP_SpellNotFound = "Hand of Protection not found in spellbook!"

-- German
if (GetLocale() == "deDE") then
    QuickHoP_BoPSpellName = "Hand der Beschützung"
    QuickHoP_BoPTargetSet = "HoP Ziel gesetzt auf: %s"
    QuickHoP_BoPTargetCleared = "HoP Ziel gelöscht"
    QuickHoP_BoPCastSuccess = "Spreche HoP auf %s"
    QuickHoP_BoPTargetNotInRange = "HoP Ziel nicht in Reichweite!"
    QuickHoP_BoPTargetNotSet = "Kein HoP Ziel gesetzt!"
    QuickHoP_NoValidTarget = "Kein gültiges Ziel ausgewählt!"
    QuickHoP_TargetNotFound = "%s nicht in Schlachtzug/Gruppe gefunden!"
    QuickHoP_SpellNotFound = "Hand der Beschützung nicht im Zauberbuch gefunden!"

-- French
elseif (GetLocale() == "frFR") then
    QuickHoP_BoPSpellName = "Main de protection"
    QuickHoP_BoPTargetSet = "Cible HoP définie sur: %s"
    QuickHoP_BoPTargetCleared = "Cible HoP effacée"
    QuickHoP_BoPCastSuccess = "Lance HoP sur %s"
    QuickHoP_BoPTargetNotInRange = "Cible HoP hors de portée!"
    QuickHoP_BoPTargetNotSet = "Aucune cible HoP définie!"
    QuickHoP_NoValidTarget = "Aucune cible valide sélectionnée!"
    QuickHoP_TargetNotFound = "%s introuvable dans le raid/groupe!"
    QuickHoP_SpellNotFound = "Main de protection introuvable dans le grimoire!"
end
