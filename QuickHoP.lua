BINDING_HEADER_QUICKHOP = "QuickHoP"
BINDING_NAME_QUICKHOP_SET     = "Set HoP Target"
BINDING_NAME_QUICKHOP_CLEAR   = "Clear HoP Target"
BINDING_NAME_QUICKHOP_CAST    = "Cast HoP on Target"
BINDING_NAME_QUICKHOP_REQUEST = "Request HoP (Caster)"

-- ============================================================
-- SETTINGS DEFAULTS
-- ============================================================

if not QuickHoP_Settings then QuickHoP_Settings = {} end
if QuickHoP_Settings.showfeedback    == nil then QuickHoP_Settings.showfeedback    = true  end
if QuickHoP_Settings.scale           == nil then QuickHoP_Settings.scale           = 1.0   end
if QuickHoP_Settings.showCooldown    == nil then QuickHoP_Settings.showCooldown    = true  end
if QuickHoP_Settings.showTarget      == nil then QuickHoP_Settings.showTarget      = true  end
if QuickHoP_Settings.showIcon        == nil then QuickHoP_Settings.showIcon        = true  end
if QuickHoP_Settings.announceEnabled == nil then QuickHoP_Settings.announceEnabled = false end
if QuickHoP_Settings.announceChannel == nil then QuickHoP_Settings.announceChannel = "BOTH" end
if QuickHoP_Settings.announceMessage == nil then QuickHoP_Settings.announceMessage = nil   end
-- Notifications (glow removed; flash + sound + chat + icon remain)
if QuickHoP_Settings.notifyFlash     == nil then QuickHoP_Settings.notifyFlash     = true  end
if QuickHoP_Settings.notifySound     == nil then QuickHoP_Settings.notifySound     = false end
if QuickHoP_Settings.notifyChat      == nil then QuickHoP_Settings.notifyChat      = false end
if QuickHoP_Settings.notifyIcon      == nil then QuickHoP_Settings.notifyIcon      = true  end
-- Sizes
if QuickHoP_Settings.alertIconScale  == nil then QuickHoP_Settings.alertIconScale  = 1.0   end
if QuickHoP_Settings.casterScale     == nil then QuickHoP_Settings.casterScale     = 1.0   end
-- Alert icon saved position
if QuickHoP_Settings.alertIconX      == nil then QuickHoP_Settings.alertIconX      = nil   end
if QuickHoP_Settings.alertIconY      == nil then QuickHoP_Settings.alertIconY      = nil   end

-- ============================================================
-- MODULE STATE
-- ============================================================

local QuickHoP_Frame            = CreateFrame("Frame")
local QuickHoP_HoPSpellIndex    = nil
local QuickHoP_PartyData        = {}   -- [paladinName] = targetName
local QuickHoP_SyncTimer        = 0
local QuickHoP_UIUpdateTimer    = 0
local QuickHoP_AddonPrefix      = "QkHoP"
local QuickHoP_CachedSpellIndex = nil
local QuickHoP_CachedSpellTexture = nil
local QuickHoP_CachedSpellRank  = nil
QuickHoP_DebugMode              = false

-- Notification state (Paladin side)
local QuickHoP_NotifyActive  = false
local QuickHoP_NotifyTimer   = 0
local QuickHoP_FlashDir      = -1
local QuickHoP_FlashAlpha    = 0.0

-- Screen flash: four Lua-built gradient textures (no XML frame needed)
-- Each band is a 60px strip anchored to one screen edge.
-- SetGradientAlpha drives the solid→transparent fade within the band.
-- We animate the master alpha on a parent frame for the pulse.
local QuickHoP_FlashFrame    = nil   -- parent Frame (alpha animated)
local QuickHoP_FlashBuilt    = false

-- Alert icon glow state
local QuickHoP_GlowFrame     = nil   -- created lazily in Lua
local QuickHoP_GlowDir       = 1
local QuickHoP_GlowAlpha     = 0.0

-- Post-cast delayed CD broadcast
local QuickHoP_PendingCDBroadcast = false
local QuickHoP_CDBroadcastTimer  = 0

-- Caster-side cooldown
local QuickHoP_CasterCDExpiry = 0   -- GetTime() when CD ends; 0 = ready

-- ============================================================
-- CORE LOAD / EVENT / UPDATE
-- ============================================================

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

    if QuickHoP_NotifyActive then
        QuickHoP_NotifyTick(elapsed)
    end

    if QuickHoP_PendingCDBroadcast then
        QuickHoP_CDBroadcastTimer = QuickHoP_CDBroadcastTimer + elapsed
        if QuickHoP_CDBroadcastTimer >= 1.0 then
            QuickHoP_PendingCDBroadcast = false
            QuickHoP_CDBroadcastTimer   = 0
            QuickHoP_BroadcastCooldown()
        end
    end
end

function QuickHoP_OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        QuickHoP_ScanSpells()
        QuickHoP_UpdateUI()
        QuickHoP_RestoreAlertIconPosition()
        QuickHoP_UpdateCasterButton()
        QuickHoP_BroadcastTarget()
    elseif event == "CHAT_MSG_ADDON" then
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] CHAT_MSG_ADDON prefix="..tostring(arg1).." msg="..tostring(arg2).." ch="..tostring(arg3).." from="..tostring(arg4), 0.7, 0.7, 1)
        end
        if arg1 == QuickHoP_AddonPrefix and (arg3 == "PARTY" or arg3 == "RAID") then
            local msg    = arg2
            local sender = arg4
            if msg == "REQ" then
                QuickHoP_ReceiveHoPRequest(sender)
            elseif string.sub(msg, 1, 3) == "CD:" then
                QuickHoP_ReceiveCooldown(sender, string.sub(msg, 4))
            else
                QuickHoP_ReceiveTarget(sender, msg)
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        QuickHoP_BroadcastTarget()
        QuickHoP_UpdateOptionsUI()
        QuickHoP_UpdateCasterButton()
    end
end

-- ============================================================
-- SPELL SCANNING
-- ============================================================

function QuickHoP_ScanSpells()
    local highestRank = 0
    local i = 1
    QuickHoP_CachedSpellIndex   = nil
    QuickHoP_CachedSpellTexture = nil
    QuickHoP_CachedSpellRank    = nil
    while true do
        local spellName, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        if string.find(spellName, QuickHoP_BoPSpellName) then
            local rankNum = 0
            if rank and rank ~= "" then
                local _, _, num = string.find(rank, "(%d+)")
                if num then rankNum = tonumber(num) end
            end
            if rankNum >= highestRank then
                highestRank             = rankNum
                QuickHoP_CachedSpellIndex   = i
                QuickHoP_CachedSpellTexture = GetSpellTexture(i, BOOKTYPE_SPELL)
                QuickHoP_CachedSpellRank    = rank
            end
        end
        i = i + 1
    end
    QuickHoP_HoPSpellIndex = QuickHoP_CachedSpellIndex
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

function QuickHoP_SlashHandler(msg)
    msg = string.lower(msg)
    if     msg == "set" or msg == "settarget"            then QuickHoP_SetTarget()
    elseif msg == "clear" or msg == "cleartarget"        then QuickHoP_ClearTarget()
    elseif msg == "cast" or msg == "hop"                 then QuickHoP_CastHoP()
    elseif msg == "show"                                 then QuickHoP_ToggleWindow()
    elseif msg == "options" or msg == "config" or msg == "menu" then QuickHoP_ShowOptions()
    elseif msg == "debug"                                then QuickHoP_Debug()
    elseif msg == "status"                               then QuickHoP_ShowStatus()
    elseif msg == "request" or msg == "req"              then QuickHoP_SendHoPRequest()
    elseif msg == "help" or msg == ""                    then QuickHoP_ShowHelp()
    else DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Unknown command. Type /qhop help for help.")
    end
end

function QuickHoP_HopRequestSlashHandler(msg)
    QuickHoP_SendHoPRequest()
end

function QuickHoP_Debug()
    if QuickHoP_DebugMode then
        QuickHoP_DebugMode = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP Debug Mode: |cFFFF0000OFF|r")
    else
        QuickHoP_DebugMode = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP Debug Mode: |cFF00FF00ON|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage("- Prefix: "..QuickHoP_AddonPrefix)
    DEFAULT_CHAT_FRAME:AddMessage("- Your target: "..(QuickHoP_Settings.target or "NONE"))
    DEFAULT_CHAT_FRAME:AddMessage("- In raid: "..(GetNumRaidMembers() > 0 and "YES" or "NO"))
    DEFAULT_CHAT_FRAME:AddMessage("- In party: "..(GetNumPartyMembers() > 0 and "YES" or "NO"))
    DEFAULT_CHAT_FRAME:AddMessage("- Known paladin targets:")
    local count = 0
    for name, target in pairs(QuickHoP_PartyData) do
        DEFAULT_CHAT_FRAME:AddMessage("  "..name.." -> "..target)
        count = count + 1
    end
    if count == 0 then DEFAULT_CHAT_FRAME:AddMessage("  (none)") end
end

function QuickHoP_ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== QuickHoP Commands ===|r")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop set - Set current target as HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop clear - Clear HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop cast - Cast HoP on saved target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop show - Toggle UI window")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop status - Show current HoP target")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop options - Open options menu")
    DEFAULT_CHAT_FRAME:AddMessage("/qhop request  OR  /hoprequest - Request HoP (casters)")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Tip:|r Bind keys in Key Bindings > QuickHoP")
end

-- ============================================================
-- TARGET MANAGEMENT
-- ============================================================

function QuickHoP_SetTarget()
    if UnitExists("target") and UnitIsPlayer("target") then
        QuickHoP_Settings.target = UnitName("target")
        QuickHoP_ShowFeedback(format(QuickHoP_BoPTargetSet, QuickHoP_Settings.target), 0, 1, 0)
        QuickHoP_UpdateUI()
        QuickHoP_BroadcastTarget()
    else
        QuickHoP_ShowFeedback(QuickHoP_NoValidTarget, 1, 0, 0)
    end
end

function QuickHoP_ClearTarget()
    QuickHoP_Settings.target = nil
    QuickHoP_ShowFeedback(QuickHoP_BoPTargetCleared, 1, 1, 0)
    QuickHoP_UpdateUI()
    QuickHoP_BroadcastTarget()
end

function QuickHoP_ShowStatus()
    if QuickHoP_Settings.target then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Current target is |cFFFFFF00"..QuickHoP_Settings.target.."|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: No target set")
    end
end

-- ============================================================
-- CHANNEL / BROADCAST / RECEIVE
-- ============================================================

function QuickHoP_GetChannel()
    if GetNumRaidMembers() > 0  then return "RAID"  end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
end

function QuickHoP_BroadcastTarget()
    local channel = QuickHoP_GetChannel()
    if not channel then return end
    local target = QuickHoP_Settings.target or "NONE"
    SendAddonMessage(QuickHoP_AddonPrefix, target, channel)
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Sent target: "..target.." on "..channel, 0.5, 1, 0.5)
    end
end

-- 1 second after cast: read real CD and broadcast to caster
function QuickHoP_BroadcastCooldown()
    if not QuickHoP_HoPSpellIndex then return end
    local channel = QuickHoP_GetChannel()
    if not channel then return end
    local start, duration = GetSpellCooldown(QuickHoP_HoPSpellIndex, BOOKTYPE_SPELL)
    local remaining = 0
    if duration and duration > 1.5 then
        remaining = duration - (GetTime() - start)
        if remaining < 0 then remaining = 0 end
    end
    SendAddonMessage(QuickHoP_AddonPrefix, "CD:"..math.floor(remaining), channel)
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Broadcast CD: "..math.floor(remaining).."s", 0.5, 1, 1)
    end
end

function QuickHoP_ReceiveTarget(sender, message)
    if sender == UnitName("player") then return end
    if message == "NONE" then
        QuickHoP_PartyData[sender] = nil
    else
        QuickHoP_PartyData[sender] = message
    end
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] PartyData["..sender.."] = "..(QuickHoP_PartyData[sender] or "nil"), 0, 1, 0)
    end
    QuickHoP_UpdateOptionsUI()
    -- A Paladin's target data just changed; re-check caster button visibility
    QuickHoP_UpdateCasterButton()
end

function QuickHoP_ReceiveCooldown(sender, cdStr)
    local cd = tonumber(cdStr) or 0
    QuickHoP_CasterCDExpiry = (cd > 0) and (GetTime() + cd) or 0
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] CD from "..sender..": "..cd.."s", 0.5, 1, 1)
    end
end

-- ============================================================
-- CASTER BUTTON VISIBILITY
-- Show only if at least one Paladin in the group has saved
-- THIS player as their HoP target.
-- ============================================================

function QuickHoP_UpdateCasterButton()
    local f = QuickHoPRequestFrame
    if not f then return end

    local _, playerClass = UnitClass("player")
    if playerClass == "PALADIN" then
        f:Hide()
        return
    end

    local myName = UnitName("player")
    local assigned = false
    for paladinName, targetName in pairs(QuickHoP_PartyData) do
        if targetName == myName then
            assigned = true
            break
        end
    end

    if assigned then
        f:SetScale(QuickHoP_Settings.casterScale or 1.0)
        f:Show()
    else
        f:Hide()
    end
end

-- ============================================================
-- HOP REQUEST — CASTER SIDE
-- ============================================================

function QuickHoP_SendHoPRequest()
    local _, playerClass = UnitClass("player")
    if playerClass == "PALADIN" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: You're a Paladin — cast it yourself!")
        return
    end
    local channel = QuickHoP_GetChannel()
    if not channel then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: Not in a party or raid.")
        return
    end
    SendAddonMessage(QuickHoP_AddonPrefix, "REQ", channel)
    QuickHoP_ShowFeedback(QuickHoP_HoPRequestSent, 0.5, 0.8, 1.0)
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] Sent HoP REQ on "..channel, 0.5, 1, 1)
    end
end

-- ============================================================
-- HOP REQUEST — PALADIN SIDE (receive + notify)
-- ============================================================

function QuickHoP_ReceiveHoPRequest(sender)
    if QuickHoP_DebugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] HoP REQ from "..sender, 1, 0.5, 1)
    end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then return end
    if QuickHoP_Settings.target ~= sender then
        if QuickHoP_DebugMode then
            DEFAULT_CHAT_FRAME:AddMessage("[QHoP DEBUG] REQ ignored — not our target", 1, 1, 0)
        end
        return
    end
    QuickHoP_TriggerNotifications(sender)
end

function QuickHoP_TriggerNotifications(senderName)
    QuickHoP_NotifyActive = true
    QuickHoP_NotifyTimer  = 5.0

    if QuickHoP_Settings.notifyChat then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF9900QuickHoP|r: "..format(QuickHoP_HoPRequestReceived, "|cFFFFFF00"..senderName.."|r"), 1, 0.6, 0)
    end
    if QuickHoP_Settings.notifySound then
        PlaySound(8959)
    end
    if QuickHoP_Settings.notifyFlash then
        QuickHoP_StartScreenFlash()
    end
    if QuickHoP_Settings.notifyIcon then
        QuickHoP_ShowAlertIcon()
    end
end

function QuickHoP_DismissNotification()
    if not QuickHoP_NotifyActive then return end
    QuickHoP_NotifyActive = false
    QuickHoP_NotifyTimer  = 0
    QuickHoP_StopScreenFlash()
    QuickHoP_HideAlertIcon()
end

function QuickHoP_NotifyTick(elapsed)
    QuickHoP_NotifyTimer = QuickHoP_NotifyTimer - elapsed
    if QuickHoP_NotifyTimer <= 0 then
        QuickHoP_DismissNotification()
        return
    end
    if QuickHoP_Settings.notifyFlash then QuickHoP_TickScreenFlash(elapsed) end
    if QuickHoP_Settings.notifyIcon  then QuickHoP_TickAlertIconGlow(elapsed) end
end

-- ============================================================
-- SCREEN FLASH
--
-- Fully Lua-built — no XML frame at all.
-- Four textures, one per screen edge, each using SetGradientAlpha:
--   solid blue at the edge → fully transparent inward over ~60px.
--
-- SetGradientAlpha(orientation, r1,g1,b1,a1, r2,g2,b2,a2)
--   is the 1.12 API (pre-SetGradient refactor).
--   VERTICAL:    (r1,g1,b1,a1) = BOTTOM colour, (r2...) = TOP colour
--   HORIZONTAL:  (r1...) = LEFT colour, (r2...) = RIGHT colour
--
-- We pulse the MASTER alpha on a transparent parent frame;
-- child textures inherit it cleanly.
-- ============================================================

local FLASH_DEPTH = 80   -- pixel depth of each band (approx 2cm at 1080p ~96dpi)
local FLASH_R, FLASH_G, FLASH_B = 0.1, 0.3, 1.0  -- blue

local function QuickHoP_BuildFlash()
    if QuickHoP_FlashBuilt then return end
    QuickHoP_FlashBuilt = true

    local f = CreateFrame("Frame", "QuickHoPFlashParent", UIParent)
    f:SetFrameStrata("FULLSCREEN")
    f:SetAllPoints(UIParent)    -- fill entire screen (just the parent; children do the drawing)
    f:SetAlpha(0)
    f:Hide()
    QuickHoP_FlashFrame = f

    -- TOP band: solid at top, fades to transparent downward
    -- VERTICAL MinColor = BOTTOM of texture = transparent end
    --          MaxColor = TOP of texture    = opaque end
    local top = f:CreateTexture(nil, "BACKGROUND")
    top:SetTexture("Interface\\Buttons\\WHITE8x8")
    top:SetPoint("TOPLEFT",  UIParent, "TOPLEFT",  0,  0)
    top:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0,  0)
    top:SetHeight(FLASH_DEPTH)
    -- VERTICAL: bottom=transparent, top=opaque
    top:SetGradientAlpha("VERTICAL",
        FLASH_R, FLASH_G, FLASH_B, 0.0,   -- bottom of this strip = transparent
        FLASH_R, FLASH_G, FLASH_B, 1.0)   -- top of this strip = opaque

    -- BOTTOM band: solid at bottom, fades to transparent upward
    local bot = f:CreateTexture(nil, "BACKGROUND")
    bot:SetTexture("Interface\\Buttons\\WHITE8x8")
    bot:SetPoint("BOTTOMLEFT",  UIParent, "BOTTOMLEFT",  0, 0)
    bot:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    bot:SetHeight(FLASH_DEPTH)
    -- VERTICAL: bottom=opaque, top=transparent
    bot:SetGradientAlpha("VERTICAL",
        FLASH_R, FLASH_G, FLASH_B, 1.0,   -- bottom = opaque
        FLASH_R, FLASH_G, FLASH_B, 0.0)   -- top = transparent

    -- LEFT band: solid at left, fades to transparent rightward
    local lft = f:CreateTexture(nil, "BACKGROUND")
    lft:SetTexture("Interface\\Buttons\\WHITE8x8")
    lft:SetPoint("TOPLEFT",    UIParent, "TOPLEFT",    0, 0)
    lft:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    lft:SetWidth(FLASH_DEPTH)
    -- HORIZONTAL: left=opaque, right=transparent
    lft:SetGradientAlpha("HORIZONTAL",
        FLASH_R, FLASH_G, FLASH_B, 1.0,   -- left = opaque
        FLASH_R, FLASH_G, FLASH_B, 0.0)   -- right = transparent

    -- RIGHT band: solid at right, fades to transparent leftward
    local rgt = f:CreateTexture(nil, "BACKGROUND")
    rgt:SetTexture("Interface\\Buttons\\WHITE8x8")
    rgt:SetPoint("TOPRIGHT",    UIParent, "TOPRIGHT",    0, 0)
    rgt:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    rgt:SetWidth(FLASH_DEPTH)
    -- HORIZONTAL: left=transparent, right=opaque
    rgt:SetGradientAlpha("HORIZONTAL",
        FLASH_R, FLASH_G, FLASH_B, 0.0,   -- left = transparent
        FLASH_R, FLASH_G, FLASH_B, 1.0)   -- right = opaque
end

function QuickHoP_StartScreenFlash()
    QuickHoP_BuildFlash()
    local f = QuickHoP_FlashFrame
    if not f then return end
    QuickHoP_FlashAlpha = 0.9
    QuickHoP_FlashDir   = -1
    f:SetAlpha(QuickHoP_FlashAlpha)
    f:Show()
end

function QuickHoP_StopScreenFlash()
    local f = QuickHoP_FlashFrame
    if not f then return end
    f:Hide()
    f:SetAlpha(0)
    QuickHoP_FlashAlpha = 0
end

function QuickHoP_TickScreenFlash(elapsed)
    local f = QuickHoP_FlashFrame
    if not f or not f:IsVisible() then return end
    -- Pulse between 0.2 and 0.9; full cycle ~1s
    QuickHoP_FlashAlpha = QuickHoP_FlashAlpha + (QuickHoP_FlashDir * elapsed * 1.4)
    if QuickHoP_FlashAlpha <= 0.2 then
        QuickHoP_FlashAlpha = 0.2
        QuickHoP_FlashDir   = 1
    elseif QuickHoP_FlashAlpha >= 0.9 then
        QuickHoP_FlashAlpha = 0.9
        QuickHoP_FlashDir   = -1
    end
    f:SetAlpha(QuickHoP_FlashAlpha)
end

-- ============================================================
-- CENTER ALERT ICON
-- ============================================================

function QuickHoP_ShowAlertIcon()
    local f = QuickHoPAlertIcon
    if not f then return end

    -- Set scale
    f:SetScale(QuickHoP_Settings.alertIconScale or 1.0)

    -- Restore saved position or center
    f:ClearAllPoints()
    if QuickHoP_Settings.alertIconX and QuickHoP_Settings.alertIconY then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            QuickHoP_Settings.alertIconX, QuickHoP_Settings.alertIconY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Reset glow state
    QuickHoP_GlowAlpha = 0.3
    QuickHoP_GlowDir   = 1

    -- Ensure glow frame exists and is configured
    QuickHoP_EnsureGlowFrame(f)

    f:SetAlpha(1.0)
    f:Show()
end

function QuickHoP_HideAlertIcon()
    local f = QuickHoPAlertIcon
    if not f then return end
    f:Hide()
    if QuickHoP_GlowFrame then QuickHoP_GlowFrame:Hide() end
end

function QuickHoP_RestoreAlertIconPosition()
    local f = QuickHoPAlertIcon
    if not f then return end
    if QuickHoP_Settings.alertIconX and QuickHoP_Settings.alertIconY then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            QuickHoP_Settings.alertIconX, QuickHoP_Settings.alertIconY)
    end
end

-- Creates the glow border frame lazily (once), parented to the alert icon.
-- Uses SetBackdropBorderColor for a clean coloured border pulse.
function QuickHoP_EnsureGlowFrame(parent)
    if QuickHoP_GlowFrame then
        QuickHoP_GlowFrame:Show()
        return
    end
    local g = CreateFrame("Frame", "QuickHoPGlowBorder", parent)
    g:SetWidth(80)
    g:SetHeight(80)
    g:SetPoint("CENTER", parent, "CENTER", 0, 0)
    g:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = {left = 0, right = 0, top = 0, bottom = 0},
    })
    g:SetBackdropBorderColor(0.5, 0.8, 1.0, 0.3)
    g:SetFrameLevel(parent:GetFrameLevel() + 2)
    QuickHoP_GlowFrame = g
end

-- Pulse the glow border alpha by animating its border colour's alpha channel
function QuickHoP_TickAlertIconGlow(elapsed)
    if not QuickHoP_GlowFrame or not QuickHoP_GlowFrame:IsVisible() then return end
    -- Pulse between 0.15 and 1.0; speed ~2 cycles/sec
    QuickHoP_GlowAlpha = QuickHoP_GlowAlpha + (QuickHoP_GlowDir * elapsed * 2.5)
    if QuickHoP_GlowAlpha >= 1.0 then
        QuickHoP_GlowAlpha = 1.0
        QuickHoP_GlowDir   = -1
    elseif QuickHoP_GlowAlpha <= 0.15 then
        QuickHoP_GlowAlpha = 0.15
        QuickHoP_GlowDir   = 1
    end
    QuickHoP_GlowFrame:SetBackdropBorderColor(0.5, 0.8, 1.0, QuickHoP_GlowAlpha)
end

function QuickHoP_AlertIcon_OnDragStop()
    local f = QuickHoPAlertIcon
    if not f then return end
    f:StopMovingOrSizing()
    local x, y = f:GetCenter()
    QuickHoP_Settings.alertIconX = x
    QuickHoP_Settings.alertIconY = y
end

-- ============================================================
-- CASTER BUTTON HANDLERS
-- ============================================================

function QuickHoP_RequestButton_OnClick()
    if arg1 == "LeftButton" and IsControlKeyDown() then
        QuickHoP_ShowOptions()
    else
        QuickHoP_SendHoPRequest()
    end
end

function QuickHoP_RequestButton_OnEnter()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Hand of Protection", 1, 1, 1)
    GameTooltip:AddLine("Click to request HoP from your Paladin", 1, 1, 0)
    GameTooltip:AddLine("Ctrl+Click: Options", 1, 1, 1)
    GameTooltip:AddLine("Keybind: Key Bindings > QuickHoP", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function QuickHoP_RequestButton_OnLeave()
    GameTooltip:Hide()
end

-- OnUpdate for caster button: drives cooldown text
function QuickHoP_RequestFrame_OnUpdate(elapsed)
    if not elapsed then return end
    local cdText = getglobal("QuickHoPRequestFrameCooldownText")
    if not cdText then return end
    if QuickHoP_CasterCDExpiry > 0 then
        local remaining = QuickHoP_CasterCDExpiry - GetTime()
        if remaining > 0 then
            cdText:SetText(QuickHoP_FormatTime(remaining))
            cdText:SetTextColor(1, 0.5, 0)
        else
            QuickHoP_CasterCDExpiry = 0
            cdText:SetText("Ready")
            cdText:SetTextColor(0, 1, 0)
        end
    else
        cdText:SetText("Ready")
        cdText:SetTextColor(0, 1, 0)
    end
end

-- ============================================================
-- CASTING
-- ============================================================

function QuickHoP_CastHoP()
    if not QuickHoP_Settings.target then
        QuickHoP_ShowFeedback(QuickHoP_BoPTargetNotSet, 1, 0, 0)
        return
    end
    if not QuickHoP_HoPSpellIndex then
        QuickHoP_ShowFeedback(QuickHoP_SpellNotFound, 1, 0, 0)
        return
    end

    local targetName     = QuickHoP_Settings.target
    local originalTarget = UnitName("target")

    TargetByName(targetName, true)

    if not UnitExists("target") or UnitName("target") ~= targetName then
        QuickHoP_ShowFeedback(format(QuickHoP_TargetNotFound, targetName), 1, 0, 0)
        if originalTarget then TargetByName(originalTarget, true) else ClearTarget() end
        return
    end
    if UnitIsDead("target") then
        QuickHoP_ShowFeedback(targetName.." is dead!", 1, 0, 0)
        if originalTarget then TargetByName(originalTarget, true) else ClearTarget() end
        return
    end
    if not CheckInteractDistance("target", 4) then
        QuickHoP_ShowFeedback(QuickHoP_BoPTargetNotInRange, 1, 0, 0)
        if originalTarget then TargetByName(originalTarget, true) else ClearTarget() end
        return
    end

    local startBefore, durationBefore = GetSpellCooldown(QuickHoP_HoPSpellIndex, BOOKTYPE_SPELL)
    CastSpell(QuickHoP_HoPSpellIndex, BOOKTYPE_SPELL)
    local startAfter, durationAfter = GetSpellCooldown(QuickHoP_HoPSpellIndex, BOOKTYPE_SPELL)
    local fired = durationAfter and durationAfter > (durationBefore or 0) + 0.5

    if fired then
        QuickHoP_ShowFeedback(format(QuickHoP_BoPCastSuccess, targetName), 0, 1, 0)
        QuickHoP_Announce(targetName)
        QuickHoP_DismissNotification()
        QuickHoP_PendingCDBroadcast = true
        QuickHoP_CDBroadcastTimer   = 0
    end

    if originalTarget and originalTarget ~= targetName then
        TargetByName(originalTarget, true)
    elseif not originalTarget then
        ClearTarget()
    end
end

-- ============================================================
-- FEEDBACK / ANNOUNCE
-- ============================================================

function QuickHoP_ShowFeedback(msg, r, g, b)
    if QuickHoP_Settings.showfeedback then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00QuickHoP|r: "..msg, r, g, b)
    end
end

function QuickHoP_Announce(targetName)
    if not QuickHoP_Settings.announceEnabled then return end
    local msg = QuickHoP_Settings.announceMessage
    if not msg or msg == "" then msg = QuickHoP_DefaultAnnounceMsg end
    msg = string.gsub(msg, "<n>", targetName)
    local ch      = QuickHoP_Settings.announceChannel or "BOTH"
    local inRaid  = GetNumRaidMembers() > 0
    local inParty = GetNumPartyMembers() > 0
    if ch == "BOTH" then
        if inRaid then SendChatMessage(msg, "RAID") elseif inParty then SendChatMessage(msg, "PARTY") end
    elseif ch == "RAID" then
        if inRaid then SendChatMessage(msg, "RAID") elseif inParty then SendChatMessage(msg, "PARTY") end
    elseif ch == "PARTY" then
        if inParty then SendChatMessage(msg, "PARTY") end
    end
end

-- ============================================================
-- UTILITIES
-- ============================================================

function QuickHoP_ToggleWindow()
    if QuickHoPFrame:IsVisible() then QuickHoPFrame:Hide() else QuickHoPFrame:Show() end
end

function QuickHoP_FormatTime(seconds)
    if seconds >= 60 then return string.format("%dm", math.floor(seconds / 60))
    else return string.format("%ds", math.floor(seconds)) end
end

-- ============================================================
-- OPTIONS PANEL
-- ============================================================

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

function QuickHoP_UpdateOptionsUI()
    if QuickHoPOptionsFrame and QuickHoPOptionsFrame:IsVisible() then
        QuickHoP_RefreshPartyList()
    end
end

function QuickHoP_RefreshPartyList()
    local f = QuickHoPOptionsFrame
    if not f then return end

    local W       = 280
    local PAD     = 15
    local ROW_H   = 18
    local SEC_GAP = 10
    local y       = -30

    -- Paladin assignment list
    local paladins   = {}
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
                table.insert(paladins, {
                    name     = name,
                    target   = QuickHoP_PartyData[name],
                    hasAddon = QuickHoP_PartyData[name] ~= nil,
                    isSelf   = false,
                })
            end
        end
    end

    -- Title
    if not f.sectionTitle then
        f.sectionTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.sectionTitle:SetText("QuickHoP Options")
    end
    f.sectionTitle:ClearAllPoints()
    f.sectionTitle:SetPoint("TOP", f, "TOP", 0, -10)

    -- HoP Assignments
    if not f.assignHeader then
        f.assignHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.assignHeader:SetText("HoP Assignments")
    end
    f.assignHeader:ClearAllPoints()
    f.assignHeader:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 8

    for i = 1, 40 do
        local row = getglobal("QuickHoPOptionsFrameParty"..i)
        if row then row:Hide() end
    end
    for idx, paladin in ipairs(paladins) do
        local row = getglobal("QuickHoPOptionsFrameParty"..idx)
        if not row then
            row = CreateFrame("Frame", "QuickHoPOptionsFrameParty"..idx, f)
            row:SetHeight(ROW_H)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.name:SetWidth(110)
            row.name:SetJustifyH("LEFT")
            row.target = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.target:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.target:SetJustifyH("RIGHT")
        end
        row:SetWidth(W - PAD * 2)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
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
        y = y - ROW_H
    end

    y = y - SEC_GAP

    -- ---- Divider 1 ----
    if not f.divider1 then
        f.divider1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.divider1:SetText("────────────────────────")
    end
    f.divider1:ClearAllPoints()
    f.divider1:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 16

    -- ---- Paladin UI Scale ----
    if not f.scaleLabel then
        f.scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.scaleLabel:SetText("Paladin UI Scale:")
    end
    f.scaleLabel:ClearAllPoints()
    f.scaleLabel:SetPoint("TOP", f, "TOP", 0, y + 6)
    y = y - 14
    if not f.scaleSlider then
        f.scaleSlider = CreateFrame("Slider", "QuickHoPOptionsScaleSlider", f, "OptionsSliderTemplate")
        f.scaleSlider:SetMinMaxValues(0.5, 2.0)
        f.scaleSlider:SetValueStep(0.1)
        f.scaleSlider:SetWidth(W - PAD * 4)
        f.scaleSlider:SetHeight(17)
        getglobal("QuickHoPOptionsScaleSliderLow"):SetText("0.5")
        getglobal("QuickHoPOptionsScaleSliderHigh"):SetText("2.0")
        f.scaleSlider:SetScript("OnValueChanged", function()
            QuickHoP_Settings.scale = f.scaleSlider:GetValue()
            getglobal("QuickHoPOptionsScaleSliderText"):SetText(string.format("%.1f", QuickHoP_Settings.scale))
            QuickHoP_UpdateUI()
        end)
    end
    f.scaleSlider:SetValue(QuickHoP_Settings.scale or 1.0)
    getglobal("QuickHoPOptionsScaleSliderText"):SetText(string.format("%.1f", QuickHoP_Settings.scale or 1.0))
    f.scaleSlider:ClearAllPoints()
    f.scaleSlider:SetPoint("TOP", f, "TOP", 0, y)
    y = y - 22

    -- ---- Alert Icon Scale ----
    if not f.alertScaleLabel then
        f.alertScaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.alertScaleLabel:SetText("Alert Icon Size:")
    end
    f.alertScaleLabel:ClearAllPoints()
    f.alertScaleLabel:SetPoint("TOP", f, "TOP", 0, y + 6)
    y = y - 14
    if not f.alertScaleSlider then
        f.alertScaleSlider = CreateFrame("Slider", "QuickHoPAlertScaleSlider", f, "OptionsSliderTemplate")
        f.alertScaleSlider:SetMinMaxValues(0.5, 3.0)
        f.alertScaleSlider:SetValueStep(0.1)
        f.alertScaleSlider:SetWidth(W - PAD * 4)
        f.alertScaleSlider:SetHeight(17)
        getglobal("QuickHoPAlertScaleSliderLow"):SetText("0.5")
        getglobal("QuickHoPAlertScaleSliderHigh"):SetText("3.0")
        f.alertScaleSlider:SetScript("OnValueChanged", function()
            QuickHoP_Settings.alertIconScale = f.alertScaleSlider:GetValue()
            getglobal("QuickHoPAlertScaleSliderText"):SetText(string.format("%.1f", QuickHoP_Settings.alertIconScale))
            if QuickHoPAlertIcon then
                QuickHoPAlertIcon:SetScale(QuickHoP_Settings.alertIconScale)
            end
        end)
    end
    f.alertScaleSlider:SetValue(QuickHoP_Settings.alertIconScale or 1.0)
    getglobal("QuickHoPAlertScaleSliderText"):SetText(string.format("%.1f", QuickHoP_Settings.alertIconScale or 1.0))
    f.alertScaleSlider:ClearAllPoints()
    f.alertScaleSlider:SetPoint("TOP", f, "TOP", 0, y)
    y = y - 22

    -- ---- Caster Button Scale ----
    if not f.casterScaleLabel then
        f.casterScaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.casterScaleLabel:SetText("Caster Button Size:")
    end
    f.casterScaleLabel:ClearAllPoints()
    f.casterScaleLabel:SetPoint("TOP", f, "TOP", 0, y + 6)
    y = y - 14
    if not f.casterScaleSlider then
        f.casterScaleSlider = CreateFrame("Slider", "QuickHoPCasterScaleSlider", f, "OptionsSliderTemplate")
        f.casterScaleSlider:SetMinMaxValues(0.5, 2.0)
        f.casterScaleSlider:SetValueStep(0.1)
        f.casterScaleSlider:SetWidth(W - PAD * 4)
        f.casterScaleSlider:SetHeight(17)
        getglobal("QuickHoPCasterScaleSliderLow"):SetText("0.5")
        getglobal("QuickHoPCasterScaleSliderHigh"):SetText("2.0")
        f.casterScaleSlider:SetScript("OnValueChanged", function()
            QuickHoP_Settings.casterScale = f.casterScaleSlider:GetValue()
            getglobal("QuickHoPCasterScaleSliderText"):SetText(string.format("%.1f", QuickHoP_Settings.casterScale))
            if QuickHoPRequestFrame and QuickHoPRequestFrame:IsVisible() then
                QuickHoPRequestFrame:SetScale(QuickHoP_Settings.casterScale)
            end
        end)
    end
    f.casterScaleSlider:SetValue(QuickHoP_Settings.casterScale or 1.0)
    getglobal("QuickHoPCasterScaleSliderText"):SetText(string.format("%.1f", QuickHoP_Settings.casterScale or 1.0))
    f.casterScaleSlider:ClearAllPoints()
    f.casterScaleSlider:SetPoint("TOP", f, "TOP", 0, y)
    y = y - 22

    y = y - SEC_GAP

    -- ---- Divider 2 ----
    if not f.divider2 then
        f.divider2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.divider2:SetText("────────────────────────")
    end
    f.divider2:ClearAllPoints()
    f.divider2:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 16

    -- ---- Macros ----
    if not f.macroHeader then
        f.macroHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.macroHeader:SetText("Macros:")
    end
    f.macroHeader:ClearAllPoints()
    f.macroHeader:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 18
    local macros = {
        {cmd = "/qhop set",   desc = "Save current target"},
        {cmd = "/qhop cast",  desc = "Cast HoP on saved target"},
        {cmd = "/qhop clear", desc = "Clear saved target"},
        {cmd = "/hoprequest", desc = "Request HoP (casters)"},
    }
    for _, m in ipairs(macros) do
        local key = "macro_"..m.cmd
        if not f[key] then
            local cmdStr  = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local descStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            descStr:SetTextColor(0.7, 0.7, 0.7)
            f[key] = cmdStr
            f["macrodesc_"..m.cmd] = descStr
        end
        f[key]:SetText(m.cmd)
        f["macrodesc_"..m.cmd]:SetText(m.desc)
        f[key]:ClearAllPoints()
        f[key]:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
        f["macrodesc_"..m.cmd]:ClearAllPoints()
        f["macrodesc_"..m.cmd]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
        y = y - 15
    end

    y = y - SEC_GAP

    -- ---- Divider 3 ----
    if not f.divider3 then
        f.divider3 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.divider3:SetText("────────────────────────")
    end
    f.divider3:ClearAllPoints()
    f.divider3:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 16

    -- ---- Announce HoP ----
    if not f.announceHeader then
        f.announceHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.announceHeader:SetText("Announce HoP:")
    end
    f.announceHeader:ClearAllPoints()
    f.announceHeader:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    if not f.announceCheck then
        f.announceCheck = CreateFrame("CheckButton", "QuickHoPAnnounceCheck", f, "UICheckButtonTemplate")
        f.announceCheck:SetWidth(20)
        f.announceCheck:SetHeight(20)
        f.announceCheck:SetScript("OnClick", function()
            QuickHoP_Settings.announceEnabled = f.announceCheck:GetChecked() == 1
            QuickHoP_UpdateAnnounceUI()
        end)
    end
    f.announceCheck:ClearAllPoints()
    f.announceCheck:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD + 2, y + 2)
    f.announceCheck:SetChecked(QuickHoP_Settings.announceEnabled and 1 or 0)
    y = y - 22

    if not f.announceChannelLabel then
        f.announceChannelLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.announceChannelLabel:SetText("Channel:")
    end
    f.announceChannelLabel:ClearAllPoints()
    f.announceChannelLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)

    if not f.announceChanBoth then
        f.announceChanBoth = CreateFrame("CheckButton", "QuickHoPChanBoth", f, "UICheckButtonTemplate")
        f.announceChanBoth:SetWidth(16)
        f.announceChanBoth:SetHeight(16)
        local lbl = f.announceChanBoth:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetText("Both")
        lbl:SetPoint("LEFT", f.announceChanBoth, "RIGHT", 1, 0)
        f.announceChanBoth.label = lbl
        f.announceChanBoth:SetScript("OnClick", function()
            QuickHoP_Settings.announceChannel = "BOTH"
            f.announceChanBoth:SetChecked(1)
            f.announceChanRaid:SetChecked(0)
            f.announceChanParty:SetChecked(0)
        end)
        f.announceChanRaid = CreateFrame("CheckButton", "QuickHoPChanRaid", f, "UICheckButtonTemplate")
        f.announceChanRaid:SetWidth(16)
        f.announceChanRaid:SetHeight(16)
        local lbl2 = f.announceChanRaid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl2:SetText("Raid")
        lbl2:SetPoint("LEFT", f.announceChanRaid, "RIGHT", 1, 0)
        f.announceChanRaid.label = lbl2
        f.announceChanRaid:SetScript("OnClick", function()
            QuickHoP_Settings.announceChannel = "RAID"
            f.announceChanBoth:SetChecked(0)
            f.announceChanRaid:SetChecked(1)
            f.announceChanParty:SetChecked(0)
        end)
        f.announceChanParty = CreateFrame("CheckButton", "QuickHoPChanParty", f, "UICheckButtonTemplate")
        f.announceChanParty:SetWidth(16)
        f.announceChanParty:SetHeight(16)
        local lbl3 = f.announceChanParty:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl3:SetText("Party")
        lbl3:SetPoint("LEFT", f.announceChanParty, "RIGHT", 1, 0)
        f.announceChanParty.label = lbl3
        f.announceChanParty:SetScript("OnClick", function()
            QuickHoP_Settings.announceChannel = "PARTY"
            f.announceChanBoth:SetChecked(0)
            f.announceChanRaid:SetChecked(0)
            f.announceChanParty:SetChecked(1)
        end)
    end
    local ch = QuickHoP_Settings.announceChannel or "BOTH"
    f.announceChanBoth:SetChecked(ch == "BOTH" and 1 or 0)
    f.announceChanRaid:SetChecked(ch == "RAID" and 1 or 0)
    f.announceChanParty:SetChecked(ch == "PARTY" and 1 or 0)
    f.announceChanBoth:ClearAllPoints()
    f.announceChanBoth:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 52, y + 4)
    f.announceChanRaid:ClearAllPoints()
    f.announceChanRaid:SetPoint("LEFT", f.announceChanBoth.label, "RIGHT", 10, 0)
    f.announceChanParty:ClearAllPoints()
    f.announceChanParty:SetPoint("LEFT", f.announceChanRaid.label, "RIGHT", 10, 0)
    y = y - 22

    if not f.announceMsgLabel then
        f.announceMsgLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.announceMsgLabel:SetText("Message (<n> = target name):")
    end
    f.announceMsgLabel:ClearAllPoints()
    f.announceMsgLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
    y = y - 18

    if not f.announceMsgBox then
        f.announceMsgBox = CreateFrame("EditBox", "QuickHoPAnnounceMsgBox", f, "InputBoxTemplate")
        f.announceMsgBox:SetWidth(W - PAD * 2 - 8)
        f.announceMsgBox:SetHeight(20)
        f.announceMsgBox:SetAutoFocus(false)
        f.announceMsgBox:SetMaxLetters(128)
        f.announceMsgBox:SetScript("OnEscapePressed", function() f.announceMsgBox:ClearFocus() end)
        f.announceMsgBox:SetScript("OnEnterPressed", function()
            QuickHoP_Settings.announceMessage = f.announceMsgBox:GetText()
            f.announceMsgBox:ClearFocus()
        end)
        f.announceMsgBox:SetScript("OnEditFocusLost", function()
            QuickHoP_Settings.announceMessage = f.announceMsgBox:GetText()
        end)
    end
    local currentMsg = QuickHoP_Settings.announceMessage
    if not currentMsg or currentMsg == "" then currentMsg = QuickHoP_DefaultAnnounceMsg end
    f.announceMsgBox:SetText(currentMsg)
    f.announceMsgBox:ClearAllPoints()
    f.announceMsgBox:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
    y = y - 24
    QuickHoP_UpdateAnnounceUI()
    y = y - SEC_GAP

    -- ---- Divider 4 ----
    if not f.divider4 then
        f.divider4 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.divider4:SetText("────────────────────────")
    end
    f.divider4:ClearAllPoints()
    f.divider4:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 16

    -- ---- HoP Request Notifications ----
    if not f.notifyHeader then
        f.notifyHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.notifyHeader:SetText("HoP Request Notifications:")
    end
    f.notifyHeader:ClearAllPoints()
    f.notifyHeader:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    y = y - 20

    local function MakeNotifyCheck(key, frameName, labelText, setting)
        if not f[key] then
            f[key] = CreateFrame("CheckButton", frameName, f, "UICheckButtonTemplate")
            f[key]:SetWidth(18)
            f[key]:SetHeight(18)
            local lbl = f[key]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetText(labelText)
            lbl:SetPoint("LEFT", f[key], "RIGHT", 2, 0)
            f[key].label = lbl
            f[key]:SetScript("OnClick", function()
                QuickHoP_Settings[setting] = f[key]:GetChecked() == 1
            end)
        end
        f[key]:SetChecked(QuickHoP_Settings[setting] and 1 or 0)
        return f[key]
    end

    -- Three notification checkboxes (glow removed)
    local chkFlash = MakeNotifyCheck("notifyCheckFlash", "QuickHoPNotifyFlash", "Screen Flash", "notifyFlash")
    local chkSound = MakeNotifyCheck("notifyCheckSound", "QuickHoPNotifySound", "Sound",        "notifySound")
    local chkChat  = MakeNotifyCheck("notifyCheckChat",  "QuickHoPNotifyChat",  "Chat Message", "notifyChat")
    local chkIcon  = MakeNotifyCheck("notifyCheckIcon",  "QuickHoPNotifyIcon",  "Center Icon",  "notifyIcon")

    chkFlash:ClearAllPoints()
    chkFlash:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
    chkSound:ClearAllPoints()
    chkSound:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4 + 130, y)
    y = y - 20
    chkChat:ClearAllPoints()
    chkChat:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
    chkIcon:ClearAllPoints()
    chkIcon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4 + 130, y)
    y = y - 20

    y = y - PAD
    local totalHeight = math.abs(y) + 10
    if totalHeight < 200 then totalHeight = 200 end
    f:SetWidth(W)
    f:SetHeight(totalHeight)
end

function QuickHoP_UpdateAnnounceUI()
    local f = QuickHoPOptionsFrame
    if not f then return end
    local enabled = QuickHoP_Settings.announceEnabled
    local c = enabled and 1 or 0.4
    if f.announceChannelLabel then f.announceChannelLabel:SetTextColor(c, c, c) end
    if f.announceMsgLabel     then f.announceMsgLabel:SetTextColor(c, c, c) end
    for _, w in ipairs({f.announceChanBoth, f.announceChanRaid, f.announceChanParty}) do
        if w then if enabled then w:Enable() else w:Disable() end end
    end
    if f.announceMsgBox then
        f.announceMsgBox:SetAlpha(enabled and 1 or 0.4)
        f.announceMsgBox:EnableMouse(enabled and true or false)
        f.announceMsgBox:EnableKeyboard(enabled and true or false)
    end
end

-- ============================================================
-- PALADIN MAIN UI UPDATE
-- ============================================================

function QuickHoP_UpdateUI()
    if not QuickHoPFrame then return end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then
        QuickHoPFrame:Hide()
        return
    end
    if not QuickHoP_CachedSpellIndex then QuickHoP_ScanSpells() end

    QuickHoPFrame:SetScale(QuickHoP_Settings.scale or 1.0)

    local btn        = getglobal("QuickHoPFrameButton")
    local icon       = getglobal("QuickHoPFrameButtonIcon")
    local targetText = getglobal("QuickHoPFrameButtonTargetText")
    local cdText     = getglobal("QuickHoPFrameButtonCooldownText")
    if not btn then return end

    if icon then
        if QuickHoP_Settings.showIcon ~= false and QuickHoP_CachedSpellTexture then
            icon:SetTexture(QuickHoP_CachedSpellTexture)
            icon:Show()
        else
            icon:Hide()
        end
    end

    if targetText then
        if QuickHoP_Settings.showTarget ~= false then
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

    if cdText then
        if QuickHoP_Settings.showCooldown ~= false and QuickHoP_CachedSpellIndex then
            local start, duration = GetSpellCooldown(QuickHoP_CachedSpellIndex, BOOKTYPE_SPELL)
            if duration and duration > 1.5 then
                local remaining = duration - (GetTime() - start)
                if remaining > 0 then
                    cdText:SetText(QuickHoP_FormatTime(remaining))
                    cdText:SetTextColor(1, 0.5, 0)
                else
                    cdText:SetText("Ready")
                    cdText:SetTextColor(0, 1, 0)
                end
            else
                cdText:SetText("Ready")
                cdText:SetTextColor(0, 1, 0)
            end
            cdText:Show()
        else
            cdText:Hide()
        end
    end
end

-- ============================================================
-- MAIN BUTTON HANDLERS
-- ============================================================

function QuickHoP_Button_OnClick(button)
    if arg1 == "LeftButton" then
        if IsControlKeyDown() then QuickHoP_ShowOptions()
        else QuickHoP_CastHoP() end
    elseif arg1 == "RightButton" then
        if IsShiftKeyDown() then QuickHoPFrame:Hide()
        elseif IsAltKeyDown() then QuickHoP_ClearTarget()
        else QuickHoP_SetTarget() end
    end
end

function QuickHoP_Button_OnEnter()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    if QuickHoP_CachedSpellRank and QuickHoP_CachedSpellRank ~= "" then
        GameTooltip:SetText("Hand of Protection ("..QuickHoP_CachedSpellRank..")", 1, 1, 1)
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
