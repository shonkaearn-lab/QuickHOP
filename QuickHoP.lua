-- QuickHoP - Quick Hand of Protection targeting addon
-- Extracted from PallyPower by Relar

BINDING_HEADER_QUICKHOP = "QuickHoP"
BINDING_NAME_QUICKHOP_SET = "Set HoP Target"
BINDING_NAME_QUICKHOP_CLEAR = "Clear HoP Target"
BINDING_NAME_QUICKHOP_CAST = "Cast HoP on Target"

-- Initialize saved variables with proper defaults
if not QuickHoP_Settings then
    QuickHoP_Settings = {}
end
if QuickHoP_Settings.showfeedback == nil then QuickHoP_Settings.showfeedback = true end
if QuickHoP_Settings.scale == nil then QuickHoP_Settings.scale = 1.0 end
if QuickHoP_Settings.showCooldown == nil then QuickHoP_Settings.showCooldown = true end
if QuickHoP_Settings.showTarget == nil then QuickHoP_Settings.showTarget = true end
if QuickHoP_Settings.showIcon == nil then QuickHoP_Settings.showIcon = true end

-- Frame for event handling
local QuickHoP_Frame = CreateFrame("Frame")
local QuickHoP_HoPSpellIndex = nil
local QuickHoP_HoPCooldown = 0
local QuickHoP_PartyData = {}  -- Stores other players' targets
local QuickHoP_SyncTimer = 0
local QuickHoP_AddonPrefix = "QuickHoP"
local QuickHoP_CachedSpellIndex = nil  -- Cache the spell index
local QuickHoP_CachedSpellTexture = nil  -- Cache the spell texture
local QuickHoP_CachedSpellRank = nil  -- Cache the spell rank for tooltip

function QuickHoP_OnLoad()
    -- Register addon message prefix for party/raid communication
    RegisterAddonMessagePrefix(QuickHoP_AddonPrefix)
    
    QuickHoP_Frame:RegisterEvent("PLAYER_LOGIN")
    QuickHoP_Frame:RegisterEvent("SPELLS_CHANGED")
    QuickHoP_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    QuickHoP_Frame:RegisterEvent("CHAT_MSG_ADDON")
    QuickHoP_Frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    QuickHoP_Frame:RegisterEvent("RAID_ROSTER_UPDATE")
    QuickHoP_Frame:SetScript("OnEvent", QuickHoP_OnEvent)
    QuickHoP_Frame:SetScript("OnUpdate", QuickHoP_OnUpdate)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r version "..QuickHoP_Version.." loaded successfully!")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Use /qhop or /quickhop for commands")
end

function QuickHoP_OnUpdate(elapsed)
    if not elapsed then return end
    
    -- Broadcast our target to party/raid every 5 seconds
    QuickHoP_SyncTimer = QuickHoP_SyncTimer + elapsed
    if QuickHoP_SyncTimer >= 5 then
        QuickHoP_SyncTimer = 0
        QuickHoP_BroadcastTarget()
    end
    
    -- Update UI once per second
    QuickHoP_UIUpdateTimer = (QuickHoP_UIUpdateTimer or 0) + elapsed
    if QuickHoP_UIUpdateTimer >= 1.0 then
        QuickHoP_UIUpdateTimer = 0
        QuickHoP_UpdateUI()
    end
end

function QuickHoP_OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        QuickHoP_ScanSpells()
        QuickHoP_UpdateUI()
        QuickHoP_BroadcastTarget()
    elseif event == "CHAT_MSG_ADDON" and arg1 == QuickHoP_AddonPrefix then
        QuickHoP_ReceiveTarget(arg2, arg4)  -- arg2 = message, arg4 = sender
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        QuickHoP_BroadcastTarget()
        QuickHoP_UpdateOptionsUI()
    end
end

function QuickHoP_ScanSpells()
    -- Find Hand of Protection in spellbook - find HIGHEST rank
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
    elseif msg == "help" or msg == "" then
        QuickHoP_ShowHelp()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Unknown command. Type /qhop help for help.")
    end
end

function QuickHoP_ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== QuickHoP Commands ===|r")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop set - Set current target as HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop clear - Clear HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop cast - Cast HoP on saved target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop show - Toggle UI window")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop options - Open options menu")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Macros:|r /qhop set, /qhop clear, /qhop cast")
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
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        channel = "PARTY"
    end
    
    if channel then
        local target = QuickHoP_Settings.target or "NONE"
        SendAddonMessage(QuickHoP_AddonPrefix, target, channel)
    end
end

function QuickHoP_ReceiveTarget(message, sender)
    if message == "NONE" then
        QuickHoP_PartyData[sender] = nil
    else
        QuickHoP_PartyData[sender] = message
    end
    QuickHoP_UpdateOptionsUI()
end

function QuickHoP_UpdateOptionsUI()
    -- Update the party list in options if it's showing
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
    
    -- Find the target unit - check player, target, party, and raid
    local targetUnit = nil
    
    -- Check if it's the player
    if UnitName("player") == QuickHoP_Settings.target then
        targetUnit = "player"
    -- Check current target
    elseif UnitExists("target") and UnitName("target") == QuickHoP_Settings.target then
        targetUnit = "target"
    -- Check raid members
    elseif GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            if UnitName("raid"..i) == QuickHoP_Settings.target then
                targetUnit = "raid"..i
                break
            end
        end
    -- Check party members
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            if UnitName("party"..i) == QuickHoP_Settings.target then
                targetUnit = "party"..i
                break
            end
        end
    end
    
    if not targetUnit then
        QuickHoP_ShowFeedback(format(QuickHoP_TargetNotFound, QuickHoP_Settings.target), 1.0, 0.0, 0.0)
        return
    end
    
    -- Validate target is friendly and alive
    if not UnitIsFriend("player", targetUnit) or UnitIsDead(targetUnit) then
        QuickHoP_ShowFeedback("Target must be a friendly, living player", 1.0, 0.0, 0.0)
        return
    end
    
    -- Check range
    if not UnitIsVisible(targetUnit) or not CheckInteractDistance(targetUnit, 4) then
        QuickHoP_ShowFeedback(QuickHoP_BoPTargetNotInRange, 1.0, 0.0, 0.0)
        return
    end
    
    -- Find Hand of Protection spell - scan ALL spells to find HIGHEST rank
    local spellIndex = nil
    local highestRank = 0
    local i = 1
    while true do
        local spellName, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        if string.find(spellName, QuickHoP_BoPSpellName) then
            -- Extract rank number
            local rankNum = 0
            if rank and rank ~= "" then
                local _, _, num = string.find(rank, "(%d+)")
                if num then
                    rankNum = tonumber(num)
                end
            end
            
            -- Keep the highest rank
            if rankNum >= highestRank then
                highestRank = rankNum
                spellIndex = i
            end
        end
        i = i + 1
    end
    
    if not spellIndex then
        QuickHoP_ShowFeedback(QuickHoP_SpellNotFound, 1.0, 0.0, 0.0)
        return
    end
    
    -- Cast the spell on the target unit
    CastSpell(spellIndex, BOOKTYPE_SPELL)
    if SpellIsTargeting() then
        SpellTargetUnit(targetUnit)
    end
    QuickHoP_ShowFeedback(format(QuickHoP_BoPCastSuccess, QuickHoP_Settings.target), 0.0, 1.0, 0.0)
end

function QuickHoP_ShowFeedback(msg, r, g, b, a)
    if QuickHoP_Settings.showfeedback then
        UIErrorsFrame:AddMessage(msg, r, g, b, a or 1.0)
    end
end

function QuickHoP_ToggleWindow()
    if QuickHoPFrame:IsVisible() then
        QuickHoPFrame:Hide()
    else
        QuickHoPFrame:Show()
    end
end

function QuickHoP_FormatTime(time)
    if not time or time <= 0 then
        return "Ready"
    end
    local mins = math.floor(time / 60)
    local secs = math.floor(time - (mins * 60))
    return string.format("%d:%02d", mins, secs)
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
    -- Clear existing party list
    for i = 1, 40 do
        local row = getglobal("QuickHoPOptionsFrameParty"..i)
        if row then
            row:Hide()
        end
    end
    
    local yOffset = -40
    local rowNum = 1
    
    -- Collect all paladins in party/raid
    local paladins = {}
    local playerName = UnitName("player")
    
    -- Add self if paladin
    local _, playerClass = UnitClass("player")
    if playerClass == "PALADIN" then
        table.insert(paladins, {name = playerName, target = QuickHoP_Settings.target, hasAddon = true, isSelf = true})
    end
    
    -- Scan party/raid for other paladins
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
    
    -- Display paladins
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
    
    -- Hide UI completely if not a paladin
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then
        QuickHoPFrame:Hide()
        return
    end
    
    -- If we don't have cached spell data, scan for it
    if not QuickHoP_CachedSpellIndex then
        QuickHoP_ScanSpells()
    end
    
    -- Apply scale
    QuickHoPFrame:SetScale(QuickHoP_Settings.scale or 1.0)
    
    local btn = getglobal("QuickHoPFrameButton")
    if not btn then return end
    
    local icon = getglobal("QuickHoPFrameButtonIcon")
    local targetText = getglobal("QuickHoPFrameButtonTargetText")
    local cooldownText = getglobal("QuickHoPFrameButtonCooldownText")
    
    -- Use cached spell data instead of scanning every update
    local spellIndex = QuickHoP_CachedSpellIndex
    local spellTexture = QuickHoP_CachedSpellTexture
    
    -- Update icon
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
    
    -- Update target text
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
    
    -- Update cooldown text
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
    
    -- Use cached spell rank
    if QuickHoP_CachedSpellRank and QuickHoP_CachedSpellRank ~= "" then
        GameTooltip:SetText("Hand of Protection (" .. QuickHoP_CachedSpellRank .. ")", 1, 1, 1)
    else
        GameTooltip:SetText("Hand of Protection", 1, 1, 1)
    end
    
    GameTooltip:AddLine("Left-click: Cast HoP", 1, 1, 0)  -- Yellow
    GameTooltip:AddLine("Right-click: Set current target", 0, 1, 0)  -- Green
    GameTooltip:AddLine("Alt+Right-click: Clear target", 1, 0.8, 0)  -- Light orange
    GameTooltip:AddLine("Shift+Right-click: Hide UI", 1, 0.5, 0)  -- Orange
    GameTooltip:AddLine("Ctrl+Left-click: Options", 1, 1, 1)  -- White
    
    GameTooltip:Show()
end

function QuickHoP_Button_OnLeave()
    GameTooltip:Hide()
end
