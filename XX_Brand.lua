if Player.CharName ~= "Brand" then return end

----------------------------------------------------------------------------------------------

require("common.log")
module("XX_Brand", package.seeall, log.setup)
clean.module("XX_Brand", clean.seeall, log.setup)

local VERSION = "1.0"
local LAST_UPDATE = "10/05/2021"

----------------------------------------------------------------------------------------------

local SDK               = _G.CoreEx

local DamageLib         = _G.Libs.DamageLib
local CollisionLib      = _G.Libs.CollisionLib
local Menu              = _G.Libs.NewMenu
local Prediction        = _G.Libs.Prediction
local TargetSelector    = _G.Libs.TargetSelector
local Orbwalker         = _G.Libs.Orbwalker
local Spell             = _G.Libs.Spell
local TS                = _G.Libs.TargetSelector()

local ObjectManager     = SDK.ObjectManager
local EventManager      = SDK.EventManager
local Input             = SDK.Input
local Game              = SDK.Game
local Geometry          = SDK.Geometry
local Renderer          = SDK.Renderer
local Enums             = SDK.Enums

local Events            = Enums.Events
local SpellSlots        = Enums.SpellSlots
local SpellStates       = Enums.SpellStates
local HitChance         = Enums.HitChance
local DamageTypes       = Enums.DamageTypes
local Vector            = Geometry.Vector

local pairs             = _G.pairs
local type              = _G.type
local tonumber          = _G.tonumber
local math_abs          = _G.math.abs
local math_huge         = _G.math.huge
local math_min          = _G.math.min
local math_deg          = _G.math.deg
local math_sin          = _G.math.sin
local math_cos          = _G.math.cos
local math_acos         = _G.math.acos
local math_pi           = _G.math.pi
local math_pi2          = 0.01745329251
local os_clock          = _G.os.clock
local string_format     = _G.string.format
local table_remove      = _G.table.remove

local _Q                = SpellSlots.Q
local _W                = SpellSlots.W
local _E                = SpellSlots.E
local _R                = SpellSlots.R

local ItemID            = require("lol/Modules/Common/ItemID")
local Q_stacks = 0
local daggerObj = false
local tempdagger = 0
---@type fun(unit: GameObject, buff: BuffInst):void
----------------------------------------------------------------------------------------------

local Q = Spell.Skillshot({
		["Slot"] = _Q,
		["SlotString"] = "Q",
		["Speed"] = 1600,
		["Range"] = 1040,    
		["Delay"] = 0.25,
		["Radius"] = 120,
		["Type"] = "Linear",
		["Collisions"] = {Heroes=true, Minions=true, WindWall=true},
		["UseHitbox"] = true
})

local W = Spell.Skillshot({
		["Slot"] = _W,
		["SlotString"] = "W",
		["Range"] = 900,
		["Delay"] = 1,
		["Radius"] = 100,
		["EffectRadius"] = 200,
		["Type"] = "Circular",
    })
local E = Spell.Targeted({
        ["Slot"] = _E,
		["SlotString"] = "E",
        ["Range"] = 670,
        ["Delay"] = 0.25,
        ["EffectRadius"] = 600,
    })
local R = Spell.Targeted({
        ["Slot"] = _R,
		["SlotString"] = "R",
        ["Range"] = 750,
        ["Delay"] = 0.25,
		["EffectRadius"] = 600,
    })

----------------------------------------------------------------------------------------------

local LastCastT = {
    [_Q] = 0,
    [_W] = 0,
    [_E] = 0,
    [_R] = 0,
}

local DrawSpellTable = { Q, W, E, R }
local TickCount = 0

---@type fun(a: number, r: number, g: number, b: number):number
local ARGB = function(a, r, g, b)
    return tonumber(string_format("0x%02x%02x%02x%02x", r, g, b, a))
end

---@type fun():boolean
local GameIsAvailable = function()
    return not Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling
end

---@type fun(object: GameObject, range: number, from: Vector):boolean
local IsValidTarget = function(object, range, from)
    local from = from or Player.Position
    return TS:IsValidTarget(object, range, from)
end

---@type fun(obj: GameObject):boolean
local IsValidObject = function(obj)
    return obj and obj.IsValid and not obj.IsDead
end

---@type fun(spell: SpellBase, condition: function):boolean
local IsReady = function(spell, condition)
    local isReady = spell:IsReady()
    if condition ~= nil then
        return isReady and (type(condition) == "function" and condition() or type(condition) == "boolean" and condition)
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
                return true and (type(condition) == "function" and condition() or type(condition) == "boolean" and condition)
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
            Menu.Checkbox(id .. "WhiteList" .. heroAI.CharName, heroAI.CharName, true)
        end
    end)
end

---@type fun(id: string):boolean|number
local GetMenuValue = function(id)
    local menuValue = Menu.Get(id, true)
    if menuValue then
        return menuValue
    end
    return false
end

---@type fun(id: string):boolean|number
local GetKeyMenuValue = function(id)
    local menuValue = Menu.GetKey(id, true)
    if menuValue then
        return menuValue
    end
    return false
end

---@type fun(slot: string, mode: string, heroName: string):boolean
local GetWhiteListValue = function(slot, mode, heroName)
    return GetMenuValue(mode .. slot .. "WhiteList" .. heroName)
end

local function ChangeCh(val)
	R.IsCharging = val
end

----------------------------------------------------------------------------------------------

---@type fun(spell: table, target: GameObject):number
local GetDamage = function(spell, target)
    local W_damages = 42
	local slot = spell.Slot
    local myLevel = Player.Level
    local level = Player.AsHero:GetSpell(slot).Level
    if slot == _W and IsReady(W) then
		local flatAP = Player.TotalAP
        local WRawDamage = { 72, 120, 165, 210, 255 }
		local WabDamage = { 93.75, 150, 206.25, 262.5, 318.75}
		if target and target:GetBuff("BrandAblaze") then
			W_damages = WabDamage[level] + (0.6 * flatAP)
		else
			W_damages = WRawDamage[level] + (0.75 * flatAP)
		end
		return W_damages
	end
end

---@type fun(unit: GameObject):void	
----------------------------------------------------------------------------------------------
local function checkStun()
	local heroes = ObjectManager.Get("enemy", "heroes")	
	for i, hero in pairs(heroes) do
		local hero = hero.AsAI
		if hero and IsValidTarget(hero) and hero:GetBuff("Stun") then
			return true
		end
		return false
	end
end

local function countR()
	local count = 0
	local heroes = ObjectManager.Get("enemy", "heroes")	
	for i, hero in pairs(heroes) do
		local hero = hero.AsAI
		local dist = Player.Position:Distance(hero.Position)
		if dist <= (R.Range + 300) then
			count = count + 1
		end
	end
	return count
end

local HitChanceList = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" }

Menu.RegisterMenu("XX Brand", "XX Brand", function()
    Menu.Checkbox("ScriptEnabled", "Script Enabled", true)

    Menu.Separator()

    Menu.ColoredText("Spell Settings", ARGB(255, 255, 255, 255), true)

    Menu.Separator()

    Menu.NewTree("Q", "[Q] Sear", function()
        Menu.NewTree("ComboQ", "Combo Options", function()
            Menu.Checkbox("ComboUseQ", "Enabled", true)
			Menu.Checkbox("ComboUseQStunOnly", "Q only to Stun", true)
			Menu.Slider("QHitchance", "Hit chance", 60, 20, 100, 1)
        end)
        Menu.NewTree("WaveClearQ", "Wave Clear Options", function()
            Menu.Checkbox("WaveClearUseQ", "Enabled", true)
            Menu.Slider("WaveClearManaQ", "Min. Mana [%]", 0, 0, 100, 1)
        end)
        Menu.NewTree("DrawingsQ", "Drawings", function()
            Menu.Checkbox("DrawQ", "Draw Range", true)
            Menu.ColorPicker("DrawColorQ", "Color", ARGB(255, 217, 55, 55))
        end)
    end)

    Menu.NewTree("W", "[W] Pillar of Flame", function()
        Menu.NewTree("ComboW", "Combo Options", function()
            Menu.Checkbox("ComboUseW", "Enabled", true)
			Menu.Checkbox("ComboUseAutoW", "Auto W stunned", true)
			Menu.Slider("WHitchance", "Hit chance", 60, 20, 100, 1)
        end)
		Menu.NewTree("WaveClearW", "Wave Clear Options", function()
            Menu.Checkbox("WaveClearUseW", "Enabled", true)
            Menu.Slider("WaveClearManaQ", "Min. Mana [%]", 0, 0, 100, 1)
		end)
        Menu.NewTree("DrawingsW", "Drawings", function()
            Menu.Checkbox("DrawW", "Draw Range", true)
            Menu.ColorPicker("DrawColorW", "Color", ARGB(255, 255, 255, 255))
        end)
    end)

    Menu.NewTree("E", "[E] Conflagration", function()
        Menu.NewTree("ComboE", "Combo Options", function()
            Menu.Checkbox("ComboUseE", "Enabled", true)
        end)
	Menu.NewTree("WaveClearE", "Wave Clear Options", function()
        Menu.Checkbox("WaveClearUseE", "Enabled", true)
        Menu.Slider("WaveClearManaQ", "Min. Mana [%]", 0, 0, 100, 1)
	end)
    Menu.NewTree("DrawingsE", "Drawings", function()
            Menu.Checkbox("DrawE", "Draw Range", true)
            Menu.ColorPicker("DrawColorE", "Color", ARGB(255, 255, 255, 255))
        end)
    end)

    Menu.NewTree("R", "[R] Pyroclasm", function()
        Menu.NewTree("ComboR", "Combo Options", function()
            Menu.Checkbox("ComboUseR", "Enabled", true)
            Menu.Slider("ComboMinHitR", "Min. Heroes Hits", 1, 1, 5, 1)
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
local count = 0
local heroes = ObjectManager.Get("enemy", "heroes")	


-- W on stunned
if checkStun() and IsReady(W) and GetMenuValue("ComboUseAutoW") then
	for i, hero in pairs(heroes) do
		local hero = hero.AsAI
		if hero and IsValidTarget(hero, W.Range) then
			local dist = Player.Position:Distance(hero.Position)	
			if dist <= W.Range and hero:GetBuff("Stun") then		
				CastSpell(_W,hero.Position)
			end
		end
	end
end

if IsReady(Q) and GetMenuValue("ComboUseQ") then
			for i, hero in pairs(heroes) do
				local hero = hero.AsAI
				if hero and IsValidTarget(hero, Q.Range) then
					local predi = Prediction.GetPredictedPosition(hero, Q, Player.Position)
					local dist = Player.Position:Distance(hero.Position)	
					if predi and dist <= Q.Range and predi.HitChance > (GetMenuValue("QHitchance")/100) then		
						if GetMenuValue("ComboUseQStunOnly") and hero:GetBuff("BrandAblaze") then
							CastSpell(_Q,predi.CastPosition)
						end
						if GetMenuValue("ComboUseQStunOnly") == false then
							CastSpell(_Q,predi.CastPosition)
						end
					end
				end
			end
end 

if IsReady(W) and GetMenuValue("ComboUseW") then
			for i, hero in pairs(heroes) do
				local hero = hero.AsAI
				if hero and IsValidTarget(hero, W.Range) then
					GetDamage(W, hero)
					local pred = Prediction.GetPredictedPosition(hero, W, Player.Position)
					local dist = Player.Position:Distance(hero.Position)	
					if pred and dist <= (W.Range) and pred.HitChance > (GetMenuValue("WHitchance")/100) then		
						CastSpell(_W,pred.CastPosition)
					end
				end
			end
end 
	
if IsReady(E) and GetMenuValue("ComboUseE") then
        for i, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, E.Range) then
                local dist = Player.Position:Distance(hero.Position)
				if dist <= E.Range then			
					CastSpell(_E,hero)
                end
            end
        end
	end
	
if IsReady(R) and GetMenuValue("ComboUseR") then
		--print(countR())
		for i, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, R.Range) then
                local dist = Player.Position:Distance(hero.Position)
				if dist <= R.EffectRadius and hero:GetBuff("BrandAblaze") and countR() >= GetMenuValue("ComboMinHitR") then			
					CastSpell(_R,hero)
                end
				if dist <= R.Range and countR() >= GetMenuValue("ComboMinHitR") and hero:GetBuff("BrandAblaze") then
					CastSpell(_R,hero)
				end
            end
        end
	end

end

local Waveclear = function()
	local minions = ObjectManager.Get("enemy", "minions")
	
	if IsReady(Q) and GetMenuValue("WaveClearUseQ") then
		for i, hero in pairs(minions) do
			local hero = hero.AsAI
			if hero and IsValidTarget(hero, Q.Range) then
				local predi = Prediction.GetPredictedPosition(hero, Q, Player.Position)
				local dist = Player.Position:Distance(hero.Position)	
				if predi and dist <= Q.Range and predi.HitChanceEnum > Enums.HitChance.High then		
					CastSpell(_Q,predi.CastPosition)
				end
			end
		end
	end
	
	if IsReady(E) and GetMenuValue("WaveClearUseE") then
        for i, hero in pairs(minions) do
            local hero = hero.AsAI
            if hero and IsValidTarget(hero, E.Range) and hero:GetBuff("BrandAblaze") then
                local dist = Player.Position:Distance(hero.Position)
				if dist <= E.Range then			
					CastSpell(_E,hero)
                end
            end
        end
	end
	
if IsReady(W) and GetMenuValue("WaveClearUseW") then
			for i, hero in pairs(minions) do
				local hero = hero.AsAI
				if hero and IsValidTarget(hero, W.Range) then
					local pred = Prediction.GetPredictedPosition(hero, W, Player.Position)
					local dist = Player.Position:Distance(hero.Position)	
					if pred and dist <= (W.Range) and pred.HitChance > 0.2 then		
						CastSpell(_W,pred.CastPosition)
					end
				end
			end
end 
end
---@type fun():void
local LastHit = function()
    
end


---@type fun():void
local AutoMode = function()

end

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
			if LastHit() then
                return
            end
        end
    end

    local tick = os_clock()
    if TickCount < tick then
        TickCount = tick + 0.5
    end
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
                    local colorValue = GetMenuValue("DrawColor" .. spell.SlotString)
                    if colorValue then
                        Renderer.DrawCircle3D(myHeroPos, spell.Range, 30, 2, colorValue)
                    end
                end
            end
        end
    end
	--[[local heroes = ObjectManager.Get("enemy", "heroes")
        for k, hero in pairs(heroes) do
            local hero = hero.AsAI
            if hero.IsVisible and hero.IsOnScreen and not hero.IsDead then
                local damage = GetDamage(W, hero)
                local hpBarPos = hero.HealthBarScreenPos
                local x = 106 / (hero.MaxHealth + hero.ShieldAll)
                local position = (hero.Health + hero.ShieldAll) * x
                local value = math_min(position, damage * x)
                position = position - value
                Renderer.DrawFilledRect(Vector(hpBarPos.x + position - 45, hpBarPos.y - 23), Vector(value, 11), 1, 0xFFD700FF)
            end
        end]]
	
end


---@type fun(unit: GameObject, buff: BuffInst):void
print("> XX Brand Loaded <")
----------------------------------------------------------------------------------------------

---@type fun():void
function OnLoad()
    EventManager.RegisterCallback(Events.OnTick, OnTick)
    EventManager.RegisterCallback(Events.OnDraw, OnDraw)
    EventManager.RegisterCallback(Events.OnBuffGain, OnBuffGain)
    return true
end

----------------------------------------------------------------------------------------------