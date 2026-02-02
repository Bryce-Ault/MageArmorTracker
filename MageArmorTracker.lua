local addonName, ns = ...

-- Only load for mages
local _, playerClass = UnitClass("player")
if playerClass ~= "MAGE" then return end

-- Configuration
local ICON_SIZE = 26
local ICON_PADDING = 6  -- gap between icon and ResourceDisplay
local LOW_TIME_THRESHOLD = 300  -- 5 minutes in seconds
local NO_ARMOR_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Armor spell names to track
local ARMOR_SPELLS = {
    ["Mage Armor"] = true,
    ["Ice Armor"] = true,
    ["Frost Armor"] = true,  -- lower rank name
}

-- Main frame anchored to the left of ResourceDisplay
local frame = CreateFrame("Frame", "MageArmorTrackerFrame", UIParent)
frame:SetSize(ICON_SIZE, ICON_SIZE)
frame:SetFrameStrata("LOW")

-- Icon texture
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim default icon border

-- Border around the icon
local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
border:SetBackdropBorderColor(0, 0, 0, 0.8)

-- Timer text (shown when < 5 min remaining)
local timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
timer:SetPoint("BOTTOM", frame, "BOTTOM", 0, -2)
timer:SetFont(timer:GetFont(), 11, "OUTLINE")
timer:SetTextColor(1, 0.2, 0.2, 1)

-- Desaturation overlay for no-armor state
local desatOverlay = frame:CreateTexture(nil, "OVERLAY")
desatOverlay:SetAllPoints()
desatOverlay:SetColorTexture(0, 0, 0, 0.45)
desatOverlay:Hide()

-- State
local activeArmor = nil      -- name of the active armor buff
local activeExpires = 0       -- GetTime() when the buff expires
local activeIcon = nil        -- texture path of the active buff icon

local function PositionFrame()
    frame:ClearAllPoints()
    local anchor = _G["ResourceDisplayAnchor"]
    if anchor then
        frame:SetPoint("RIGHT", anchor, "LEFT", -ICON_PADDING, 0)
    else
        -- Fallback if ResourceDisplay isn't loaded yet
        frame:SetPoint("CENTER", UIParent, "CENTER", -86, -145)
    end
end

local function ScanArmor()
    for i = 1, 40 do
        local name, iconTex, _, _, _, expirationTime = UnitBuff("player", i)
        if not name then break end
        if ARMOR_SPELLS[name] then
            activeArmor = name
            activeIcon = iconTex
            activeExpires = expirationTime
            return
        end
    end
    -- No armor found
    activeArmor = nil
    activeIcon = nil
    activeExpires = 0
end

local function UpdateDisplay()
    if activeArmor then
        icon:SetTexture(activeIcon)
        icon:SetDesaturated(false)
        desatOverlay:Hide()
    else
        icon:SetTexture(NO_ARMOR_ICON)
        icon:SetDesaturated(true)
        desatOverlay:Show()
    end
end

local function UpdateTimer()
    if not activeArmor or activeExpires == 0 then
        timer:SetText("")
        return
    end

    local remaining = activeExpires - GetTime()
    if remaining <= 0 then
        timer:SetText("")
        return
    end

    if remaining <= LOW_TIME_THRESHOLD then
        local mins = math.floor(remaining / 60)
        local secs = math.floor(remaining % 60)
        timer:SetText(string.format("%d:%02d", mins, secs))
    else
        timer:SetText("")
    end
end

-- OnUpdate for timer countdown (only runs when armor is active and low)
local elapsed_acc = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    elapsed_acc = elapsed_acc + elapsed
    if elapsed_acc < 0.2 then return end
    elapsed_acc = 0
    UpdateTimer()
end)

-- Event handling
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        PositionFrame()
        ScanArmor()
        UpdateDisplay()
        UpdateTimer()
        return
    end

    if event == "UNIT_AURA" then
        if unit ~= "player" then return end
        ScanArmor()
        UpdateDisplay()
        UpdateTimer()
    end
end)
