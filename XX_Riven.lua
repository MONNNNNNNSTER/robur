if Player.CharName ~= "Riven" then return end

----------------------------------------------------------------------------------------------

module("XX_Riven", package.seeall, log.setup)
clean.module("XX_Riven", clean.seeall, log.setup)

local VERSION = "1.0"
local LAST_UPDATE = "11/05/2021"

----------------------------------------------------------------------------------------------

local SDK = _G.CoreEx

local DamageLib = _G.Libs.DamageLib
local CollisionLib = _G.Libs.CollisionLib
local Menu = _G.Libs.NewMenu
local Prediction = _G.Libs.Prediction
local TargetSelector = _G.Libs.TargetSelector
local Orbwalker = _G.Libs.Orbwalker
local Spell = _G.Libs.Spell
local TS = _G.Libs.TargetSelector()

local ObjectManager = SDK.ObjectManager
local EventManager = SDK.EventManager
local Input = SDK.Input
local Game = SDK.Game
local Geometry = SDK.Geometry
local Renderer = SDK.Renderer
local Enums = SDK.Enums

local Events = Enums.Events
local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local HitChance = Enums.HitChance
local DamageTypes = Enums.DamageTypes
local Vector = Geometry.Vector

local pairs = _G.pairs
local type = _G.type
local tonumber = _G.tonumber
local math_abs = _G.math.abs
local math_huge = _G.math.huge
local math_min = _G.math.min
local math_deg = _G.math.deg
local math_sin = _G.math.sin
local math_cos = _G.math.cos
local math_acos = _G.math.acos
local math_pi = _G.math.pi
local math_pi2 = 0.01745329251
local os_clock = _G.os.clock
local string_format = _G.string.format
local table_remove = _G.table.remove

local _Q = SpellSlots.Q
local _W = SpellSlots.W
local _E = SpellSlots.E
local _R = SpellSlots.R

local ItemID = require("lol/Modules/Common/ItemID")
local Passive_stacks = 0
local IsUlted = false

---@type fun(unit: GameObject, buff: BuffInst):void
----------------------------------------------------------------------------------------------

local Q = Spell.Skillshot({
    ["Slot"] = _Q,
    ["SlotString"] = "Q",
    ["Range"] = 300,
    ["Delay"] = 0.3125,
    ["Radius"] = 250
})

local W = Spell.Active({
    ["Slot"] = _W,
    ["SlotString"] = "W",
    ["Range"] = 0,
    ["Delay"] = 0.25,
    ["EffectRadius"] = 200,
    ["Type"] = "Circular"
})
local E = Spell.Skillshot({
    ["Slot"] = _E,
    ["SlotString"] = "E",
    ["Range"] = 250,
    ["Delay"] = 0
})
local R = Spell.Skillshot({
    ["Slot"] = _R,
    ["SlotString"] = "R",
    ["Range"] = 1100,
    ["Speed"] = 1600,
    ["Delay"] = 0.25,
    ["Collisions"] = {WindWall = true},
    ["UseHitbox"] = true,
    ["ConeAngleRad"] = 18,
    ["Type"] = "Cone"
})

----------------------------------------------------------------------------------------------

local LastCastT = {[_Q] = 0, [_W] = 0, [_E] = 0, [_R] = 0}

local DrawSpellTable = {Q, W, E, R}
local TickCount = 0

---@type fun(a: number, r: number, g: number, b: number):number
local ARGB = function(a, r, g, b)
    return tonumber(string_format("0x%02x%02x%02x%02x", r, g, b, a))
end

---@type fun():boolean
local GameIsAvailable = function()
    return not Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or
               Player.IsRecalling
end

---@type fun(object: GameObject, range: number, from: Vector):boolean
local IsValidTarget = function(object, range, from)
    local from = from or Player.Position
    return TS:IsValidTarget(object, range, from)
end

---@type fun(obj: GameObject):boolean
local IsValidObject = function(obj) return
    obj and obj.IsValid and not obj.IsDead end

---@type fun(spell: SpellBase, condition: function):boolean
local IsReady = function(spell, condition)
    local isReady = spell:IsReady()
    if condition ~= nil then
        return isReady and
                   (type(condition) == "function" and condition() or
                       type(condition) == "boolean" and condition)
    end
    return isReady
end

---@type fun(value: number):boolean
local IsEnoughMana = function(value)
    local manaPct = Player.AsAttackableUnit.ManaPercent
    return manaPct > value * 0.01
end

---@type fun(slot: number, position: Vector|GameObject, condition: function|boolean):void
local CastSpell = function(slot, position, condition)
    local tick = os_clock()
    if LastCastT[slot] + 0.050 < tick then
        if Input.Cast(slot, position) then
            LastCastT[slot] = tick
            if condition ~= nil then
                return true and
                           (type(condition) == "function" and condition() or
                               type(condition) == "boolean" and condition)
            end
            return true
        end
    end
    return false
end

---@type fun(id: string):void
local AddWhiteListMenu = function(name, id)
    Menu.NewTree(id .. "WhiteList", name, function()
        local heroes = ObjectManager.Get("enemy", "heroes")
        for k, hero in pairs(heroes) do
            local heroAI = hero.AsAI
            Menu.Checkbox(id .. "WhiteList" .. heroAI.CharName, heroAI.CharName,
                          true)
        end
    end)
end

---@type fun(id: string):boolean|number
local GetMenuValue = function(id)
    local menuValue = Menu.Get(id, true)
    if menuValue then return menuValue end
    return false
end

---@type fun(id: string):boolean|number
local GetKeyMenuValue = function(id)
    local menuValue = Menu.GetKey(id, true)
    if menuValue then return menuValue end
    return false
end

---@type fun(slot: string, mode: string, heroName: string):boolean
local GetWhiteListValue = function(slot, mode, heroName)
    return GetMenuValue(mode .. slot .. "WhiteList" .. heroName)
end

----------------------------------------------------------------------------------------------

---@type fun(spell: table, target: GameObject):number
local GetDamage = function(spell, target)
    local R_damages = 0
    local slot = spell.Slot
    local myLevel = Player.Level
    local level = Player.AsHero:GetSpell(slot).Level
    local missing_health = (target.AsAttackableUnit.Health * 100) /
                               target.AsAttackableUnit.MaxHealth
    -- print(missing_health)
    if slot == _R and IsReady(R) then
        local flatAD = Player.TotalAD
        local RRawDamage = {100, 150, 200}
        if IsValidTarget(target) then
            R_damages = (RRawDamage[level] + (0.6 * flatAD)) +
                            ((2.667 / 100) * missing_health *
                                (RRawDamage[level] + (0.6 * flatAD)))
            -- print(R_damages)
        end
        return R_damages
    end
end

---@type fun(unit: GameObject):void	
----------------------------------------------------------------------------------------------

local function GetPassiveStacks()
    local buff = Player:GetBuff("RivenPassiveAABoost")
    if buff then return buff.Count end
end

local function GetWindSlash()
    local buff = Player:GetBuff("rivenwindslashready")
    if buff then
        return true
    else
        return false
    end
end

local HitChanceList = {
    "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh",
    "Dashing", "Immobile"
}

Menu.RegisterMenu("XX Riven", "XX Riven", function()
    Menu.Checkbox("ScriptEnabled", "Script Enabled", true)

    Menu.Separator()

    Menu.ColoredText("Spell Settings", ARGB(255, 255, 255, 255), true)

    Menu.Separator()

    Menu.NewTree("Q", "[Q] Broken Wings", function()
        Menu.NewTree("ComboQ", "Combo Options",
                     function()
            Menu.Checkbox("ComboUseQ", "Enabled", true)
        end)
        Menu.NewTree("WaveClearQ", "Wave Clear Options", function()
            Menu.Checkbox("WaveClearUseQ", "Enabled", true)
        end)
        Menu.NewTree("DrawingsQ", "Drawings", function()
            Menu.Checkbox("DrawQ", "Draw Range", true)
            Menu.ColorPicker("DrawColorQ", "Color", ARGB(255, 217, 55, 55))
        end)
    end)

    Menu.NewTree("W", "[W] Ki Burst", function()
        Menu.NewTree("ComboW", "Combo Options",
                     function()
            Menu.Checkbox("ComboUseW", "Enabled", true)
        end)
        Menu.NewTree("WaveClearW", "Wave Clear Options", function()
            Menu.Checkbox("WaveClearUseW", "Enabled", true)
        end)
        Menu.NewTree("DrawingsW", "Drawings", function()
            Menu.Checkbox("DrawW", "Draw Range", true)
            Menu.ColorPicker("DrawColorW", "Color", ARGB(255, 255, 255, 255))
        end)
    end)

    Menu.NewTree("E", "[E] Valor", function()
        Menu.NewTree("ComboE", "Combo Options",
                     function()
            Menu.Checkbox("ComboUseE", "Enabled", true)
        end)
        Menu.NewTree("WaveClearE", "Wave Clear Options", function()
            Menu.Checkbox("WaveClearUseE", "Enabled", true)
        end)
        Menu.NewTree("DrawingsE", "Drawings", function()
            Menu.Checkbox("DrawE", "Draw Range", true)
            Menu.ColorPicker("DrawColorE", "Color", ARGB(255, 255, 255, 255))
        end)
    end)

    Menu.NewTree("R", "[R] Blade of the Exile", function()
        Menu.NewTree("ComboR", "Combo Options", function()
            Menu.Checkbox("ComboUseR",
                          "Enabled (Activating Again when killable)", true)
            Menu.Slider("RHitchance", "Hit chance", 60, 20, 100, 1)
        end)
        Menu.NewTree("DrawingsR", "Drawings", function()
            Menu.Checkbox("DrawR", "Draw Range", true)
            Menu.ColorPicker("DrawColorR", "Color", ARGB(255, 255, 255, 255))
        end)
    end)

    Menu.Separator()

    Menu.ColoredText("Script Information", ARGB(255, 255, 255, 255), true)

    Menu.Separator()

    Menu.ColoredText("Version: " .. VERSION, ARGB(255, 51, 204, 255))
    Menu.ColoredText("Last Update: " .. LAST_UPDATE, ARGB(255, 51, 204, 255))

    Menu.Separator()
end)

----------------------------------------------------------------------------------------------

---@type fun():void
local Combo = function()
    Passive_stacks = GetPassiveStacks()
    local count = 0
    local heroes = ObjectManager.Get("enemy", "heroes")

    if IsReady(R) and GetMenuValue("ComboUseR") then
        if GetWindSlash() then
            for i, hero in pairs(heroes) do
                local hero = hero.AsAI
                if hero and IsValidTarget(hero, R.Range) then
                    local predi = Prediction.GetPredictedPosition(hero, R,
                                                                  Player.Position)
                    local dist = Player.Position:Distance(hero.Position)
                    local damage = GetDamage(R, hero)
                    local true_damage = DamageLib.CalculatePhysicalDamage(
                                            Player, hero, damage)
                    if predi and true_damage > hero.AsAttackableUnit.Health and
                        dist <= R.Range and predi.HitChance >
                        (GetMenuValue("RHitchance") / 100) then
                        CastSpell(_R, predi.CastPosition)
                    end
                end
            end
        else
            for i, hero in pairs(heroes) do
                local hero = hero.AsAI
                if hero and IsValidTarget(hero, (2 * Q.Range)) then
                    local dist = Player.Position:Distance(hero.Position)
                    if dist <= R.Range then
                        CastSpell(_R, Player.Position)
                    end
                end
            end
        end
    end

    if IsReady(W) and GetMenuValue("ComboUseW") then
        for i, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, W.EffectRadius) then
                local dist = Player.Position:Distance(hero.Position)
                if dist <= W.EffectRadius then CastSpell(_W) end
            end
        end
    end

    if IsReady(Q) and GetMenuValue("ComboUseQ") then
        for i, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, (Q.Range + 300)) then
                local dist = Player.Position:Distance(hero.Position)
                if dist <= (Q.Range + 300) then
                    if GetPassiveStacks() and GetPassiveStacks() >= 2 then
                        if dist < Orbwalker.GetTrueAutoAttackRange(Player, hero) then
                            Input.Attack(hero.Position)
                        else
                            Orbwalker.MoveTo(Player.Position)
                            CastSpell(_Q, hero.Position)
                            Orbwalker.MoveTo(nil)
                        end

                    else
                        Orbwalker.MoveTo(hero)
                        CastSpell(_Q, hero.Position)
                        Orbwalker.MoveTo(nil)
                    end
                end
            end
        end
    end

    if IsReady(E) and GetMenuValue("ComboUseE") then
        for i, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, E.Range + 250) then
                local dist = Player.Position:Distance(hero.Position)
                if dist <= (E.Range + 250) then
                    CastSpell(_E, hero.Position)
                end
            end
        end
    end

end

local function ClearW(target)
    if IsReady(W) and GetMenuValue("WaveClearUseW") then
        for i, hero in pairs(target) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, W.EffectRadius) then
                local dist = Player.Position:Distance(hero.Position)
                if dist <= W.EffectRadius then CastSpell(_W) end
            end
        end
    end
end

local function ClearQ(target)
    for i, hero in pairs(target) do
        local hero = hero.AsAI
        if hero and IsValidTarget(hero, (Q.Range)) then
            local dist = Player.Position:Distance(hero.Position)
            if dist <= (Q.Range) then
                if GetPassiveStacks() and GetPassiveStacks() >= 1 then
                    if dist < Orbwalker.GetTrueAutoAttackRange(Player, hero) then
                        Input.Attack(hero.Position)
                    else
                        Orbwalker.MoveTo(Player.Position)
                        CastSpell(_Q, hero.Position)
                        Orbwalker.MoveTo(nil)
                    end
                else
                    Orbwalker.MoveTo(hero)
                    CastSpell(_Q, hero.Position)
                    Orbwalker.MoveTo(nil)
                end
            end
        end
    end
end

local function ClearE(target)
    if IsReady(E) and GetMenuValue("WaveClearUseE") then
        for i, hero in pairs(target) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, E.Range) then
                local dist = Player.Position:Distance(hero.Position)
                if dist <= E.Range then
                    CastSpell(_E, hero.Position)
                end
            end
        end
    end
end

local Waveclear = function()
    local minions = ObjectManager.Get("enemy", "minions")
    local jgl_neut = ObjectManager.Get("neutral", "minions")
    Passive_stacks = GetPassiveStacks()

    ClearW(minions)
    ClearW(jgl_neut)

    ClearQ(minions)
    ClearQ(jgl_neut)

    ClearE(minions)
    ClearE(jgl_neut)

end

---@type fun():void
local LastHit = function() end

---@type fun():void
local AutoMode = function() end

----------------------------------------------------------------------------------------------

---@type fun():void
local OnTick = function()
    if not GetMenuValue("ScriptEnabled") then return end

    if GameIsAvailable() then
        AutoMode()

        local activeMode = Orbwalker.GetMode()
        if activeMode == "Combo" then
            Combo()
        elseif activeMode == "Lasthit" then
            LastHit()
        elseif activeMode == "Waveclear" then
            Waveclear()
            if LastHit() then return end
        end
    end

    local tick = os_clock()
    if TickCount < tick then TickCount = tick + 0.5 end
end

---@type fun():void
local OnDraw = function()
    if not GetMenuValue("ScriptEnabled") then return end
    local myHeroPos = Player.Position
    if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
        for i = 1, #DrawSpellTable do
            local spell = DrawSpellTable[i]
            if spell then
                local menuValue = GetMenuValue("Draw" .. spell.SlotString)
                if menuValue then
                    local colorValue = GetMenuValue(
                                           "DrawColor" .. spell.SlotString)
                    if colorValue then
                        Renderer.DrawCircle3D(myHeroPos, spell.Range, 30, 2,
                                              colorValue)
                    end
                end
            end
        end
    end
    if IsReady(R) then
        local heroes = ObjectManager.Get("enemy", "heroes")
        for k, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero.IsVisible and hero.IsOnScreen and not hero.IsDead then

                local damage = GetDamage(R, hero)
                local true_damage = DamageLib.CalculatePhysicalDamage(Player,
                                                                      hero,
                                                                      damage)
                local hpBarPos = hero.HealthBarScreenPos
                local x = 106 / (hero.MaxHealth + hero.ShieldAll)
                local position = (hero.Health + hero.ShieldAll) * x
                local value = math_min(position, true_damage * x)
                position = position - value
                if true_damage >= (hero.Health + hero.ShieldAll) then
                    Renderer.DrawFilledRect(
                        Vector(hpBarPos.x + position - 45, hpBarPos.y - 23),
                        Vector(value, 11), 1, 0xADFF2FFF)
                else
                    Renderer.DrawFilledRect(
                        Vector(hpBarPos.x + position - 45, hpBarPos.y - 23),
                        Vector(value, 11), 1, 0xFFD700FF)
                end
            end
        end
    end
end

---@type fun(unit: GameObject, buff: BuffInst):void
print("> XX Riven Loaded <")
----------------------------------------------------------------------------------------------

---@type fun():void
function OnLoad()
    EventManager.RegisterCallback(Events.OnTick, OnTick)
    EventManager.RegisterCallback(Events.OnDraw, OnDraw)
    EventManager.RegisterCallback(Events.OnBuffGain, OnBuffGain)
    return true
end

----------------------------------------------------------------------------------------------
