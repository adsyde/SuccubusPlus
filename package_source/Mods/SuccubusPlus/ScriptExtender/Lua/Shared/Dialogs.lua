-- Правленые диалоги (сервер и клиент): какой вариант включить, решает DialogKit по включённым модам
-- и порядку загрузки. DialogKit.lua и DialogKitManifest.lua кладёт сборка (make_mod.py).
local DialogKit = Ext.Require("Shared/DialogKit.lua")
Ext.Require("Shared/DialogKitManifest.lua")

DialogKit.Apply("a41f6c2e-9b37-4d58-b0e1-7c3d95f28e64", DialogKitManifest, function(fmt, ...)
    _P("[SuccubusPlus] DialogKit: " .. string.format(fmt, ...))
end)
