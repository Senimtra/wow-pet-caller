-- PET-caller: summon Brightpaw whenever I mount Mystic Runesaber.

local frame = CreateFrame("Frame") -- Create a hidden frame to receive events.
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Fire once when the player enters the world.
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") -- Fire when a spell cast finishes successfully.

local fired = false -- Guard so the login message only prints once.
local MOUNT_SPELL_NAME = "Mystic Runesaber" -- The exact spell name of the mount.
local PET_NAME = "Brightpaw" -- The exact pet name I want to summon.
local targetPetGUID = nil -- Cache for Brightpaw's GUID (unique pet ID).

local function getSpellName(spellID)
    -- Resolve a spell name from its ID using whatever API exists in the client.
    if C_Spell and C_Spell.GetSpellName then -- Newer API.
        return C_Spell.GetSpellName(spellID)
    end
    if C_Spell and C_Spell.GetSpellInfo then -- Older C_Spell API.
        local info = C_Spell.GetSpellInfo(spellID) -- Info table includes .name.
        return info and info.name or nil
    end
    if GetSpellInfo then -- Legacy global API.
        return GetSpellInfo(spellID)
    end
    return nil -- If no API exists, return nothing.
end

local function findBrightpawGUID()
    -- Scan the pet journal and return Brightpaw's GUID (unique pet ID).
    local numPets = C_PetJournal.GetNumPets() -- Total pets in my journal.
    for i = 1, numPets do -- Walk every pet entry.
        local petID, _, owned, customName, _, _, _, name = C_PetJournal.GetPetInfoByIndex(i)
        local displayName = customName or name -- Custom name overrides the base name.
        if owned and displayName == PET_NAME then -- Only match owned pets by name.
            return petID -- This petID is the GUID used by the journal.
        end
    end
    return nil -- Not found.
end

local function summonBrightpawIfNeeded()
    -- Cache the pet GUID once so I do not re-scan every time.
    if not targetPetGUID then -- If I do not already know the GUID...
        targetPetGUID = findBrightpawGUID() -- ...search for it now.
    end
    if not targetPetGUID then -- If still missing, stop quietly.
        return
    end

    -- Do nothing if Brightpaw is already the active summoned pet.
    if C_PetJournal.GetSummonedPetGUID() == targetPetGUID then
        return
    end

    -- Summon Brightpaw.
    C_PetJournal.SummonPetByGUID(targetPetGUID)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Run once on login/reload: cache the pet GUID and print the load message.
        if fired then return end -- Prevent double-printing.
        fired = true -- Mark as fired.
        targetPetGUID = findBrightpawGUID() -- Cache Brightpaw's GUID early.
        DEFAULT_CHAT_FRAME:AddMessage("|cff8f3fffPET-caller|r loaded v1.0") -- Pretty load message.
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Fires when a spell successfully completes casting.
        local unit, _, spellID = ... -- Read event payload.
        if unit ~= "player" then return end -- Ignore other units' casts.

        -- If the successful spell was my mount, ensure Brightpaw is out.
        local spellName = getSpellName(spellID) -- Convert ID to name.
        if spellName == MOUNT_SPELL_NAME then -- Only react to my mount.
            summonBrightpawIfNeeded() -- Summon if needed.
        end
    end
end)
