-- SuccubusPlus: совместимость с Heels Mod (Sulfoxide, Nexus 24587). Он озвучивает шаги
-- персонажа особым звуком, если на персонаже есть маркерный пассив HEELS_FOOTWEAR (сам мод
-- ставит его на дереве статусов, но ни на один предмет его не вешает -- ждёт, что это сделают
-- другие моды). Обувь суккуба (Ophelia's High Heels Collection, Silk_Heels/Silk_Heels_Camp)
-- каблучная, так что даём ей этот пассив через PassivesOnEquip, как ванильные ARM_* делают
-- для своих пассивов (см. data "PassivesOnEquip" в Armor.txt).
local HEELS_MOD = "a51f5405-30e3-41a2-bc16-ad7682fb14ea"
local SHOES = { "Silk_Heels", "Silk_Heels_Camp" }
local PASSIVE = "HEELS_FOOTWEAR"

local function SuccubusPlus_OpheliaHeelsCompat()
    if not Ext.Mod.IsModLoaded(HEELS_MOD) then return end
    for _, name in ipairs(SHOES) do
        local s = Ext.Stats.Get(name)
        if s then
            local cur = s.PassivesOnEquip or ""
            if not cur:find(PASSIVE, 1, true) then
                s.PassivesOnEquip = cur ~= "" and (cur .. ";" .. PASSIVE) or PASSIVE
                s:Sync()
            end
        end
    end
end

Ext.Events.StatsLoaded:Subscribe(SuccubusPlus_OpheliaHeelsCompat)
