 --[[
	Draven by OKOK92;
 ]]
 
require("common.log")
module("OK_Draven", package.seeall, log.setup)

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

Menu:AddMenu("OK_Draven", "OK_Draven")
Menu.OK_Draven:AddBool("AutoR","Use R to KS", true)
Menu.OK_Draven:AddBool("AutoE","Auto E", true)


local function getRdmg(target)
	local Drav_R_moy = {210, 330, 450}
	local Drav_R_Ratio = {1.1, 1.3, 1.5}
	local dmgR = Drav_R_moy[Player:GetSpell(SpellSlots.R).Level] + (Drav_R_Ratio[Player:GetSpell(SpellSlots.R).Level]*Player.TotalAD)
	return dmgR
end

local function getAAdmg(target)
	local DravAD = Player.TotalAD
	local EnemArmor = Player.Armor + Player.BonusArmor
	return DravAD - EnemArmor
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
	elseif Player:GetSpellState(SpellSlots.W) == SpellStates.Ready then
		Input.Cast(SpellSlots.W, target)
	end
end

local function Combo_E()
		local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, Player.AttackRange	
	if Player:GetSpellState(_E) ~= SpellStates.Ready then return end
		for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			if dist <= 950 then				
				Input.Cast(_E, hero.Position)  
			end				
		end		
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
			if getRdmg(hero) > (hero.Health)  and dist <= 4000 then				
				Input.Cast(SpellSlots.R, hero.Position) -- R KS        
			end
		end		
	end	
end 

local function OnTick()		
		if Menu.OK_Draven.AutoR.Value then 
		AutoR()
		end
		if Menu.OK_Draven.AutoE.Value then 
		Combo_E()
		end
		
	if Orb.GetMode() == "Combo" then 
		local target = Ts:GetTarget(Player.AttackRange, true)
		if target and target.IsValid then
			Combo(target)
			UseItems(target)
		end
	end
end

function OnLoad() 
	if Player.CharName ~= "Draven" then return false end 
	EventManager.RegisterCallback(Enums.Events.OnTick, OnTick)
	Game.PrintChat("OK_Draven Loaded ! ")
	return true
end
