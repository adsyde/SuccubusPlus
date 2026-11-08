-- Restore the class dialog tag on existing characters. ClassDescriptions alone
-- do not actively reconcile a saved character; keep the one-attempt flags intact.
local TAG = "f3eebbdb-e98b-54a4-a284-1e2f72537562"
local TRIED = "28ff2cea-7e24-5f15-ae54-bab5f444afe1"

local function query(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function reconcile(character)
    if type(character) ~= "string" or character == "" then return end
    local class = query(Osi.HasPassive, character, "Succubus_Desire")
    local tagged = query(Osi.IsTagged, character, TAG)
    if class == 1 and tagged == 0 then
        local ok = pcall(Osi.SetTag, character, TAG)
        if ok then
            _P("[SuccubusPlus] Dialog eligibility: restored class tag for " .. character)
        end
    elseif class == 0 and tagged == 1 then
        -- A completed respec must not leave class dialog options on another class.
        pcall(Osi.ClearTag, character, TAG)
    end
end

local function reconcilePlayers()
    local ok, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if not ok or type(rows) ~= "table" then return end
    for _, row in ipairs(rows) do reconcile(row[1]) end
end

-- Osiris events run after the story is available, unlike restricted SessionLoaded.
Ext.Osiris.RegisterListener("SavegameLoaded", 0, "after", reconcilePlayers)
Ext.Osiris.RegisterListener("CharacterCreationFinished", 0, "after", reconcilePlayers)
for _, event in ipairs({"CharacterJoinedParty", "LeveledUp", "RespecCompleted"}) do
    Ext.Osiris.RegisterListener(event, 1, "after", reconcile)
end
Ext.Osiris.RegisterListener("DialogStarted", 2, "before", reconcilePlayers)
Ext.Osiris.RegisterListener("DialogStarted", 2, "after", function(dialog, instance)
    local player = query(Osi.DialogGetInvolvedPlayer, instance, 1)
    if type(player) ~= "string" or player == "" then return end
    reconcile(player)
    local class = query(Osi.HasPassive, player, "Succubus_Desire")
    local trader = query(Osi.DialogGetInvolvedNPC, instance, 1)
    local tried = type(trader) == "string" and query(Osi.GetFlag, TRIED, trader) or nil
    _P(string.format("[SuccubusPlus] Dialog eligibility: dialog=%s player=%s class=%s tag=%s npc=%s tried=%s",
        tostring(dialog), player, tostring(class), tostring(query(Osi.IsTagged, player, TAG)),
        tostring(trader), tostring(tried)))
end)
