-- #############################################################################
-- guild bank
-- update when changing equip sets
-- #############################################################################
local folder,ns=...
local addon = CreateFrame('Frame')
local kui = LibStub('Kui-1.0')
local liui = LibStub('LibItemUpgradeInfo-1.0')

-- equipment set inventory slot stuff ##########################################
-- items by bag => { slot => { set names } }
local es_items = {}

local function GetNamesBySlot(bag,slot,sep,max_names)
    if not bag or not slot then return end
    sep = sep or '|n'

    if es_items[bag] and es_items[bag][slot] then
        local names = es_items[bag][slot]

        if names and #names > 0 then
            local t = ''
            for k,name in ipairs(names) do
                if k > max_names then
                    break
                elseif k == 1 then
                    t = name
                else
                    t = t..sep..name
                end
            end

            return t
        end
    end
end

local function UpdateSlotButton(frame)
    local bag = frame:GetParent():GetID()
    local slot = frame:GetID()

    local link,ilvl = GetContainerItemLink(bag,slot)
    if link and IsEquippableItem(link) then
        ilvl = liui:GetUpgradedItemLevel(link)
    end

    if bag == -1 and frame.frame.frameID == 'bank' then
        bag = 'bank-1'
    end

    local names = GetNamesBySlot(bag,slot,nil,3)

    local text = frame.KuiEquipText
    if not text then
        local t = frame:CreateFontString(nil,'OVERLAY')
        t:SetPoint('TOPLEFT',-5,0)
        t:SetPoint('BOTTOMRIGHT',5,0)
        t:SetJustifyV('TOP')
        t:SetFont(kui.m.f.francois,11,'outline')
        t:SetShadowColor(0,0,0,1)
        t:SetShadowOffset(1,-1)

        text = t
        frame.KuiEquipText = t
    end

    local ilvl_text = frame.KuiItemLevelText
    if not ilvl_text then
        local t = frame:CreateFontString(nil,'OVERLAY')
        t:SetPoint('BOTTOMLEFT',5,-2)
        t:SetPoint('BOTTOMRIGHT',-5,-2)
        t:SetFont(kui.m.f.francois,11,'outline')
        t:SetShadowColor(0,0,0,1)
        t:SetShadowOffset(1,-1)

        ilvl_text = t
        frame.KuiItemLevelText = t
    end

    if link and ilvl then
        ilvl_text:SetText(ilvl)
        ilvl_text:Show()
    else
        ilvl_text:Hide()
    end

    if names then
        text:SetText(names)
        text:Show()
    else
        text:Hide()
    end
end

local function ParseLocationArray(es_name,items)
    if not items then return end

    for _,location in pairs(items) do
        local player,bank,bags,void,slot,bag =
            EquipmentManager_UnpackLocation(location)

        if bags or bank then
            if bank and not bags then
                bag = 'bank-1'
                slot = slot - BANK_CONTAINER_INVENTORY_OFFSET
            end

            if not es_items[bag] then
                es_items[bag] = {}
            end
            if not es_items[bag][slot] then
                es_items[bag][slot] = {}
            end

            tinsert(es_items[bag][slot],es_name)
        end
    end
end
local function GetInventorySlotItems()
    -- create list of items in equipment sets
    local ids = C_EquipmentSet.GetEquipmentSetIDs()
    wipe(es_items)

    for k,id in ipairs(ids) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(id)
        local items = C_EquipmentSet.GetItemLocations(id)
        ParseLocationArray(name,items)
    end
end

-- paper-doll frame stuff ######################################################
local slots = {
    "Head",
    "Neck",
    "Shoulder",
    "Back",
    "Chest",
    "Wrist",
    "Hands",
    "Waist",
    "Legs",
    "Feet",
    "Finger0",
    "Finger1",
    "Trinket0",
    "Trinket1",
    "MainHand",
    "SecondaryHand",
}
local buttons = {}

local function ParseSlots()
    -- parse slot names into inventory ids & paper-doll frames
    for _,k in pairs(slots) do
        k = k..'Slot'

        local id = GetInventorySlotInfo(k)
        local button_name = 'Character'..k

        buttons[id] = _G[button_name]
    end
end
local function CreateText()
    -- create text objects on paper-doll frames
    for k,b in pairs(buttons) do
        local text = b:CreateFontString(nil,'OVERLAY')
        text:SetPoint('BOTTOMLEFT',2,2)
        text:SetFont(kui.m.f.francois,11,'outline')
        text:SetShadowColor(0,0,0,1)
        text:SetShadowOffset(1,-1)

        b.KuiText = text
    end
end
local function UpdateEquipment()
    -- set text to item levels on paper-doll frames
    local high,low

    -- fetch item levels
    for k,b in pairs(buttons) do
        local link = GetInventoryItemLink('player',k)
        if link and (b ~= CharacterSecondaryHandSlot or not HasArtifactEquipped()) then
            local ilvl = liui:GetUpgradedItemLevel(link)
            b.Kui_ilvl = ilvl

            if ilvl then
                if not high or ilvl > high  then
                    high = ilvl
                end
                if not low or ilvl < low then
                    low = ilvl
                end
            end
        else
            b.Kui_ilvl = nil
        end
    end

    if not high or not low then return end
    local diff = high-low

    -- set text
    for k,b in pairs(buttons) do
        local ilvl = b.Kui_ilvl
        if ilvl then
            -- scaled distance & direction from centre point between low/high
            local grad_dir = (.5-((ilvl-low)/diff))*2
            -- reverse distance into closeness (higher number closer to middle)
            local cor_dir = math.abs(math.abs(grad_dir)-1)
            -- amount of colour from 75 to 255 depending on distance
            local grad_col = (75+(cor_dir*180))/255

            if grad_dir >= 0 then
                -- red
                b.KuiText:SetTextColor(1,grad_col,grad_col)
            else
                -- green
                b.KuiText:SetTextColor(grad_col,1,grad_col)
            end

            b.KuiText:SetText(ilvl)
            b.KuiText:Show()
        else
            b.KuiText:Hide()
        end
    end
end
-- artefact ui stuff ###########################################################
do
    local hooked

    local function CreateRelicText(slot)
        local text = slot:CreateFontString(nil,'OVERLAY')
        text:SetPoint('BOTTOM',slot,'TOP',0,-18)
        text:SetFont(kui.m.f.francois,11,'outline')
        text:SetShadowColor(0,0,0,1)
        text:SetShadowOffset(1,-1)
        text:Hide()

        slot.KuiText = text
    end
    local function ArtifactFrameOnShow(self)
        addon:UpdateRelics()
    end

    function addon:UpdateRelics()
        if not hooked then return end
        if not ArtifactFrame:IsShown() then return end

        for i=1,3 do
            local slot = ArtifactFrame.PerksTab.TitleContainer['RelicSlot'..i]
            if slot then
                if not slot.KuiText then
                    CreateRelicText(slot)
                end

                slot.KuiText:Hide()

                local _,_,_,link = C_ArtifactUI.GetRelicInfo(i)
                local ilvl = link and liui:GetUpgradedItemLevel(link)
                if ilvl then
                    slot.KuiText:SetText(ilvl)
                    slot.KuiText:Show()
                end
            end
        end
    end
    function addon:HookArtifactUI()
        hooked = true
        ArtifactFrame:HookScript('OnShow',ArtifactFrameOnShow)
    end
end
-- events ######################################################################
function addon:ADDON_LOADED(addon)
    if addon == 'Blizzard_ArtifactUI' then
        self:HookArtifactUI()
    elseif addon ~= folder then
        return
    end

    ParseSlots()
    CreateText()

    if Bagnon and Bagnon.ItemSlot then
        hooksecurefunc(Bagnon.ItemSlot,'SetItem',UpdateSlotButton)
    end
end
function addon:EQUIPMENT_SETS_CHANGED()
    UpdateEquipment()
    GetInventorySlotItems()
end
function addon:PLAYER_EQUIPMENT_CHANGED()
    UpdateEquipment()
    GetInventorySlotItems()
end
function addon:BAG_UPDATE()
    UpdateEquipment()
    GetInventorySlotItems()
end
function addon:ARTIFACT_UPDATE()
    self:UpdateRelics()
end
function addon:PLAYERBANKSLOTS_CHANGED()
    self:BAG_UPDATE()
end
function addon:BANKFRAME_OPENED()
    GetInventorySlotItems()
end
-- initialise ##################################################################
addon:SetScript('OnEvent',function(self,event,...)
    self[event](self,...)
end)

addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('EQUIPMENT_SETS_CHANGED')
addon:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
addon:RegisterEvent('BAG_UPDATE')
addon:RegisterEvent("ARTIFACT_UPDATE");
addon:RegisterEvent('PLAYERBANKSLOTS_CHANGED')
addon:RegisterEvent("BANKFRAME_OPENED");
