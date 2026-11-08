Ext.Require("Shared/Dialogs.lua")

Ext.Require("Shared/OptionalSpells.lua")
Ext.Require("Shared/OpheliaHeelsCompat.lua")

-- SuccubusFix: страховка «Экстаза» (Succubus_Enemy_DesireMAX) для класса «Суккуб».
-- В моде экстаз вешается цепочкой служебных статусов, которая запускается только в начале боя
-- и опирается на запись ОЗ врага; если суккуб вступил в бой позже или запись не успела,
-- экстаз не наступал никогда. Здесь проверка прямая: желание (длительность накопительного
-- статуса Succubus_Enemy_Desire_Counter) >= текущих ОЗ врага -> экстаз.
-- Проверяем, когда растет желание, когда врага бьют и в начале каждого хода.

local DESIRE = "Succubus_Enemy_Desire_Counter"
local CLIMAX = "Succubus_Enemy_DesireMAX"
local SUCCUBUS_PASSIVE = "Succubus_Desire"

local function rows(db, ...)
    local args = { ... }
    local ok, r = pcall(function() return Osi[db]:Get(table.unpack(args)) end)
    if ok and type(r) == "table" then return r end
    return {}
end

local function q(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

-- источник экстаза: суккуб из отряда (статус при наложении кладет суккубу счетчик врагов в экстазе)
local function succubus()
    for _, r in ipairs(rows("DB_Players", nil)) do
        if q(Osi.HasPassive, r[1], SUCCUBUS_PASSIVE) == 1 then return r[1] end
    end
    return nil
end

local function check(target)
    if type(target) ~= "string" then return end
    if q(Osi.HasActiveStatus, target, DESIRE) ~= 1 then return end
    if q(Osi.HasActiveStatus, target, CLIMAX) == 1 then return end
    if q(Osi.IsDead, target) == 1 then return end
    if q(Osi.IsInCombat, target) ~= 1 then return end
    local desire = tonumber(q(Osi.GetStatusTurns, target, DESIRE)) or 0
    local hp = tonumber(q(Osi.GetHitpoints, target)) or 0
    if hp > 0 and desire >= hp then
        local src = succubus()
        if src then
            pcall(Osi.ApplyStatus, target, CLIMAX, -1, 1, src)
        else
            pcall(Osi.ApplyStatus, target, CLIMAX, -1, 1)
        end
    end
end

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
    if status == DESIRE then check(object) end
end)

Ext.Osiris.RegisterListener("AttackedBy", 7, "after",
    function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
        check(defender)
    end)

Ext.Osiris.RegisterListener("TurnStarted", 1, "after", function(character)
    check(character)
end)

-- SuccubusPlus: «Опустошение» (SUCCUBUS_DRAINED — копия «Кровопотери» ASTARION_WEAK, -1 к атакам,
-- испытаниям и проверкам) для тех, с кем суккуб был близок: 50 ходов после секса, 5 после поцелуя.
-- Суккуб — персонаж с пассивкой Succubus_Desire. Партнеры — остальные участники сцены.
-- Источники: флаги и диалоги игры (Osiris FlagSet / DialogActorJoined / DialogEnded) и сцены BG3SX.
-- Флаги и диалоги сравниваются по UUID (последние 36 символов строки Osiris).

local DRAINED = "SUCCUBUS_DRAINED"
local SEX_TURNS, KISS_TURNS = 50, 5

-- флаг -> {kind, запасной партнер, если флаг выставлен не в диалоге}
local FLAGS = {
    -- секс (флаг ставится, только если сцена состоялась)
    ["504df8d4-2152-f67e-5ca1-5a6a04c4627f"] = { "sex", "c7c13742-bacd-460a-8f65-f864fe41f255" }, -- Astarion, ночь после праздника
    ["ea9faf06-5886-0ef7-9996-28307f0baeb2"] = { "sex", "c7c13742-bacd-460a-8f65-f864fe41f255" }, -- ORI_HadSexWithAstarion
    ["150c8ec7-fbd2-d040-9951-0c41c911c371"] = { "sex", "58a69333-40bf-8358-1d17-fff240d7fb12" }, -- ORI_HadSexWithLaezel
    ["ee418d4a-0bc3-4626-bfd0-eb14d6e537bc"] = { "sex", "58a69333-40bf-8358-1d17-fff240d7fb12" }, -- Laezel Romance1HadSex
    ["d17fb00d-d999-44d1-8479-8dc26022ab8e"] = { "sex", "58a69333-40bf-8358-1d17-fff240d7fb12" }, -- Laezel Romance2HadSex
    ["51408d18-17c8-1b71-2ddc-4df94ea60797"] = { "sex", "25721313-0c15-4935-8176-9f134385451b", dialogOnly = true }, -- ORI_HadSexWithMinthara (A Beautiful Webbing ставит его и при отказе, но скриптом, вне диалога)
    ["8adfdfe9-5170-aa82-2eab-0cca0ac04112"] = { "sex", "0de603c5-42e2-4811-9dad-f652de080eba" }, -- ORI_HadSexWithMinsc
    ["0d6941f3-511b-4d80-fcda-7adc8a960fbb"] = { "sex", "c774d764-4a17-48dc-b470-32ace9ce447d" }, -- ORI_HadSexWithWyll
    ["c042ad34-f39f-71e6-3a43-fcfac2e847c9"] = { "sex", "2c76687d-93a2-477b-8b18-8a14b549304c" }, -- ORI_HadSexWithKarlach
    ["1d310301-bebf-477a-a460-399adaee2e8d"] = { "sex", "7628bc0e-52b8-42a7-856a-13a6fd413323" }, -- Halsin, эльф
    ["eecac008-77e9-4fb8-a26f-1e46ebfe25f1"] = { "sex", "7628bc0e-52b8-42a7-856a-13a6fd413323" }, -- Halsin, медведь
    ["b5bb0f61-64ac-255e-a7c7-9d3b6f84ea31"] = { "sex", nil },                                    -- Мизора
    ["10cfd95c-876e-cce9-9138-5593b5b5a33e"] = { "sex", nil },                                    -- дроу-близнецы
    ["933959fb-958b-59bc-3d5e-31e12f619d8d"] = { "sex", "73d49dc5-8b8b-45dc-a98c-927bb4e3169b" }, -- Император
    ["218d22ac-2711-1405-a04e-5aab2514c5cb"] = { "sex", "3947e0e2-3b4c-4a39-ac53-454e95665b26" }, -- Хаарлеп
    ["923441c5-d3b2-b5f2-d7d7-c243f7f8c18b"] = { "sex", "c774d764-4a17-48dc-b470-32ace9ce447d" }, -- Wyll, акт 2
    ["4fb50342-ce79-4c29-b1e4-e299f5762561"] = { "sex", "c7c13742-bacd-460a-8f65-f864fe41f255" }, -- Astarion, после Черной мессы
    ["89e80d33-c1e5-4c14-a532-4199b381e510"] = { "sex", "c7c13742-bacd-460a-8f65-f864fe41f255" }, -- Astarion, торговец кровью
    -- поцелуи
    ["2a98bc41-f6b7-4277-a282-1a91c4ef8a9b"] = { "kiss", nil, speakerIsPartner = true },           -- ORI_Kiss_StartRandom («Можно тебя поцеловать?»)
    ["0434578b-646b-e0a7-3124-bc3338144658"] = { "kiss", "3ed74f06-3c60-42dc-83f6-f034cb47c679" }, -- Shadowheart, праздник
    ["d0aff20a-1b27-2f59-c4fb-d944448e7208"] = { "kiss", "c774d764-4a17-48dc-b470-32ace9ce447d" }, -- Wyll, праздник
    ["4ed3c064-1537-8b3b-a791-af3047edfcec"] = { "kiss", "58a69333-40bf-8358-1d17-fff240d7fb12" }, -- Laezel
    ["4394fa93-e71f-b956-c106-bb5ee4430414"] = { "kiss", "c774d764-4a17-48dc-b470-32ace9ce447d" }, -- Wyll
    ["7d9cf683-4717-c5c8-a6fb-bbd281218c25"] = { "kiss", "2c76687d-93a2-477b-8b18-8a14b549304c" }, -- Karlach, после починки сердца
    ["bf82162b-e99e-46ae-a1c6-86053c1ceb5e"] = { "kiss", "7628bc0e-52b8-42a7-856a-13a6fd413323" }, -- Halsin
    ["5545bdb8-364d-4550-85a0-d67382966e70"] = { "kiss", "7628bc0e-52b8-42a7-856a-13a6fd413323" }, -- Halsin, финал
    ["48f9311b-a74a-4451-9c2f-68c6e271641d"] = { "kiss", "58a69333-40bf-8358-1d17-fff240d7fb12" }, -- Laezel, финал
    ["27d18f3c-c54a-456e-aaec-5faea2364bc1"] = { "kiss", "25721313-0c15-4935-8176-9f134385451b" }, -- Minthara
}

-- сцены без флага «состоялось»: срабатывают в конце диалога, если в нем не выставлен флаг отказа
local DIALOGS = {
    ["700d677f-1bfd-1c83-8530-0db12875c33b"] = { "sex", "26e83a93-8999-4488-83ee-a93d1ccd5cac" }, -- Shadowheart, купание
    ["0a86b0b6-4ebc-d1f1-d537-715983e22c26"] = { "sex", "becb720c-0e30-448d-b1a5-42cddf36409f" }, -- Shadowheart, Nightfall
    ["c2fbbf85-71d0-d4aa-07df-21abbb9f303a"] = { "sex", nil },                                    -- Karlach, после починки сердца
    ["2bf0d0c0-495c-6866-d5ad-d37dd4fa3648"] = { "sex", "306bf676-1d2e-7500-9244-dab19607bfd3" }, -- Karlach, свидание
    ["e6067557-2187-7493-c9b6-363ef6dd8334"] = { "sex", nil },                                    -- Gale, последняя ночь
    ["9126cddc-ad91-a174-d7e1-c4c35f1408b5"] = { "kiss", nil },                                   -- Gale, праздник (Плетение)
    ["86bc2633-3a2e-4d3c-b6ec-7622dad15e1f"] = { "sex", "f17a9a86-b191-4afc-ad60-0377283402f2" }, -- Minthara, акт 2 (мод A Beautiful Webbing), отказ — WAD_MinthyisAnnoyed
}

local function uid(s)
    if type(s) ~= "string" or #s < 36 then return nil end
    return string.lower(s:sub(-36))
end

local function isSuccubus(c)
    local ok, v = pcall(Osi.HasPassive, c, "Succubus_Desire")
    return ok and v == 1
end

local function drain(partner, turns, source)
    if not partner or isSuccubus(partner) then return end
    local ok = pcall(Osi.ApplyStatus, partner, DRAINED, turns * 6.0, 1, source)
    if not ok then pcall(Osi.ApplyStatus, partner, DRAINED, turns * 6.0, 1) end
end

-- участники и выставленные флаги каждого идущего диалога
local actors, setFlags, done = {}, {}, {}

local function succubusOf(list)
    for _, c in ipairs(list or {}) do
        if isSuccubus(c) then return c end
    end
    return nil
end

local function playerSuccubus()
    local ok, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if ok and type(rows) == "table" then
        for _, r in ipairs(rows) do
            if isSuccubus(r[1]) then return r[1] end
        end
    end
    return nil
end

local function apply(kind, list, succubus, only)
    local turns = kind == "sex" and SEX_TURNS or KISS_TURNS
    if only then
        drain(only, turns, succubus)
        return
    end
    for _, c in ipairs(list or {}) do
        if uid(c) ~= uid(succubus) then drain(c, turns, succubus) end
    end
end

Ext.Osiris.RegisterListener("DialogActorJoined", 4, "after", function(dialog, instance, actor, speakerIndex)
    actors[instance] = actors[instance] or {}
    table.insert(actors[instance], actor)
end)

Ext.Osiris.RegisterListener("FlagSet", 3, "after", function(flag, speaker, instance)
    local id = uid(flag)
    if not id then return end
    if instance and instance ~= 0 then
        setFlags[instance] = setFlags[instance] or {}
        setFlags[instance][id] = true
    end
    local info = FLAGS[id]
    if not info then return end
    if info.dialogOnly and not (instance and instance ~= 0) then return end
    local list = (instance and actors[instance]) or {}
    local succubus = succubusOf(list)
    if not succubus and isSuccubus(speaker) then succubus = speaker end
    if not succubus and #list == 0 then succubus = playerSuccubus() end
    if not succubus then return end
    local key = tostring(instance) .. ":" .. info[1]
    if instance and instance ~= 0 and done[key] then return end
    done[key] = true
    if info.speakerIsPartner and speaker and not isSuccubus(speaker) then
        apply(info[1], nil, succubus, speaker)
    elseif #list > 1 then
        apply(info[1], list, succubus)
    elseif info[2] then
        apply(info[1], nil, succubus, info[2])
    end
end)

Ext.Osiris.RegisterListener("DialogEnded", 2, "after", function(dialog, instance)
    local info = DIALOGS[uid(dialog) or ""]
    local list = actors[instance]
    if info and list then
        local succubus = succubusOf(list)
        local cancelled = info[2] and setFlags[instance] and setFlags[instance][info[2]]
        if succubus and not cancelled and not done[tostring(instance) .. ":" .. info[1]] then
            apply(info[1], list, succubus)
        end
    end
    actors[instance], setFlags[instance] = nil, nil
    done[tostring(instance) .. ":sex"], done[tostring(instance) .. ":kiss"] = nil, nil
end)

-- BG3SX: сцена NSFW на двоих и больше; «Опустошение» после ее окончания
local sxScenes = {}

local function sxEntities(e)
    local scene = type(e) == "table" and (e[1] or e) or nil
    if type(scene) ~= "table" then return nil end
    return scene.Uuid, scene.Type, scene.entities
end

Ext.Events.SessionLoaded:Subscribe(function()
    local ev = Ext.ModEvents and Ext.ModEvents.BG3SX
    if not ev or not ev.SceneCreated or not ev.SceneDestroyed then return end
    ev.SceneCreated:Subscribe(function(e)
        local ok, id, typ, ents = pcall(sxEntities, e)
        if ok and id and typ == "NSFW" and type(ents) == "table" and #ents >= 2 then
            local copy = {}
            for _, c in ipairs(ents) do table.insert(copy, c) end
            sxScenes[id] = copy
        end
    end)
    ev.SceneDestroyed:Subscribe(function(e)
        local id = type(e) == "table" and (e[1] or e.Uuid) or e
        local ents = sxScenes[id]
        sxScenes[id] = nil
        if not ents then return end
        local succubus = succubusOf(ents)
        if succubus then apply("sex", ents, succubus) end
    end)
end)

-- SuccubusPlus: очарование торговцев. Бросок харизмы рядом с «Торговать» (DialogKit add_roll) ставит
-- на торговце Object-флаг «очарован» или «не очарован»; здесь меняем его отношение к герою:
--   успех  -> +50 (цены ниже ~25%, PriceAttitudeCoefficient 0.005), но не выше 100;
--   провал -> -50 (цены выше ~25%), но не ниже -44: на -45 игра заменяет беседу враждебной
--             (NGB_Default_Hostile) и торговля закрывается. Если отношение уже низкое — штраф меньше или 0.
-- Как у Аррона в игре (+50 «своим друидам»): AddAttitudeTowardsPlayer(торговец, герой, N).

local CHARM_SUCCESS = "33a95622-9ed0-548e-96ca-18bdbbebe456"   -- SUCC_TraderCharm_Success
local CHARM_FAILURE = "3fc4d1d4-9f68-536f-ba5e-f93b03187adf"   -- SUCC_TraderCharm_Failure
local STEP, CAP, FLOOR = 50, 100, -44

local function flagId(s)
    if type(s) ~= "string" or #s < 36 then return nil end
    return string.lower(s:sub(-36))
end

local function charmPlayer(instance)
    local ok, p = pcall(Osi.DialogGetInvolvedPlayer, instance, 1)
    if ok and type(p) == "string" and p ~= "" then return p end
    local okDb, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if okDb and type(rows) == "table" then
        for _, r in ipairs(rows) do
            local okP, v = pcall(Osi.HasPassive, r[1], "Succubus_Desire")
            if okP and v == 1 then return r[1] end
        end
    end
    return nil
end

local function charmDelta(success, current)
    if success then
        return math.max(0, math.min(STEP, CAP - current))
    end
    return -math.max(0, math.min(STEP, current - FLOOR))
end

Ext.Osiris.RegisterListener("FlagSet", 3, "after", function(flag, trader, instance)
    local id = flagId(flag)
    if id ~= CHARM_SUCCESS and id ~= CHARM_FAILURE then return end
    local player = charmPlayer(instance)
    if not player then return end
    local ok, current = pcall(Osi.GetAttitudeTowardsPlayer, trader, player)
    current = (ok and tonumber(current)) or 0
    local delta = charmDelta(id == CHARM_SUCCESS, current)
    if delta ~= 0 then
        pcall(Osi.AddAttitudeTowardsPlayer, trader, player, delta)
    end
end)

-- SuccubusPlus: особенности, которые срабатывают по экстазу, смерти врага и шелковой нити (features.py, temptress.py):
--   Дар «Искушение» — враг, впавший в экстаз, получает SUCC_TEMPTED (атаки с помехой);
--   Дар «Пир»      — умер враг в экстазе -> суккуб получает SUCC_FEAST (временные ОЗ);
--   Кошмар «Упоение» — умер враг в экстазе -> SUCC_RAPTURE (доп. бонусное действие на ход);
--   «Отклик страсти» — враг впал в экстаз -> SUCC_ECHO суккубу (+5 самообладания);
--   вершины «Королева соблазна» и «Владычица кошмаров» — умер враг в экстазе -> SUCC_CHARM_BACK (+1 чары);
--   Королева пауков: «Сеть желаний» и «Королева паутины» — союзник под нитью (SpiderQueen_LINK_TARGET)
--   получает пассивки на время связи, «Королева паутины» еще и SUCC_WEB_QUEEN (10 временных ОЗ).
-- События Osiris: StatusApplied/StatusRemoved(объект, статус, причина, id), Died(персонаж), CombatEnded(бой).

local CLIMAX = "Succubus_Enemy_DesireMAX"
local LINK = "SpiderQueen_LINK_TARGET"
local CHARM_BACK = { "Passive_Succubus_TM_Queen", "Passive_Succubus_NM_Dread" }
local LINK_PASSIVES = { Passive_Succubus_SQ_Web = "Passive_Succubus_SQ_WebAlly",
                        Passive_Succubus_SQ_Queen = "Passive_Succubus_SQ_QueenAlly" }
local REWARD_MOD = 'a41f6c2e-9b37-4d58-b0e1-7c3d95f28e64'
Ext.Vars.RegisterModVariable(REWARD_MOD,'ClimaxRewards',{Server=true,Client=false,Persistent=true})

local function key(s)
    if type(s) ~= "string" then return nil end
    return string.lower(s:sub(-36))
end

local function has(c, passive)
    local ok, v = pcall(Osi.HasPassive, c, passive)
    return ok and v == 1
end

local function succubi()
    local out = {}
    local ok, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if ok and type(rows) == "table" then
        for _, r in ipairs(rows) do
            if has(r[1], "Succubus_Desire") then table.insert(out, r[1]) end
        end
    end
    return out
end

local function rewards()
    local vars=Ext.Vars.GetModVariables(REWARD_MOD)
    return vars.ClimaxRewards or {owners={},climaxed={},echo={},paid={}},vars
end
local function valid_owner(s,t)
    if not s or not has(s,'Succubus_Desire') then return false end
    local ok,value=pcall(function()
        local a,b=Ext.Entity.Get(s),Ext.Entity.Get(t)
        return a and b and a.TurnBased and b.TurnBased and a.TurnBased.Combat~=nil and
            tostring(a.TurnBased.Combat)==tostring(b.TurnBased.Combat) and
            Osi.IsEnemy(s,t)==1 and Osi.IsInCombat(s)==1 and Osi.IsInCombat(t)==1
    end)
    return ok and value
end
local function combat_of(c)
    local e=Ext.Entity.Get(c)
    return e and e.TurnBased and tostring(e.TurnBased.Combat) or nil
end
local function on_climax(object,causee)
    local k = key(object)
    if not k then return end
    local d,vars=rewards()
    local recorded=d.owners[k]
    if recorded and recorded.combat~=combat_of(object) then recorded=nil end
    local s=recorded and recorded.owner or causee
    if not valid_owner(s,object) then return end
    local combat=combat_of(s)
    if not combat then return end
    d.climaxed[k]={owner=s,combat=combat}
    local first=d.echo[k]~=combat
    d.echo[k]=combat; vars.ClimaxRewards=d
    if has(s,'Passive_SuccGift_Temptation') then pcall(Osi.ApplyStatus,object,'SUCC_TEMPTED',-1,1,s) end
    if first and has(s,'Passive_Succubus_PassionEcho') then pcall(Osi.ApplyStatus,s,'SUCC_ECHO',0.0,1,s) end
end

local function on_link(ally)
    for _, s in ipairs(succubi()) do
        for passive, ally_passive in pairs(LINK_PASSIVES) do
            if has(s, passive) and not has(ally, ally_passive) then pcall(Osi.AddPassive, ally, ally_passive) end
        end
        if has(s, "Passive_Succubus_SQ_Queen") then pcall(Osi.ApplyStatus, ally, "SUCC_WEB_QUEEN", 60.0, 1, s) end
    end
end

-- Record before the original Desire threshold handler emits its CLIMAX event.
Ext.Osiris.RegisterListener('StatusApplied',4,'before',function(object,status,causee)
    if status~='Succubus_Enemy_Desire_Counter' or not valid_owner(causee,object) then return end
    local d,vars=rewards()
    d.owners[key(object)]={owner=causee,combat=combat_of(causee)}
    vars.ClimaxRewards=d
end)
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
    if status == CLIMAX then on_climax(object,causee)
    elseif status == LINK then on_link(object) end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, causee, storyActionID)
    if status==CLIMAX or status=='Succubus_Enemy_Desire_Counter' then
        local d,vars=rewards()
        if status==CLIMAX then d.climaxed[key(object)]=nil
        else d.owners[key(object)]=nil end
        vars.ClimaxRewards=d
    end
    if status ~= LINK then return end
    for _, ally_passive in pairs(LINK_PASSIVES) do
        if has(object, ally_passive) then pcall(Osi.RemovePassive, object, ally_passive) end
    end
end)

local function death_rewards(character)
    local k = key(character)
    if not k then return end
    local d,vars=rewards(); local record=d.climaxed[k]
    local ok,current=pcall(Osi.HasActiveStatus,character,CLIMAX)
    if not record or not ok or current~=1 or d.paid[k]==record.combat then return end
    d.paid[k]=record.combat; vars.ClimaxRewards=d
    local s=record.owner
    if s and has(s,'Succubus_Desire') then
        if has(s, "Passive_SuccGift_Feast") then pcall(Osi.ApplyStatus, s, "SUCC_FEAST", 60.0, 1, s) end
        if has(s, "Passive_Succubus_NM_Rapture") then pcall(Osi.ApplyStatus, s, "SUCC_RAPTURE", 6.0, 1, s) end
        for _, p in ipairs(CHARM_BACK) do
            if has(s, p) then
                pcall(Osi.ApplyStatus, s, "SUCC_CHARM_BACK", 0.0, 1, s)
                break
            end
        end
    end
end
-- Dying is before status teardown. Died is only a duplicate-safe fallback.
Ext.Osiris.RegisterListener('Dying',1,'before',death_rewards)
Ext.Osiris.RegisterListener('Died',1,'after',death_rewards)

Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function(combat)
    local d,vars=rewards()
    for k,r in pairs(d.owners) do if r.combat==tostring(combat) then d.owners[k]=nil end end
    for k,r in pairs(d.climaxed) do if r.combat==tostring(combat) then d.climaxed[k]=nil end end
    for _,field in ipairs({'echo','paid'}) do
        for k,id in pairs(d[field]) do if id==tostring(combat) then d[field][k]=nil end end
    end
    vars.ClimaxRewards=d
end)

-- SuccubusPlus: вид крыльев на 8 уровне (Passive_Succubus_Wings, features.py) — Osi.AddCustomVisualOverride
-- с моделью крыльев Nikjima (Soaring Ambition), выбранной по расе и полу. Модель в паке одна на расу+пол
-- (взята из CC-записей крыльев в src/AscendedWings, слоты Tail/Beard/Hair — так их разложил автор модели);
-- своей отдельной модели хвоста в паке нет, поэтому на 5 уровне (хвост) вид не меняется, только умения.
-- Dwarf/Gnome/Halfling своей модели крыльев в паке не имеют — переиспользуют тот же визуал, что люди:
-- их скелет — уменьшенная копия человеческого со своим масштабным коэффициентом, подвешенная к кости
-- модель должна смасштабироваться вместе с ним (решение пользователя, нужна проверка пропорций в игре).
local WING_VISUALS = {
    HUMAN     = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    ELF       = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    DROWELF   = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    HALFELF   = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    TIEFLING  = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    GITHYANKI = { Male = "fc810087-a447-1d7f-3c36-e1bbcc6c34a8", Female = "f19948ae-06b4-6cf4-9c70-4d379e22a9dd" },
    HALFORC   = { Male = "560b3cab-dd31-966d-c683-41048afa5af0", Female = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db" },
    DRAGONBORN = { Male = "8ecfb8f0-051d-d8a8-191c-4aa4c72314ac", Female = "7cd75088-6659-ab0c-a425-e2554c32c6e9" },
    DWARF     = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    GNOME     = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
    HALFLING  = { Male = "a97bf4b9-6e05-1666-6dfa-f0e3e4c266db", Female = "9a11a25f-2644-3cf9-f71a-4fb3ac78d89c" },
}
local RACE_ORDER = { "HUMAN", "ELF", "DROWELF", "HALFELF", "TIEFLING", "GITHYANKI", "HALFORC", "DRAGONBORN",
                     "DWARF", "GNOME", "HALFLING" }

local winged = {}

-- Osiris принимает UUID CharacterCreationSharedVisual, а не VisualResource.
-- Эти служебные записи создает wing_overrides.py; отдельный слот Wings требует проверки в игре.
local WING_OVERRIDES = {
    ["560b3cab-dd31-966d-c683-41048afa5af0"] = "35f1bf5b-371d-5d7a-8759-e23ccb900de7",
    ["7cd75088-6659-ab0c-a425-e2554c32c6e9"] = "b84ce2bf-3e9e-5d5a-a417-c728fb8c123b",
    ["8ecfb8f0-051d-d8a8-191c-4aa4c72314ac"] = "5ec177bc-d33e-5483-ba16-23a804a1cdab",
    ["9a11a25f-2644-3cf9-f71a-4fb3ac78d89c"] = "b9741021-b3b0-57f9-9d12-fd011b09157b",
    ["a97bf4b9-6e05-1666-6dfa-f0e3e4c266db"] = "07b85bd2-f3f8-50af-82ce-cdda88be4d6b",
    ["f19948ae-06b4-6cf4-9c70-4d379e22a9dd"] = "52568fd9-c4a5-58a7-90fa-1b30d00cd659",
    ["fc810087-a447-1d7f-3c36-e1bbcc6c34a8"] = "c9093e5f-d478-555d-b94f-73b01303c361",
}

-- GUID из нативных Shared/SharedDev/Tags. Имена Tagged() в stats
-- не являются аргументами Osiris IsTagged(GUIDSTRING, TAG).
local TAGS = {
    HUMAN = "69fd1443-7686-4ca9-9516-72ec0b9d94d7",
    ELF = "351f4e42-1217-4c06-b47a-443dcf69b111",
    DROWELF = "a672ac1d-d088-451a-9537-3da4bf74466c",
    HALFELF = "34317158-8e6e-45a2-bd1e-6604d82fdda2",
    TIEFLING = "aaef5d43-c6f3-434d-b11e-c763290dbe0c",
    GITHYANKI = "677ffa76-2562-4217-873e-2253d4720ba4",
    HALFORC = "3311a9a9-cdbc-4b05-9bf6-e02ba1fc72a3",
    DRAGONBORN = "02e5e9ed-b6b2-4524-99cd-cb2bc84c754a",
    DWARF = "486a2562-31ae-437b-bf63-30393e18cbdd",
    GNOME = "1f0551f3-d769-47a9-b02b-5d3a8c51978c",
    HALFLING = "b99b6a5d-8445-44e4-ac58-81b2ee88aab1",
    FEMALE = "3806477c-65a7-4100-9f92-be4c12c4fa4f",
}

local function key(c)
    if type(c) ~= "string" then return nil end
    return string.lower(c:sub(-36))
end

local function has(c, passive)
    local ok, v = pcall(Osi.HasPassive, c, passive)
    return ok and v == 1
end

local function is_tagged(c, tag)
    local ok, v = pcall(Osi.IsTagged, c, TAGS[tag])
    return ok and v == 1
end

local function wing_visual(character)
    for _, race in ipairs(RACE_ORDER) do
        if is_tagged(character, race) then
            local byGender = WING_VISUALS[race]
            return is_tagged(character, "FEMALE") and byGender.Female or byGender.Male
        end
    end
    return nil
end

local function apply_wings(character)
    local k = key(character)
    if not k or winged[k] then return end
    local visual = wing_visual(character)
    if not visual then return end
    local override = WING_OVERRIDES[visual]
    if not override then return end
    local ok, err = pcall(Osi.AddCustomVisualOverride, character, override)
    if ok then
        winged[k] = true
    else
        Ext.Utils.PrintError("[SuccubusPlus Wings] " .. tostring(err))
    end
end

local function players()
    local out = {}
    local ok, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if ok and type(rows) == "table" then
        for _, r in ipairs(rows) do
            table.insert(out, r[1])
        end
    end
    return out
end

local function reconcile(character)
    if has(character, "Passive_Succubus_Wings") then
        apply_wings(character)
    else
        local k = key(character)
        if not k then return end
        -- Имя Ovirride (с опечаткой) соответствует нативному story_header.div.
        -- Удаляются только собственные UUID; внешность и хвост других модов не затрагиваются.
        for _, override in pairs(WING_OVERRIDES) do
            local ok, err = pcall(Osi.RemoveCustomVisualOvirride, character, override)
            if not ok then Ext.Utils.PrintError("[SuccubusPlus Wings] " .. tostring(err)) end
        end
        winged[k] = nil
    end
end

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", reconcile)
Ext.Osiris.RegisterListener("RespecCompleted", 1, "after", function(character)
    local k = key(character)
    if k then winged[k] = nil end
    reconcile(character)
end)

-- сохранения, где суккуб уже был 8 уровня до этого обновления мода: досрочно применить вид при загрузке
local function scan()
    for _, s in ipairs(players()) do reconcile(s) end
end

Ext.Events.SessionLoaded:Subscribe(function()
    winged = {}
    scan()
end)

-- При SessionLoaded игроки могут еще отсутствовать в DB_Players.
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", scan)

SUCC_HAS_OPHELIA = true
-- SuccubusPlus: нижнее белье не надето при создании (make_mod.EQUIPMENT надевает только оружие и
-- оба костюма — ARM_Vanity_Body_Leather_Rich и ARM_Vanity_Body_Rich_D, они общие для обоих полов и
-- вместе составляют один образ — при разделении на "один надет, другой в рюкзаке" вид оказался
-- неполным, см. отчет пользователя) — белье кладется в рюкзак одним разом на 1 уровне суккуба, чтобы
-- игрок сам решил, носить ли его вместо костюма. Обувь — по полу персонажа: у женщин каблуки
-- Ophelia's High Heels Collection (Silk_Heels + Silk_Heels_Camp), если пак стоит на диске в момент
-- сборки (SUCC_HAS_OPHELIA подставляет make_mod.py), у мужчин — как всегда, ванильные
-- ARM_Shoes + ARM_Camp_Sandals_A1 (решение пользователя: мужчинам каблуки не давать).
local COMMON = {
    "5fa043bf-0445-49ad-9e82-0df77c639fe2",  -- ARM_Underwear_Incubus
}
local VANILLA_SHOES = { "97f37571-35e8-4cc8-8b0d-ff92d20ae0bb", "37ceb8fb-7d41-4373-b31b-6fcc602955b4" }  -- ARM_Shoes, ARM_Camp_Sandals_A1
local OPHELIA_SHOES = { "3b2173cc-8a2e-4375-80f8-a193eea03adc", "3b2173cc-8a2e-4375-80f8-a193eea03adc" }  -- Silk_Heels, Silk_Heels_Camp (общий визуал)
local MARKER = "SUCC_STARTER_GEAR"

local function has(c, passive)
    local ok, v = pcall(Osi.HasPassive, c, passive)
    return ok and v == 1
end

local function has_status(c, status)
    local ok, v = pcall(Osi.HasActiveStatus, c, status)
    return ok and v == 1
end

local function is_tagged(c, tag)
    local ok, v = pcall(Osi.IsTagged, c, tag)
    return ok and v == 1
end

local function give_starter_gear(character)
    if has_status(character, MARKER) then return end
    for _, guid in ipairs(COMMON) do
        pcall(Osi.TemplateAddTo, guid, character, 1, 0)
    end
    local shoes = (SUCC_HAS_OPHELIA and is_tagged(character, "FEMALE")) and OPHELIA_SHOES or VANILLA_SHOES
    for _, guid in ipairs(shoes) do
        pcall(Osi.TemplateAddTo, guid, character, 1, 0)
    end
    pcall(Osi.ApplyStatus, character, MARKER, -1, 1, character)
end

local function succubi()
    local out = {}
    local ok, rows = pcall(function() return Osi.DB_Players:Get(nil) end)
    if ok and type(rows) == "table" then
        for _, r in ipairs(rows) do
            if has(r[1], "Succubus_Desire") then table.insert(out, r[1]) end
        end
    end
    return out
end

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
    if has(character, "Succubus_Desire") then give_starter_gear(character) end
end)

-- сохранения, где суккуб уже создан до этого обновления мода: досрочно выдать при загрузке
Ext.Events.SessionLoaded:Subscribe(function()
    for _, s in ipairs(succubi()) do give_starter_gear(s) end
end)

-- новая игра: LeveledUp не срабатывает на самом первом уровне, выданном в редакторе персонажа
-- (это не "получение уровня", а создание) — CharacterCreationFinished ловит именно этот момент
Ext.Osiris.RegisterListener("CharacterCreationFinished", 0, "after", function()
    for _, s in ipairs(succubi()) do give_starter_gear(s) end
end)

Ext.Require("Shared/DialogEligibility.lua")

-- Temptress: bounded status dispatch, no damage subscription or boss catalogue.
local MOD = 'a41f6c2e-9b37-4d58-b0e1-7c3d95f28e64'
local PREP, OWN, USED = 'SUCC_TM_PREPARED', 'SUCC_TM_OWN_TURN', 'SUCC_TM_KISS_USED'
Ext.Vars.RegisterModVariable(MOD, 'TemptressCombat', {Server=true, Client=false, Persistent=true})

local function key(s)
    return type(s)=='string' and s:sub(-36):lower() or nil
end
local function query(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
end
local function active(c,s) return query(Osi.HasActiveStatus,c,s)==1 end
local function has(c,p) return query(Osi.HasPassive,c,p)==1 end
local function trained(c,minimum,fallback)
    local e=Ext.Entity.Get(c)
    if e and e.Classes and e.Classes.Classes then
        for _,row in ipairs(e.Classes.Classes) do
            if tostring(row.ClassUUID)=='b448c84e-31f1-4b08-8b65-1d29b605afee' and
               tostring(row.SubClassUUID)=='114225df-5ffd-5f7b-8cda-5898d8b63834' then
                return row.Level>=minimum
            end
        end
        return false
    end
    return has(c,fallback)
end
local function data()
    local vars = Ext.Vars.GetModVariables(MOD)
    local d = vars.TemptressCombat or {prep={}, deceiver={}}
    return d, vars
end
local function turn(c)
    local e = Ext.Entity.Get(c)
    return e and e.TurnBased
end
local function own(c)
    local t=turn(c)
    return t and t.IsInCombat_M==true and t.IsActiveCombatTurn==true
end
local function pair(c,t)
    if not c or not t or query(Osi.IsDead,c)~=0 or query(Osi.IsDead,t)~=0 then return false end
    local a,b=turn(c),turn(t)
    return a and b and a.IsInCombat_M==true and b.IsInCombat_M==true and
        a.Combat~=nil and tostring(a.Combat)==tostring(b.Combat) and query(Osi.IsEnemy,c,t)==1
end
local function apply(c,s,d,source)
    Osi.RemoveStatus(c,s)
    Osi.ApplyStatus(c,s,d,1,source)
end
local function prepare(c,t)
    if not own(c) or not pair(c,t) or not trained(c,2,'Passive_Succubus_TM_Haze') then return end
    local d,vars=data()
    -- One current owner per target. Native status source is checked by the UI;
    -- this persistent ledger also validates the owner at execution time.
    Osi.RemoveStatus(t,PREP)
    if active(t,PREP) then return end
    Osi.ApplyStatus(t,PREP,12,1,c)
    if not active(t,PREP) then return end
    d.prep[key(t)]={owner=key(c),combat=tostring(turn(c).Combat)}
    vars.TemptressCombat=d
end
local function reserve(c,t)
    if not own(c) or not pair(c,t) or active(c,USED) or not trained(c,2,'Passive_Succubus_TM_Haze') then return false end
    Osi.ApplyStatus(c,USED,-1,1,c)
    return active(c,USED)
end

-- Called by the already-installed extraction classifier BEFORE RESOLVE.
function SUCC_TM_ValidateExtraction(c,t)
    return active(t,'Succubus_Enemy_DesireMAX') and reserve(c,t)
end

local pending = {}
local position_spells = {Target_Succubus_TailStrike=true, Zone_Succubus_WingBuffet=true, Zone_Succubus_WingBuffet_Small=true}
local function remember(c,spell,id)
    if position_spells[spell] and id and id~=0 and own(c) and trained(c,6,'Passive_Succubus_TM_OtherFace') then
        pending[tostring(id)]={owner=c,combat=tostring(turn(c).Combat),effect=spell=='Target_Succubus_TailStrike' and 'PRONE' or 'OFF_BALANCED'}
    end
end
Ext.Osiris.RegisterListener('UsingSpell',5,'before',function(c,spell,kind,element,id) remember(c,spell,id) end)
Ext.Osiris.RegisterListener('StatusApplied',4,'after',function(t,s,c,id)
    if s=='PRONE' or s=='OFF_BALANCED' then
        local p=pending[tostring(id)]
        if p and p.effect==s and key(p.owner)==key(c) and turn(c) and
            p.combat==tostring(turn(c).Combat) and trained(c,6,'Passive_Succubus_TM_OtherFace') then prepare(c,t) end
        return
    end
    if s=='SUCC_TM_PREP_REQUEST' then prepare(c,t); return end
    if s=='SUCC_TM_SHADOW_REQUEST' then
        if not own(c) or not pair(c,t) or not has(c,'Passive_Succubus_TM_ShadowStrike') or active(c,'SUCC_TM_SHADOW_USED') then return end
        Osi.ApplyStatus(c,'SUCC_TM_SHADOW_USED',-1,1,c)
        if not active(c,'SUCC_TM_SHADOW_USED') then return end
        prepare(c,t)
        apply(t,'SUCC_TM_SHADOW_RESOLVE',0,c)
    elseif s=='SUCC_TM_EARLY_REQUEST' then
        local d,vars=data()
        local p=d.prep[key(t)]
        if not p or p.owner~=key(c) or not active(t,PREP) or active(t,'Succubus_Enemy_DesireMAX') then return end
        if not turn(c) or p.combat~=tostring(turn(c).Combat) or not reserve(c,t) then return end
        -- Consume before damage can trigger another preparation.
        Osi.RemoveStatus(t,PREP)
        if active(t,PREP) then return end
        d.prep[key(t)]=nil; vars.TemptressCombat=d
        apply(t,'SUCC_TM_EARLY_RESOLVE',0,c)
    elseif s=='SUCC_TM_DECEIVER_REQUEST' then
        if not has(t,'Passive_Succubus_TM_Deceiver') or query(Osi.IsInCombat,t)~=1 then return end
        local d,vars=data(); local combat=tostring(turn(t).Combat)
        if d.deceiver[key(t)]==combat then return end
        d.deceiver[key(t)]=combat; vars.TemptressCombat=d
        apply(t,'SUCC_CHARM_BACK',0,t)
    end
end)

local function sync(c,reset)
    if not has(c,'Succubus_Desire') then
        Osi.RemoveStatus(c,OWN); Osi.RemoveStatus(c,'SUCC_TM_MASTERY'); Osi.RemoveStatus(c,'SUCC_TM_ENABLED'); return
    end
    if reset then
        Osi.RemoveStatus(c,USED); Osi.RemoveStatus(c,'SUCC_TM_SHADOW_USED')
    end
    if own(c) then Osi.ApplyStatus(c,OWN,-1,1,c) else Osi.RemoveStatus(c,OWN) end
    if trained(c,2,'Passive_Succubus_TM_Haze') then Osi.ApplyStatus(c,'SUCC_TM_ENABLED',-1,1,c)
    else Osi.RemoveStatus(c,'SUCC_TM_ENABLED') end
    if trained(c,6,'Passive_Succubus_TM_OtherFace') then
        Osi.ApplyStatus(c,'SUCC_TM_MASTERY',-1,1,c)
    else Osi.RemoveStatus(c,'SUCC_TM_MASTERY') end
end
Ext.Osiris.RegisterListener('TurnStarted',1,'after',function(c) sync(c,true) end)
Ext.Osiris.RegisterListener('TurnEnded',1,'after',function(c)
    Osi.RemoveStatus(c,OWN)
    Osi.RemoveStatus(c,'SUCC_TM_TRAIL')
    for id,p in pairs(pending) do if key(p.owner)==key(c) then pending[id]=nil end end
end)
Ext.Events.SessionLoaded:Subscribe(function()
    -- Only the small party list, once on load. Do not clear USED on reload.
    local rows=query(function() return Osi.DB_Players:Get(nil) end) or {}
    for _,r in ipairs(rows) do sync(r[1],false) end
end)
Ext.Osiris.RegisterListener('Died',1,'after',function(c)
    local d,vars=data(); d.prep[key(c)]=nil
    for target,p in pairs(d.prep) do
        if p.owner==key(c) then Osi.RemoveStatus(target,PREP); d.prep[target]=nil end
    end
    vars.TemptressCombat=d
end)
Ext.Osiris.RegisterListener('CombatEnded',1,'after',function(combat)
    local d,vars=data()
    for target,p in pairs(d.prep) do
        if p.combat==tostring(combat) then Osi.RemoveStatus(target,PREP); d.prep[target]=nil end
    end
    for owner,id in pairs(d.deceiver) do if id==tostring(combat) then d.deceiver[owner]=nil end end
    vars.TemptressCombat=d
    for id,p in pairs(pending) do if p.combat==tostring(combat) then pending[id]=nil end end
end)

-- BEGIN SUCCUBUS EXTRACTION GUARD
local extraction_legendary_passives = {
    "LegendaryAction_AdamantineGolem_KineticArmor",
    "LegendaryAction_Apostle_Gaze",
    "LegendaryAction_Automaton_ChainStaticBolt",
    "LegendaryAction_Bulette_DiamondScalesBurst",
    "LegendaryAction_EyebeamNova_Counter_Logic",
    "LegendaryAction_FOR_Owlbear",
    "LegendaryAction_FOR_SpiderQueen",
    "LegendaryAction_GOB_Dror",
    "LegendaryAction_HAG_Counterswap",
    "LegendaryAction_HAG_Counterswap_Double",
    "LegendaryAction_Interrupt_CRE_GithyankiInquisitor_VlaakithsMindSword",
    "LegendaryAction_LOW_BhaalTemple_MarkedForMurder",
    "LegendaryAction_LOW_BhaalsRetribution_Orin",
    "LegendaryAction_LOW_BhaalsRetribution_Sarevok",
    "LegendaryAction_LOW_BloodSwipe_Orin",
    "LegendaryAction_LOW_Cazador_BatSwarm",
    "LegendaryAction_LOW_Cazador_BatSwarm_Block",
    "LegendaryAction_LOW_Cazador_BatSwarm_Huge",
    "LegendaryAction_LOW_Cazador_BatSwarm_Large",
    "LegendaryAction_LOW_Cazador_BatSwarm_Small",
    "LegendaryAction_LOW_FatherCarrion_SpiritParade",
    "LegendaryAction_LOW_GithyankiPaladin_VlaakithsCry",
    "LegendaryAction_LOW_GithyankiProdigy_PacifyingAura",
    "LegendaryAction_LOW_Raphael",
    "LegendaryAction_LOW_Raphael_Ascended",
    "LegendaryAction_LOW_Viconia_DarkSentinel",
    "LegendaryAction_LOW_Viconia_HeartWrench",
    "LegendaryAction_MOO_Ketheric_GeneralsWrath",
    "LegendaryAction_MidasWrath_TollCollector",
    "LegendaryAction_MixChangeExplosion_Brewer",
    "LegendaryAction_Oliver_Cursedome",
    "LegendaryAction_SCL_Drider_PsionicVengeance",
    "LegendaryAction_SHA_Necromancer_LandOfTheDead",
    "LegendaryAction_SHA_Necromancer_SpectralForm",
    "LegendaryAction_SHA_Necromancer_SpectralForm_Technical",
    "LegendaryAction_SHA_Orthon",
    "LegendaryAction_ShamblingMound_OverwhelmingGrowth",
    "LegendaryAction_Surgeon_GrapplingArm",
    "LegendaryAction_Surgeon_MindScreech",
    "LegendaryAction_TWN_VlaakithsKillers_SoulSyphon",
    "LegendaryAction_UND_Nere_PsychicMirror",
    "LegendaryAction_WYR_DivineBeckoning_Gortash",
    "LegendaryActions",
    "LegendaryResistance",
}
local extraction_legendary_statuses = {
    "LEGENDARYACTION_ADAMANTINEGOLEM_KINETICARMOR",
    "LEGENDARYACTION_APOSTLE_GAZE",
    "LEGENDARYACTION_AUTOMATON_CHAINSTATICBOLT",
    "LEGENDARYACTION_BULETTE_DIAMONDSCALESBURST",
    "LEGENDARYACTION_CRE_GITHYANKIINQUISITOR_VLAAKITHSMINDSWORD",
    "LEGENDARYACTION_CRE_GITHYANKIINQUISITOR_VLAAKITHSMINDSWORD_2",
    "LEGENDARYACTION_FOR_OWLBEAR_CALLCONSORT",
    "LEGENDARYACTION_FOR_SPIDERQUEEN_SILKTOMB",
    "LEGENDARYACTION_GOB_DROR_GALVANISE",
    "LEGENDARYACTION_HAG_COUNTERSWAP",
    "LEGENDARYACTION_HAG_COUNTERSWAP_DOUBLE",
    "LEGENDARYACTION_LOW_BHAALTEMPLE_MARKEDFORMURDER",
    "LEGENDARYACTION_LOW_BLOODSWIPE_ORIN",
    "LEGENDARYACTION_LOW_CAZADOR_BATSWARM",
    "LEGENDARYACTION_LOW_CAZADOR_BATSWARM_HEAL",
    "LEGENDARYACTION_LOW_CAZADOR_BATSWARM_HUGE",
    "LEGENDARYACTION_LOW_CAZADOR_BATSWARM_LARGE",
    "LEGENDARYACTION_LOW_FATHERCARRION_SPIRITPARADE",
    "LEGENDARYACTION_LOW_GITHYANKIPALADIN_VLAAKITHSCRY",
    "LEGENDARYACTION_LOW_GITHYANKIPRODIGY_PACIFYINGAURA",
    "LEGENDARYACTION_LOW_ORIN_BHAALSRETRIBUTION",
    "LEGENDARYACTION_LOW_RAPHAEL_BEGUILINGREBUKE",
    "LEGENDARYACTION_LOW_RAPHAEL_CASCADEOFSOULS",
    "LEGENDARYACTION_LOW_SAREVOK_BHAALSRETRIBUTION",
    "LEGENDARYACTION_LOW_VICONIA_DARKSENTINEL",
    "LEGENDARYACTION_LOW_VICONIA_HEARTWRENCH",
    "LEGENDARYACTION_MIDASWRATH_TOLLCOLLECTOR",
    "LEGENDARYACTION_MIXCHANGEEXPLOSION_BREWER",
    "LEGENDARYACTION_MOO_KETHERIC_GENERALSWRATH",
    "LEGENDARYACTION_OLIVER_CURSEDOME",
    "LEGENDARYACTION_SCL_DRIDER_PSIONICVENGEANCE",
    "LEGENDARYACTION_SHA_NECROMANCER_LANDOFTHEDEAD",
    "LEGENDARYACTION_SHA_NECROMANCER_SPECTRALFORM",
    "LEGENDARYACTION_SHA_ORTHON_BLINDINGPURSUIT",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA_COUNTER_0",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA_COUNTER_1",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA_COUNTER_2",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA_COUNTER_3",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA_COUNTER_4",
    "LEGENDARYACTION_SPECTATOR_EYEBEAMNOVA_COUNTER_5",
    "LEGENDARYACTION_STATUS",
    "LEGENDARYACTION_TWN_GRAPPLINGARM_SURGEON",
    "LEGENDARYACTION_TWN_MINDSCREECH_SURGEON",
    "LEGENDARYACTION_TWN_SOULSYPHON_VLAAKITHKILLERS",
    "LEGENDARYACTION_UND_NERE_PSYCHICMIRROR",
    "LEGENDARYACTION_WYR_DIVINEBECKONING_GORTASH",
    "LEGENDARY_RESISTANCE",
    "LEGENDARY_RESISTANCE_CHARISMA",
    "LEGENDARY_RESISTANCE_CONSTITUTION",
    "LEGENDARY_RESISTANCE_CROWD_CONTROL",
    "LEGENDARY_RESISTANCE_DEXTERITY",
    "LEGENDARY_RESISTANCE_INTELLIGENCE",
    "LEGENDARY_RESISTANCE_STRENGTH",
    "LEGENDARY_RESISTANCE_WISDOM",
}
-- Boss stat names checked against local Patch 8 Character records. Honour
-- minions (ordinary spiders, goblins, nurses and mind swords) are excluded.
local bosses = {}
for name in ([[
UND_AdamantineGolem UND_Nere SHA_Necromancer SCL_DriderCaravan_Drider
Brewer TollCollector GOB_Hobgoblin_Boss GLO_Cazador GLO_Raphael
LOW_Raphael_Monster_Form_Stats Spectator Spectator_Strong Orthon
Spider_Phase_Queen FOR_Owlbear FOR_Owlbear_Daddy LOW_Githyanki_Prodigy
LOW_HouseOfGrief_Viconia LOW_FatherCarrion GLO_Orin GLO_Orin_Slayer
LOW_Sarevok Steel_Watcher_Quadruped Bulette SCL_Oliver END_Netherbrain_Face
SCL_Ketheric ApostleOfMyrkul HAG_AuntieEthel CRE_Githyanki_Inquisitor
TWN_Githyanki_Warlock ShamblingMound_Dark LOW_Githyanki_Paladin Surgeon
WYR_Gortash Dragon_BronzeSkeletal Dragon_AdultRed
]]):gmatch('%S+') do bosses[name] = true end

local boss_ids = {
    ["05c338d9-4590-4c4b-b87e-8c27ea2c2b18"] = true,
    ["10403a03-aa9c-4c68-8a52-cbb381627906"] = true,
    ["2a5997fc-5f2a-4a13-b309-bed16da3b255"] = true,
    ["307934b5-6fb5-4fdc-a7ff-433a7ba175b3"] = true,
    ["3588d24b-ead5-4e87-9ff9-3eb508466a16"] = true,
    ["37223ef4-2293-4a2a-a1e2-88367d241fcf"] = true,
    ["3b460226-8ca2-4bbc-9bd7-8bb947aa2c06"] = true,
    ["4d9e3db3-9a78-4f4b-8101-1dd73c0f3be5"] = true,
    ["5038c0f2-0022-4699-82ce-a319b30616bb"] = true,
    ["53651a9f-7ea8-444f-ba2d-224390b72f7d"] = true,
    ["54467aa9-33dd-41c4-bd77-87a71ed22c16"] = true,
    ["67770922-5e0a-40c5-b3f0-67e8eb50493a"] = true,
    ["8e75eb3b-7551-485e-8f98-2bf2e51d3e84"] = true,
    ["b983c336-9a14-4e9b-adb9-4689e7e0afa9"] = true,
    ["e58b8b34-038b-4858-b817-c2a8096a9381"] = true,
    ["e6b2f3ba-2d02-4507-8680-6047322e1a4b"] = true,
    ["ed103005-fd71-457d-ae6c-39654bbd8f2e"] = true,
    ["fd75dc6e-6a8d-4d9d-8cfc-ca4ff5da53d7"] = true,
}
local boss_templates = {
    ["187952ff-f290-417d-8108-652d9bb61a52"] = true,
    ["2f1d1763-9f7d-45f6-a102-5bd388fb7e86"] = true,
    ["3333491e-dc88-4b61-8539-fed9f3af5ca1"] = true,
    ["368935f0-4a15-4122-b101-9174dee70163"] = true,
    ["514fff43-9a2f-4984-b3d1-2d53cf3fc15f"] = true,
    ["6047fffd-f7d3-4956-8b7a-ef82c08f8867"] = true,
    ["6145f104-895d-4023-8fc7-1ba2cea1480a"] = true,
    ["64383f18-9830-40c2-8681-657cf36afc05"] = true,
    ["69f4c031-8d4e-41c5-997b-4d39a763ac66"] = true,
    ["7821978d-c720-4651-9693-936960145636"] = true,
    ["8c85932d-12dd-4046-a694-6534071470a2"] = true,
    ["a400d55e-e453-4c80-9cdb-fdde663c4556"] = true,
    ["b9eeaebb-9b00-4552-940f-5d829a66e8cb"] = true,
    ["bc4b5efc-cbd3-4f8f-a31e-d37f801a038c"] = true,
    ["ced6bfeb-8f6f-47d0-943f-77833f643318"] = true,
    ["f8a1cb8d-3e40-4c33-8a92-92ee742b6439"] = true,
}

local function uuid(value)
    return type(value) == "string" and value:sub(-36):lower() or ""
end

local spells = {
    Target_Succubus_AirKiss = true, Succubus_TakingHeart = true,
    Target_Succubus_DrainingKiss = true, Target_Succubus_DrainingKiss_Greedy = true,
}

local function mark(target)
    -- Revoke permission before reclassification. Unknown/error is protected.
    local revoked = pcall(Osi.RemoveStatus, target, 'SUCCUBUS_EXTRACTION_ALLOWED')
    local checked, remaining = pcall(Osi.HasActiveStatus, target, 'SUCCUBUS_EXTRACTION_ALLOWED')
    if not revoked or not checked or remaining ~= 0 then
        Osi.ApplyStatus(target, 'SUCCUBUS_EXTRACTION_GUARD', -1, 1, target)
        return false
    end
    local ok, stat = pcall(Osi.GetStatString, target)
    -- Unknown stat lookup must not allow an unclassified target to be killed.
    local template_ok, template = pcall(Osi.GetTemplate, target)
    local protected = not ok or type(stat) ~= 'string' or stat == '' or
        not template_ok or type(template) ~= 'string' or #uuid(template) ~= 36 or
        bosses[stat] or boss_ids[uuid(target)] or
        boss_templates[uuid(template)]
    if not protected then
        for _, name in ipairs(extraction_legendary_passives) do
            local success, result = pcall(Osi.HasPassive, target, name)
            if not success or (result ~= 0 and result ~= 1) or result == 1 then
                protected = true
                break
            end
        end
    end
    if not protected then
        for _, name in ipairs(extraction_legendary_statuses) do
            local success, result = pcall(Osi.HasActiveStatus, target, name)
            if not success or (result ~= 0 and result ~= 1) or result == 1 then
                protected = true
                break
            end
        end
    end
    if protected then
        Osi.ApplyStatus(target, 'SUCCUBUS_EXTRACTION_GUARD', -1, 1, target)
    else
        Osi.RemoveStatus(target, 'SUCCUBUS_EXTRACTION_GUARD')
        Osi.ApplyStatus(target, 'SUCCUBUS_EXTRACTION_ALLOWED', -1, 1, target)
    end
    return true
end

Ext.Osiris.RegisterListener('EnteredCombat', 2, 'after', function(character)
    mark(character)
end)
Ext.Osiris.RegisterListener('StatusApplied', 4, 'before', function(character, status)
    if status == 'Succubus_Enemy_DesireMAX' then mark(character) end
end)
-- CHECK is inert. Only after synchronous classification has completed do we
-- start a separate native status application. No global damage listener, no
-- character search, and no legendary catalogue in a stats expression.
local resolving = {}
Ext.Osiris.RegisterListener('StatusApplied', 4, 'after', function(character, status, causee)
    local temptress = status == 'SUCC_TM_EXTRACT_CHECK'
    if status ~= 'SUCCUBUS_EXTRACTION_CHECK' and not temptress then return end
    local k = uuid(character)
    if resolving[k] or type(causee) ~= 'string' or causee == '' or
       uuid(causee) == '00000000-0000-0000-0000-000000000000' then return end
    resolving[k] = true
    local ok, err = pcall(function()
        local resolve = temptress and 'SUCC_TM_EXTRACT_RESOLVE' or 'SUCCUBUS_EXTRACTION_RESOLVE'
        Osi.RemoveStatus(character, status)
        Osi.RemoveStatus(character, resolve)
        if temptress and (not SUCC_TM_ValidateExtraction or not SUCC_TM_ValidateExtraction(causee,character)) then return end
        if not mark(character) then return end
        Osi.ApplyStatus(character, resolve, 0, 1, causee)
    end)
    resolving[k] = nil
    if not ok then _P('[SuccubusPlus] Extraction blocked: ' .. tostring(err)) end
end)
-- Also covers a save loaded mid-combat, without waiting for another turn.
Ext.Osiris.RegisterListener('UsingSpellOnTarget', 6, 'before', function(caster, target, spell)
    if spells[spell] then mark(target) end
end)
