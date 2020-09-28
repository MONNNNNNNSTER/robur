 --[[
	Master Yi by OKOK92;
 ]]
 
require("common.log")
module("OK_MasterYi", package.seeall, log.setup)

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
local WaitR = false

local _Q = SpellSlots.Q
local _W = SpellSlots.W
local _E = SpellSlots.E
local _R = SpellSlots.R

Menu:AddMenu("OK_MasterYi", "OK_MasterYi")
Menu.OK_MasterYi:AddBool("AutoR","Auto R", true)
Menu.OK_MasterYi:AddBool("AutoW","Auto Heal W", true)
Menu.OK_MasterYi:AddBool("AutoQSS","Auto QSS hard CC", true)

local function getAAdmg(target)
	local DravAD = Player.TotalAD
	local EnemArmor = Player.Armor + Player.BonusArmor
	return DravAD - EnemArmor
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
	if Menu.OK_MasterYi.AutoQSS.Value then 
		for i=SpellSlots.Item1, SpellSlots.Item6 do
		local _item = Player:GetSpell(i)
		if _item ~= nil and _item then
			local itemInfo = _item.Name
			if itemInfo == "QuicksilverSash" or itemInfo == "MercurialScimitar" then
				if Player:GetSpellState(i) == SpellStates.Ready and buffInst.BuffType == BuffTypes.Taunt or buffInst.BuffType == BuffTypes.Stun or buffInst.BuffType == BuffTypes.Polymorph or buffInst.BuffType == BuffTypes.Fear or buffInst.BuffType == BuffTypes.Charm or buffInst.BuffType == BuffTypes.Suppression or buffInst.BuffType == BuffTypes.Asleep or buffInst.BuffType == BuffTypes.Disarm then
					-- Smart Delay
					local smartDelay = math.random (250, 700)  
					delay(smartDelay, Input.Cast(i))
				end
				break
			end
		end
		end
	end
end

local function Combo(target)
	if Menu.OK_MasterYi.AutoR.Value then
		if Player:GetSpellState(SpellSlots.R) == SpellStates.Ready then
			Input.Cast(SpellSlots.R)
			end
	end
	
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready then
		Input.Cast(SpellSlots.Q, target)
	end
	
	if  Player:GetSpellState(SpellSlots.E) == SpellStates.Ready then
		Input.Cast(SpellSlots.E)
	end
end

local function Combo_W()
	-- Heal with W at 30%
	if Player.Health <= (Player.MaxHealth * 0.3) and Player:GetSpellState(SpellSlots.W) == SpellStates.Ready and and Player:GetSpellState(SpellSlots.Q) ~= SpellStates.Ready then
		Input.Cast(SpellSlots.W)
	end
end
local function Combo_Q()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos = Player.Position
	if Player:GetSpellState(SpellSlots.Q) ~= SpellStates.Ready then return end
	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)     
			if dist <= 600 then				
				Input.Cast(SpellSlots.Q, hero)
			end
		end		
	end	
end

local function OnTick()				
	if Orb.GetMode() == "Combo" then 
		Combo_Q()
		local target = Ts:GetTarget(Player.AttackRange, true)
		if target and target.IsValid then
			UseBotrk(target)
			Combo(target)
				if Menu.OK_MasterYi.AutoW.Value then 
					Combo_W()
				end
		end
	end
end

function OnLoad() 
	if Player.CharName ~= "MasterYi" then return false end
	EventManager.RegisterCallback(Enums.Events.OnTick, OnTick)
	EventManager.RegisterCallback(Enums.Events.OnBuffGain, UseQSS)
	Game.PrintChat('<font color="#3BB143">SCRIPT LOADED :</font><font color="#20639b"> OK_MasterYi</font><font color="#20639b"> !</font>')
	return true
end
