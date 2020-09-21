 --[[
 Original Assembly MTristana by Mistal
 Reworked by OKOK92 : 
 + Updated to work with the new version of Robur 
 + Added Menu 
 + Added AutoJump
 ]]
 
require("common.log")
module("MTrist", package.seeall, log.setup)

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

local _Q = SpellSlots.Q
local _W = SpellSlots.W
local _E = SpellSlots.E
local _R = SpellSlots.R

Menu:AddMenu("MtristV2", "MtristV2")
Menu.MtristV2:AddBool("Rcombo","Use R to KS or push back", true)
Menu.MtristV2:AddBool("AutoJump","Auto Jump to kill", true)


local function getRdmg(target)
	local tristR = {300, 400, 500}
	local dmgR = tristR[Player:GetSpell(SpellSlots.R).Level]
	return (dmgR + Player.TotalAP) * (100.0 / (100 + Player.FlatMagicReduction ) )
end

local function getAAdmg(target)
	local TristAD = Player.TotalAD
	local EnemArmor = Player.Armor + Player.BonusArmor
	return TristAD - EnemArmor
end

local function UseItems(target)	
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

local function Combo(target)
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready then
		Input.Cast(SpellSlots.Q)
	elseif Player:GetSpellState(SpellSlots.E) == SpellStates.Ready then
		Input.Cast(SpellSlots.E, target)
	end
end

local function AutoR()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	
	if Player:GetSpellState(SpellSlots.R) ~= SpellStates.Ready then return end

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			if dist <= myRange and getRdmg(hero) > (hero.Health) then				
				Input.Cast(SpellSlots.R, hero) -- R KS        
			elseif dist <= 200 then				
				Input.Cast(SpellSlots.R, hero) -- Anti-Gap Closer
			end
		end		
	end	
end 

local function AutoJump()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	
	if Player:GetSpellState(_W) ~= SpellStates.Ready then return end
		for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			if dist > myRange and getAAdmg(hero) > (hero.Health) then				
				Input.Cast(_W, hero.Position)  
			end				
		end		
	end	
end

local function OnTick()		
		if Menu.MtristV2.Rcombo.Value then 
			AutoR()
		end
		if Menu.MtristV2.AutoJump.Value then 
			AutoJump()
		end
	if Orb.GetMode() == "Combo" then 
			local target = Ts:GetTarget(Player.AttackRange + Player.BoundingRadius, true)
		if target and target.IsValid and not target.IsDead then
			Combo(target)
			UseItems(target)
		end
	end
end

function OnLoad() 
	if Player.CharName ~= "Tristana" then return false end 
	Game.PrintChat("MTristana V2 by OKOK92")
	EventManager.RegisterCallback(Enums.Events.OnTick, OnTick)
	return true
end
