 --[[
OK_Twitch
 ]]
 
require("common.log")
module("OK_Twitch", package.seeall, log.setup)

require("lol/Modules/Common/Collision")
require("lol/Modules/Common/DamageLib")

local _Core, _Libs = _G.CoreEx, _G.Libs
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer, Vector = 
_Core.ObjectManager, _Core.EventManager, _Core.Input, _Core.Enums, _Core.Game, _Core.Geometry, _Core.Renderer, _Core.Geometry.Vector
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Collision, DmgLib, HPred, Pred, Orb, Menu, Ts = _Libs.CollisionLib, _Libs.DamageLib, _Libs.HealthPred, _Libs.Prediction, _Libs.Orbwalker, _Libs.Menu, _Libs.TargetSelector()
local Menu = require("lol/Modules/Common/Menu")

local Enemies = ObjManager.Get("enemy", "heroes")
local EnemyMinions = ObjManager.Get("enemy", "minions")
local Player = ObjManager.Player
local BuffTypes = _G.CoreEx.Enums.BuffTypes

local _Q = SpellSlots.Q
local _W = SpellSlots.W
local _E = SpellSlots.E
local _R = SpellSlots.R

-- Spells Datas
local QData = Player:GetSpell(_Q)
local WData = Player:GetSpell(_W)
local EData = Player:GetSpell(_E)
local RData = Player:GetSpell(_R)

local function DrawPlayer()
		local Position = Player.Position
		Renderer.DrawCircle3D(Position, 875, 30, 0.3, 16777215)
end

Menu:AddMenu("OK_Twitch", "OK_Twitch")
Menu.OK_Twitch:AddBool("AutoW","Use W Auto", true)
Menu.OK_Twitch:AddBool("AutoE","Use E Auto", true)
Menu.OK_Twitch:AddBool("AutoR","Use R Auto", true)
Menu.OK_Twitch:AddBool("AutoHeal","Heal Auto at 15%", true)
Menu.OK_Twitch:AddBool("AutoQSS","Auto QSS hard CC", true)


function AutoHeal()

	if string.find(string.lower(Player:GetSpell(SpellSlots.Summoner1).Name), "heal") then
		HealSpell = SpellSlots.Summoner1
	elseif string.find(string.lower(Player:GetSpell(SpellSlots.Summoner2).Name), "heal") then
		HealSpell = SpellSlots.Summoner2
	end
	if Player.Health <= (0.15 * Player.MaxHealth) then
		Input.Cast(HealSpell)
	end
end

function countEStacks(target) 
	local ai = target.AsAI
    if ai and ai.IsValid then
		for i = 0, ai.BuffCount do
			local buff = ai:GetBuff(i)
			if buff then
				if buff.Name == "TwitchDeadlyVenom" then
					if buff.Count ~= nil then
						return buff.Count
					end
				end
			end
		end
	end

	return 0
end

function invisibleCheck() 
	local ai = Player
	return ai.IsStealthed
end

local function getEdmg(target)
	local TwitchE_Damage_level = {20, 30, 40, 50, 60}
	local TwitchE_Damage_buff_level = {15, 20, 25, 30, 35}
	
	local Twitch_Buff_poison = countEStacks(target)
	
	local TwitchE_Damage_Base = TwitchE_Damage_level[Player:GetSpell(SpellSlots.E).Level]
	local TwitchE_Damage_Buff = TwitchE_Damage_buff_level[Player:GetSpell(SpellSlots.E).Level]
	
	local TwitchE_Damage_Total = TwitchE_Damage_Base + (TwitchE_Damage_Buff + 0.35 * Player.BonusAD) * Twitch_Buff_poison
	return TwitchE_Damage_Total
end

local function getAAdmg(target)
	local TristAD = Player.TotalAD
	local EnemArmor = Player.Armor + Player.BonusArmor
	return TristAD - EnemArmor
end

local function UseBotrk(target)	
	for i=SpellSlots.Item1, SpellSlots.Item6 do
		local _item = Player:GetSpell(i)
		if _item ~= nil and _item then
			local itemInfo = _item.Name

			if itemInfo == "ItemSwordOfFeastAndFamine" or itemInfo == "BilgewaterCutlass" then
				if Player:GetSpellState(i) == SpellStates.Ready then
					Input.Cast(i, target)
				end
				break
			end
		end
	end
end

local function UseQSS(Player, buffInst)	
	for i=SpellSlots.Item1, SpellSlots.Item6 do
		local _item = Player:GetSpell(i)
		if _item ~= nil and _item then
			local itemInfo = _item.Name

			if itemInfo == "QuicksilverSash" or itemInfo == "MercurialScimitar" then
				if Player:GetSpellState(i) == SpellStates.Ready and buffInst.BuffType == BuffTypes.Taunt or buffInst.BuffType == BuffTypes.Stun  then
					local smartDelay = math.random (250, 500)  
					delay(smartDelay, Input.Cast(i))
				end
				break
			end
		end
	end
end

local function Combo(target)
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready then
		Input.Cast(SpellSlots.Q)
	elseif Player:GetSpellState(SpellSlots.R) == SpellStates.Ready and invisibleCheck() == false then
			if Menu.OK_Twitch.AutoR.Value then 
				Input.Cast(SpellSlots.R, target)
			end
	end
end

local function AutoE()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	
	if Player:GetSpellState(SpellSlots.E) ~= SpellStates.Ready then return end

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			if dist <= 1200 and getEdmg(hero) > (hero.Health + hero.Armor) then				
				Input.Cast(SpellSlots.E, hero) -- E to kill      
			elseif dist <= 1200 and countEStacks(hero) == 6 then				
				Input.Cast(SpellSlots.E, hero) -- E at 5 stacks
			end
		end		
	end	
end 

local function AutoW()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	
	if Player:GetSpellState(SpellSlots.W) ~= SpellStates.Ready then return end

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			if dist <= 700 then	-- Range is 950 used 700 to optimize			
				Input.Cast(SpellSlots.W, hero.Position)  
			end
		end		
	end	
end

local function OnDraw()
  DrawPlayer()
end

local function OnTick()		
	if Menu.OK_Twitch.AutoHeal.Value then 
		AutoHeal()
	end
	if Menu.OK_Twitch.AutoE.Value then 
		AutoE()
	end
	if Orb.GetMode() == "Combo" then 
		local target = Ts:GetTarget(Player.AttackRange + Player.BoundingRadius, true)
		if Player.Level == 6 and Player:GetSpellState(SpellSlots.R) == SpellStates.Ready then
			target = Ts:GetTarget(Player.AttackRange + Player.BoundingRadius + 300, true)
		end
		if target and target.IsValid and not target.IsDead then
			if Menu.OK_Twitch.AutoW.Value then 
				AutoW()
			end
		
		UseBotrk(target)
		Combo(target)
		end
	end
end

function OnLoad() 
	if Player.CharName ~= "Twitch" then return false end 
	Game.PrintChat('<font color="#3BB143">SCRIPT LOADED :</font><font color="#20639b"> OK_Twitch</font><font color="#20639b"> !</font>')
	EventManager.RegisterCallback(Enums.Events.OnTick, OnTick)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnBuffGain, UseQSS)
	return true
end
