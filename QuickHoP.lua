BINDING_HEADER_QUICKHOP = "QuickHoP"
BINDING_NAME_QUICKHOP_SET = "Set HoP Target"
BINDING_NAME_QUICKHOP_CLEAR = "Clear HoP Target"
BINDING_NAME_QUICKHOP_CAST = "Cast HoP on Target"

if not QuickHoP_Settings then
    QuickHoP_Settings = {}
end
if QuickHoP_Settings.showfeedback == nil then QuickHoP_Settings.showfeedback = true end
if QuickHoP_Settings.scale == nil then QuickHoP_Settings.scale = 1.0 end
if QuickHoP_Settings.showCooldown == nil then QuickHoP_Settings.showCooldown = true end
if QuickHoP_Settings.showTarget == nil then QuickHoP_Settings.showTarget = true end
if QuickHoP_Settings.showIcon == nil then QuickHoP_Settings.showIcon = true end

local QuickHoP_Frame = CreateFrame("Frame")
local QuickHoP_HoPSpellIndex = nil
local QuickHoP_HoPCooldown = 0
local QuickHoP_PartyData = {}
local QuickHoP_SyncTimer = 0
local QuickHoP_UIUpdateTimer = 0
local QuickHoP_AddonPrefix = "QkHoP"
local QuickHoP_CachedSpellIndex = nil
local QuickHoP_CachedSpellTexture = nil
local QuickHoP_CachedSpellRank = nil
QuickHoP_DebugMode = false

function QuickHoP_OnLoad()
    this:RegisterEvent("PLAYER_LOGIN")
    this:RegisterEvent("SPELLS_CHANGED")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("CHAT_MSG_ADDON")
    this:RegisterEvent("PARTY_MEMBERS_CHANGED")
    this:RegisterEvent("RAID_ROSTER_UPDATE")
    this:SetBackdropColor(0.0, 0.0, 0.0, 0.5)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r version "..QuickHoP_Version.." loaded successfully!")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Use /qhop or /quickhop for commands")
end

function QuickHoP_OnUpdate(elapsed)
    if not elapsed then return end
    
    QuickHoP_SyncTimer = QuickHoP_SyncTimer + elapsed
    if QuickHoP_SyncTimer >= 5 then
        QuickHoP_SyncTimer = 0
        QuickHoP_BroadcastTarget()
    end
    
    QuickHoP_UIUpdateTimer = QuickHoP_UIUpdateTimer + elapsed
    if QuickHoP_UIUpdateTimer >= 3.0 then
        QuickHoP_UIUpdateTimer = 0
        QuickHoP_UpdateUI()
    end
end

function QuickHoP_OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        QuickHoP_ScanSpells()
        QuickHoP_UpdateUI()
        QuickHoP_BroadcastTarget()
    elseif event == "CHAT_MSG_ADDON" then
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] CHAT_MSG_ADDON: prefix="..tostring(arg1)..", msg="..tostring(arg2)..", channel="..tostring(arg3)..", sender="..tostring(arg4), 0.7, 0.7, 1)
        end
        
        if arg1 == QuickHoP_AddonPrefix and (arg3 == "PARTY" or arg3 == "RAID") then
            QuickHoP_ReceiveTarget(arg4, arg2)
        end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        QuickHoP_BroadcastTarget()
        QuickHoP_UpdateOptionsUI()
    end
end

function QuickHoP_ScanSpells()
    local highestRank = 0
    local i = 1
    QuickHoP_CachedSpellIndex = nil
    QuickHoP_CachedSpellTexture = nil
    QuickHoP_CachedSpellRank = nil
    
    while true do
        local spellName, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        if string.find(spellName, QuickHoP_BoPSpellName) then
            local rankNum = 0
            if rank and rank ~= "" then
                local _, _, num = string.find(rank, "(%d+)")
                if num then
                    rankNum = tonumber(num)
                end
            end
            
            if rankNum >= highestRank then
                highestRank = rankNum
                QuickHoP_CachedSpellIndex = i
                QuickHoP_CachedSpellTexture = GetSpellTexture(i, BOOKTYPE_SPELL)
                QuickHoP_CachedSpellRank = rank
            end
        end
        i = i + 1
    end
    
    QuickHoP_HoPSpellIndex = QuickHoP_CachedSpellIndex
end

function QuickHoP_SlashHandler(msg)
    msg = string.lower(msg)
    
    if msg == "set" or msg == "settarget" then
        QuickHoP_SetTarget()
    elseif msg == "clear" or msg == "cleartarget" then
        QuickHoP_ClearTarget()
    elseif msg == "cast" or msg == "hop" then
        QuickHoP_CastHoP()
    elseif msg == "show" then
        QuickHoP_ToggleWindow()
    elseif msg == "options" or msg == "config" or msg == "menu" then
        QuickHoP_ShowOptions()
    elseif msg == "debug" then
        QuickHoP_Debug()
    elseif msg == "help" or msg == "" then
        QuickHoP_ShowHelp()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Unknown command. Type /qhop help for help.")
    end
end

function QuickHoP_Debug()
    if QuickHoP_DebugMode then
        QuickHoP_DebugMode = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP Debug Mode: |cFFFF0000OFF|r")
    else
        QuickHoP_DebugMode = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP Debug Mode: |cFF00FF00ON|r")
        DEFAULT_CHAT_FRAME:AddMessage("You will now see all addon communication")
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP Debug Info:|r")
    DEFAULT_CHAT_FRAME:AddMessage("- Prefix: "..QuickHoP_AddonPrefix)
    DEFAULT_CHAT_FRAME:AddMessage("- Your target: "..(QuickHoP_Settings.target or "NONE"))
    DEFAULT_CHAT_FRAME:AddMessage("- In raid: "..(GetNumRaidMembers() > 0 and "YES ("..GetNumRaidMembers().." members)" or "NO"))
    DEFAULT_CHAT_FRAME:AddMessage("- In party: "..(GetNumPartyMembers() > 0 and "YES ("..GetNumPartyMembers().." members)" or "NO"))
    DEFAULT_CHAT_FRAME:AddMessage("- Known paladin targets:")
    local count = 0
    for name, target in pairs(QuickHoP_PartyData) do
        DEFAULT_CHAT_FRAME:AddMessage("  "..name.." -> "..target)
        count = count + 1
    end
    if count == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  (none - no other paladins detected)")
    end
end

function QuickHoP_ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== QuickHoP Commands ===|r")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop set - Set current target as HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop clear - Clear HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop cast - Cast HoP on saved target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop show - Toggle UI window")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop options - Open options menu")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Tip:|r Bind keys in Key Bindings > QuickHoP")
end

function QuickHoP_SetTarget()
    if UnitExists("target") and UnitIsPlayer("target") then
        QuickHoP_Settings.target = UnitName("target")
        QuickHoP_ShowFeedback(format(QuickHoP_BoPTargetSet, QuickHoP_Settings.target), 0.0, 1.0, 0.0)
        QuickHoP_UpdateUI()
        QuickHoP_BroadcastTarget()
    else
        QuickHoP_ShowFeedback(QuickHoP_NoValidTarget, 1.0, 0.0, 0.0)
    end
end

function QuickHoP_ClearTarget()
    QuickHoP_Settings.target = nil
    QuickHoP_ShowFeedback(QuickHoP_BoPTargetCleared, 1.0, 1.0, 0.0)
    QuickHoP_UpdateUI()
    QuickHoP_BroadcastTarget()
end

function QuickHoP_BroadcastTarget()
    local channel = nil
    if GetNumRaidMembers() == 0 then
        if GetNumPartyMembers() > 0 then
            channel = "PARTY"
        end
    else
        channel = "RAID"
    end
    
    if channel then
        local target = QuickHoP_Settings.target or "NONE"
        local playerName = UnitName("player")
        SendAddonMessage(QuickHoP_AddonPrefix, target, channel, playerName)
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Sent: "..QuickHoP_AddonPrefix.." -> "..target.." on "..channel.." from "..playerName, 0.5, 1, 0.5)
        end
    end
end

function QuickHoP_ReceiveTarget(sender, message)
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Received from "..sender..": "..message, 1, 0.5, 0.5)
    end
    
    if sender == UnitName("player") then
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Ignoring own message", 1, 1, 0)
        end
        return
    end
    
    if message == "NONE" then
        QuickHoP_PartyData[sender] = nil
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Cleared target for "..sender, 1, 0.5, 0)
        end
    else
        QuickHoP_PartyData[sender] = message
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Set target for "..sender.." -> "..message, 0, 1, 0)
        end
    end
    QuickHoP_UpdateOptionsUI()
end

function QuickHoP_UpdateOptionsUI()
    if QuickHoPOptionsFrame and QuickHoPOptionsFrame:IsVisible() then
        QuickHoP_RefreshPartyList()
    end
end

function QuickHoP_ShowStatus()
    if QuickHoP_Settings.target then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Current target is |cFFFFFF00"..QuickHoP_Settings.target.."|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: No target set")
    end
end

function QuickHoP_CastHoP()
    if not QuickHoP_Settings.target then
        QuickHoP_ShowFeedback(QuickHoP_BoPTargetNotSet, 1.0, 0.0, 0.0)
        return
    end
    
    if not QuickHoP_HoPSpellIndex then
        QuickHoP_ShowFeedback(QuickHoP_SpellNotFound, 1.0, 0.0, 0.0)
        return
    end
    
    local targetName = QuickHoP_Settings.target
    local originalTarget = UnitName("target")
    
    -- Simple: Just target them by name
    TargetByName(targetName, true)
    
    -- Verify we got the right target
    if not UnitExists("target") or UnitName("target") ~= targetName then
        QuickHoP_ShowFeedback(format(QuickHoP_TargetNotFound, targetName), 1.0, 0.0, 0.0)
        -- Restore original target
        if originalTarget then
            TargetByName(originalTarget, true)
        else
            ClearTarget()
        end
        return
    end
    
    -- Check if dead
    if UnitIsDead("target") then
        QuickHoP_ShowFeedback(targetName.." is dead!", 1.0, 0.0, 0.0)
        -- Restore original target
        if originalTarget then
            TargetByName(originalTarget, true)
        else
            ClearTarget()
        end
        return
    end
    
    -- Check range (30 yards for HoP)
    if not CheckInteractDistance("target", 4) then
        QuickHoP_ShowFeedback(QuickHoP_BoPTargetNotInRange, 1.0, 0.0, 0.0)
        -- Restore original target
        if originalTarget then
            TargetByName(originalTarget, true)
        else
            ClearTarget()
        end
        return
    end
    
    -- Cast the spell
    CastSpell(QuickHoP_HoPSpellIndex, BOOKTYPE_SPELL)
    QuickHoP_ShowFeedback(format(QuickHoP_BoPCastSuccess, targetName), 0.0, 1.0, 0.0)
    
    -- Restore original target
    if originalTarget and originalTarget ~= targetName then
        TargetByName(originalTarget, true)
    elseif not originalTarget then
        ClearTarget()
    end
end

function QuickHoP_ShowFeedback(msg, r, g, b)
    if QuickHoP_Settings.showfeedback then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: "..msg, r, g, b)
    end
end

function QuickHoP_ToggleWindow()
    if QuickHoPFrame:IsVisible() then
        QuickHoPFrame:Hide()
    else
        QuickHoPFrame:Show()
    end
end

function QuickHoP_FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

function QuickHoP_ShowOptions()
    if not QuickHoPOptionsFrame then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Options frame not loaded - try /reload")
        return
    end
    
    if QuickHoPOptionsFrame:IsVisible() then
        QuickHoPOptionsFrame:Hide()
    else
        QuickHoPOptionsFrame:Show()
        QuickHoP_RefreshPartyList()
    end
end

function QuickHoP_RefreshPartyList()
    for i = 1, 40 do
        local row = getglobal("QuickHoPOptionsFrameParty"..i)
        if row then
            row:Hide()
        end
    end
    
    local yOffset = -40
    local rowNum = 1
    
    local paladins = {}
    local playerName = UnitName("player")
    
    local _, playerClass = UnitClass("player")
    if playerClass == "PALADIN" then
        table.insert(paladins, {name = playerName, target = QuickHoP_Settings.target, hasAddon = true, isSelf = true})
    end
    
    local numMembers = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
    local unitPrefix = GetNumRaidMembers() > 0 and "raid" or "party"
    
    for i = 1, numMembers do
        local unit = unitPrefix..i
        if UnitExists(unit) then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            
            if class == "PALADIN" and name ~= playerName then
                local hasAddon = QuickHoP_PartyData[name] ~= nil
                local target = QuickHoP_PartyData[name]
                table.insert(paladins, {name = name, target = target, hasAddon = hasAddon, isSelf = false})
            end
        end
    end
    
    for i, paladin in ipairs(paladins) do
        local row = getglobal("QuickHoPOptionsFrameParty"..rowNum)
        if not row then
            row = CreateFrame("Frame", "QuickHoPOptionsFrameParty"..rowNum, QuickHoPOptionsFrame)
            row:SetWidth(250)
            row:SetHeight(16)
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", 5, 0)
            row.name:SetWidth(100)
            row.name:SetJustifyH("LEFT")
            
            row.target = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.target:SetPoint("LEFT", 110, 0)
            row.target:SetJustifyH("LEFT")
        end
        
        row:SetPoint("TOPLEFT", QuickHoPOptionsFrame, "TOPLEFT", 15, yOffset)
        
        if paladin.isSelf then
            row.name:SetText(paladin.name.." (you)")
            row.name:SetTextColor(1, 1, 0)
        else
            row.name:SetText(paladin.name)
            row.name:SetTextColor(1, 1, 1)
        end
        
        if paladin.hasAddon then
            if paladin.target then
                row.target:SetText("→ "..paladin.target)
                row.target:SetTextColor(0, 1, 0)
            else
                row.target:SetText("No Target")
                row.target:SetTextColor(0.5, 0.5, 0.5)
            end
        else
            row.target:SetText("(No addon)")
            row.target:SetTextColor(1, 0, 0)
        end
        
        row:Show()
        yOffset = yOffset - 18
        rowNum = rowNum + 1
    end
    
    return yOffset
end

function QuickHoP_UpdateUI()
    if not QuickHoPFrame then return end
    
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then
        QuickHoPFrame:Hide()
        return
    end
    
    if not QuickHoP_CachedSpellIndex then
        QuickHoP_ScanSpells()
    end
    
    QuickHoPFrame:SetScale(QuickHoP_Settings.scale or 1.0)
    
    local btn = getglobal("QuickHoPFrameButton")
    if not btn then return end
    
    local icon = getglobal("QuickHoPFrameButtonIcon")
    local targetText = getglobal("QuickHoPFrameButtonTargetText")
    local cooldownText = getglobal("QuickHoPFrameButtonCooldownText")
    
    local spellIndex = QuickHoP_CachedSpellIndex
    local spellTexture = QuickHoP_CachedSpellTexture
    
    if icon then
        local showIcon = QuickHoP_Settings.showIcon
        if showIcon == nil then showIcon = true end
        
        if showIcon and spellTexture then
            icon:SetTexture(spellTexture)
            icon:Show()
        else
            icon:Hide()
        end
    end
    
    if targetText then
        local showTarget = QuickHoP_Settings.showTarget
        if showTarget == nil then showTarget = true end
        
        if showTarget then
            if QuickHoP_Settings.target then
                targetText:SetText(QuickHoP_Settings.target)
                targetText:SetTextColor(0, 1, 0)
                btn:SetBackdropColor(0.0, 0.3, 0.0, 0.8)
            else
                targetText:SetText("No Target")
                targetText:SetTextColor(1, 0, 0)
                btn:SetBackdropColor(0.3, 0.0, 0.0, 0.8)
            end
            targetText:Show()
        else
            targetText:Hide()
        end
    end
    
    if cooldownText then
        local showCooldown = QuickHoP_Settings.showCooldown
        if showCooldown == nil then showCooldown = true end
        
        if showCooldown and spellIndex then
            local start, duration = GetSpellCooldown(spellIndex, BOOKTYPE_SPELL)
            
            if duration and duration > 1.5 then
                local remaining = duration - (GetTime() - start)
                if remaining > 0 then
                    cooldownText:SetText(QuickHoP_FormatTime(remaining))
                    cooldownText:SetTextColor(1, 0.5, 0)
                else
                    cooldownText:SetText("Ready")
                    cooldownText:SetTextColor(0, 1, 0)
                end
            else
                cooldownText:SetText("Ready")
                cooldownText:SetTextColor(0, 1, 0)
            end
            cooldownText:Show()
        else
            cooldownText:Hide()
        end
    end
end

function QuickHoP_Button_OnClick(button)
    if arg1 == "LeftButton" then
        if IsControlKeyDown() then
            QuickHoP_ShowOptions()
        else
            QuickHoP_CastHoP()
        end
    elseif arg1 == "RightButton" then
        if IsShiftKeyDown() then
            QuickHoPFrame:Hide()
        elseif IsAltKeyDown() then
            QuickHoP_ClearTarget()
        else
            QuickHoP_SetTarget()
        end
    end
end

function QuickHoP_Button_OnEnter()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    
    if QuickHoP_CachedSpellRank and QuickHoP_CachedSpellRank ~= "" then
        GameTooltip:SetText("Hand of Protection (" .. QuickHoP_CachedSpellRank .. ")", 1, 1, 1)
    else
        GameTooltip:SetText("Hand of Protection", 1, 1, 1)
    end
    
    GameTooltip:AddLine("Left-click: Cast HoP", 1, 1, 0)
    GameTooltip:AddLine("Right-click: Set current target", 0, 1, 0)
    GameTooltip:AddLine("Alt+Right-click: Clear target", 1, 0.8, 0)
    GameTooltip:AddLine("Shift+Right-click: Hide UI", 1, 0.5, 0)
    GameTooltip:AddLine("Ctrl+Left-click: Options", 1, 1, 1)
    
    GameTooltip:Show()
end

function QuickHoP_Button_OnLeave()
    GameTooltip:Hide()
end
