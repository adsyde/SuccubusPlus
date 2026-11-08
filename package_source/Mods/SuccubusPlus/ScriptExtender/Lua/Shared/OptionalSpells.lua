SUCC_CANTRIPS = "00884d36-fe04-57a5-b102-88c232b3b84d"
SUCC_SPELL_LISTS = { [1] = "28fb1f73-a49f-5278-9fae-2c4870cb6fb9", [2] = "e3a93f57-6fb2-5edc-858c-d946b4fed0b9", [3] = "6a1abc63-4a39-548d-8db4-9a7a933ef45b", [4] = "fb29065d-cfed-571d-add8-61e9a9aa9ca9", [5] = "7c218ae1-3467-5281-8c74-0f291050b1e2", [6] = "cd194c06-6fa0-53d0-8b4e-d8fe2215bd6a" }

-- SuccubusPlus: необязательные заклинания из других модов. Мод работает и без них; если 5eSpells или
-- Valkrana's Spellbook включены, их подходящие по лору заклинания попадают в списки суккуба.
-- Заклинание за чары — вариант SuccSpell_* (как в features.spell_variant): стоимость ActionPoint:1;SuccubusCharm:1,
-- Level пустой (та же причина, что в features.spell_variant). Фокусы добавляются как есть. Списки
-- дописываются так же, как это делает 5eSpells
-- (Ext.StaticData + Ext.Types.Serialize/Unserialize в StatsLoaded). SUCC_CANTRIPS и SUCC_SPELL_LISTS
-- (круг -> UUID списка «до этого круга») подставляет make_mod.py перед этим файлом.

local OPTIONAL = {
    ["fb5f528d-4d48-4bf2-a668-2274d3cfba96"] = {  -- 5eSpells
        [0] = { "Target_MindSliver" },
        [1] = { "Target_CauseFear" },
        [2] = { "Target_MindWhip", "Target_MindSpike", "Target_Suggestion" },
        [3] = { "Target_EnemiesAbound", "Target_Antagonize" },
        [4] = { "Target_CharmMonster", "Projectile_RaulothimsPsychicLance", "Shout_ShadowOfMoil" },
        [5] = { "Target_SynapticStatic", "Target_Mislead" },
    },
    ["9deeb371-f01e-41b4-b20e-c5eee0751b12"] = {  -- Valkrana's Spellbook
        [1] = { "Projectile_ValkranaShadowfellSalvo" },
        [2] = { "Target_ValkranaSoulSecret" },
    },
}

local function variant_name(base)
    return "SuccSpell_" .. base:match("^[^_]+_(.+)$")
end

local function add_to_list(uuid, spells)
    local sd = Ext.StaticData.Get(uuid, "SpellList")
    local list = sd and sd.Spells or nil
    if not list then return end
    local arr = Ext.Types.Serialize(list)
    local have, changed = {}, false
    for _, s in ipairs(arr) do have[s] = true end
    for _, s in ipairs(spells) do
        if not have[s] then table.insert(arr, s); changed = true end
    end
    if changed then Ext.Types.Unserialize(list, arr) end
end

local function make_variant(base)
    local name = variant_name(base)
    if Ext.Stats.Get(name) then return name end
    local ok, s = pcall(Ext.Stats.Create, name, "SpellData", base)
    if not ok or not s then return nil end
    s.Level = 0  -- пустой (как у FourElements/ArcaneShot): у класса нет ячеек, свой круг фильтровал бы список в пустоту
    s.UseCosts = "ActionPoint:1;SuccubusCharm:1"
    s.RitualCosts = ""
    s:Sync()
    return name
end

function SuccubusPlus_OptionalSpells()
    for mod, circles in pairs(OPTIONAL) do
        if Ext.Mod.IsModLoaded(mod) then
            for circle, bases in pairs(circles) do
                local names = {}
                for _, base in ipairs(bases) do
                    if Ext.Stats.Get(base) then
                        table.insert(names, circle == 0 and base or make_variant(base))
                    end
                end
                if circle == 0 then
                    add_to_list(SUCC_CANTRIPS, names)
                else
                    -- списки накопительные: заклинание круга N есть во всех списках «до круга N и выше»
                    for c, uuid in pairs(SUCC_SPELL_LISTS) do
                        if c >= circle then add_to_list(uuid, names) end
                    end
                end
            end
        end
    end
end

Ext.Events.StatsLoaded:Subscribe(SuccubusPlus_OptionalSpells)
