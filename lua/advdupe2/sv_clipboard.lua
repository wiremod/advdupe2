--[[
	Title: Adv. Duplicator 2 Module
	
	Desc: Provides advanced duplication functionality for the Adv. Dupe 2 tool.
	
	Author: TB
	
	Version: 1.0
]]

require "duplicator"

AdvDupe2.duplicator = {} 
//AdvDupe2.AllowNPCs = false	--Allow to paste NPCs
AdvDupe2.JobManager = {}
AdvDupe2.JobManager.PastingHook = false
AdvDupe2.JobManager.Queue = {}

local constraints = {Weld=true,  Axis=true, Ballsocket=true, Elastic=true, Hydraulic=true, Motor=true, Muscle=true, Pulley=true, Rope=true, Slider=true, Winch=true}


--[[
	Name: CopyEntTable
	Desc: Returns a copy of the passed entity's table
	Params: <entity> Ent
	Returns: <table> enttable
]]

/*---------------------------------------------------------
	Returns a copy of the passed entity's table
---------------------------------------------------------*/
local function CopyEntTable( Ent, Offset )

	local Tab = {}

	if Ent.PreEntityCopy then
		Ent:PreEntityCopy()
	end

	local EntityClass = duplicator.FindEntityClass( Ent:GetClass() )
	
	local EntTable = table.Copy(Ent:GetTable())
	if EntityClass then

		local Arg
		for iNumber, Key in pairs( EntityClass.Args ) do
			-- Translate keys from old system
			if ( Key == "pos" or Key == "position" ) then Key = "Pos" end
			if ( Key == "ang" or Key == "Ang" or Key == "angle" ) then Key = "Angle" end
			if ( Key == "model" ) then Key = "Model" end

			Arg = EntTable[ Key ]
			
			-- Special keys
			--if ( Key == "Data" ) then Arg = EntTable end
			
			-- If there's a missing argument then unpack will stop sending at that argument
			if Arg == nil then Arg = false end
			
			Tab[ Key ] = Arg
			
		end
		
	end	

	Tab.BoneMods = table.Copy( Ent.BoneMods )
	if(Ent.EntityMods)then
		Tab.EntityMods = Ent.EntityMods
	end

	if Ent.PostEntityCopy then
		Ent:PostEntityCopy()
	end

	Tab.Pos 			= Ent:GetPos()
	Tab.Angle 			= nil
	Tab.Class 			= Ent:GetClass()
	Tab.Model 			= Ent:GetModel()
	Tab.Skin 			= Ent:GetSkin()
	if(Tab.Skin==0)then	Tab.Skin = nil end
	
	if(Tab.Class == "gmod_cameraprop")then
		Tab.key = Ent:GetNetworkedInt("key")
	end
	-- Allow the entity to override the class
	-- This is a hack for the jeep, since it's real class is different from the one it reports as
	-- (It reports a different class to avoid compatibility problems)
	if Ent.ClassOverride then Tab.Class = Ent.ClassOverride end
	
	Tab.PhysicsObjects = {}

	-- Physics Objects
	//if(IsValid(Ent:GetPhysicsObject()))then
		local iNumPhysObjects = Ent:GetPhysicsObjectCount()
		local PhysObj
		
		for Bone = 0, iNumPhysObjects-1 do 
			PhysObj = Ent:GetPhysicsObjectNum( Bone )
			if PhysObj!=nil then
				Tab.PhysicsObjects[ Bone ] = Tab.PhysicsObjects[ Bone ] or {}
				if(PhysObj:IsMoveable())then Tab.PhysicsObjects[ Bone ].Frozen = true end
				PhysObj:EnableMotion(false)
				Tab.PhysicsObjects[ Bone ].Pos = PhysObj:GetPos() - Tab.Pos
				Tab.PhysicsObjects[ Bone ].Angle = PhysObj:GetAngle()
			end
		end
		
		Tab.PhysicsObjects[0].Pos = Tab.Pos - Offset
	//end

	Tab.Pos = nil
	if(Tab.Class!="prop_physics")then
		if(!Tab.BuildDupeInfo)then Tab.BuildDupeInfo = {} end
		Tab.BuildDupeInfo.IsNPC = Ent:IsNPC()
		Tab.BuildDupeInfo.IsVehicle = Ent:IsVehicle()
	end
	if( IsValid(Ent:GetParent()) ) then
		if(!Tab.BuildDupeInfo)then Tab.BuildDupeInfo = {} end
		Tab.PhysicsObjects[ 0 ].Angle = Ent:GetAngles()
		Tab.BuildDupeInfo.DupeParentID = Ent.Entity:GetParent():EntIndex()
	end
	
	-- Flexes
	local FlexNum = Ent:GetFlexNum()
	Tab.Flex = Tab.Flex or {}
	local weight
	local flexes = false
	for i = 0, FlexNum do
		weight = Ent:GetFlexWeight( i )
		if(weight!=0)then
			Tab.Flex[ i ] = Ent:GetFlexWeight( i )
			flexes = true
		end
	end
	
	if(flexes)then
		Tab.FlexScale = Ent:GetFlexScale()
	else
		Tab.Flex = nil
	end
	
	if ( EntTable.CollisionGroup ) then
		if ( !Tab.EntityMods ) then Tab.EntityMods = {} end
		Tab.EntityMods.CollisionGroupMod = EntTable.CollisionGroup
	end
	
	// Make this function on your SENT if you want to modify the
	//  returned table specifically for your entity.
	if Ent.OnEntityCopyTableFinish then
		Ent:OnEntityCopyTableFinish( Tab )
	end

	return Tab

end


--[[
	Name: CopyConstraintTable
	Desc: Create a table for constraints
	Params: <table> Constraints
	Returns: <table> Constraints, <table> Entities
]]

/*Still not finished:

*/
local function CopyConstraintTable( Const, Offset )

	local Constraint = {}
	local Entities = {}

	if(Const!=nil)then
		Const.Constraint = nil
		Const.OnDieFunctions=nil
		Constraint.Entity={}
		local Type = duplicator.ConstraintType[ Const.Type ]
	
		if ( Type ) then 
			for k, key in pairs( Type.Args ) do
				if(!string.find(key, "Ent") and !string.find(key, "Bone"))then
					Constraint[key] = Const[ key ]
				end		
			end	
				
			if((Const["Ent"] && Const["Ent"]:IsWorld()) || IsValid(Const["Ent"]))then
				Constraint.Entity[ 1 ] = {}
				Constraint.Entity[ 1 ].Index = Const["Ent"]:EntIndex()
				if(!Const["Ent"]:IsWorld())then table.insert( Entities, Const["Ent"] ) end
			else
				local ent
				for i=1,4 do
					ent = "Ent"..i
					
					if((Const[ent] && Const[ent]:IsWorld()) || IsValid(Const[ent]))then
						Constraint.Entity[ i ] 				= {}
						Constraint.Entity[ i ].Index 		= Const[ent]:EntIndex()
						Constraint.Entity[ i ].Bone			= Const[ "Bone"..i ]
						Constraint.Entity[ i ].Length		= Const[ "Length"..i ]
						Constraint.Entity[ i ].World		= Const[ "World"..i ]

						if Const[ ent ]:IsWorld() then
							Constraint.Entity[ i ].World = true
							if ( Const[ "LPos"..i ] ) then
								if(i!= 4 and i!=2)then
									if(Const["Ent2"])then
										Constraint.Entity[ i ].LPos = Const[ "LPos"..i ] - Const["Ent2"]:GetPos()
										Constraint[ "LPos"..i ] = Const[ "LPos"..i ] - Const["Ent2"]:GetPos()
									elseif(Const["Ent4"])then
										Constraint.Entity[ i ].LPos = Const[ "LPos"..i ] - Const["Ent4"]:GetPos()
										Constraint[ "LPos"..i ] = Const[ "LPos"..i ] - Const["Ent4"]:GetPos()
									end
								elseif(Const["Ent1"])then
									Constraint.Entity[ i ].LPos = Const[ "LPos"..i ] - Const["Ent1"]:GetPos()
									Constraint[ "LPos"..i ] = Const[ "LPos"..i ] - Const["Ent1"]:GetPos()
								end
							else
								Constraint.Entity[ i ].LPos = Offset
								Constraint[ "LPos"..i ] = Offset
							end
						else
							Constraint.Entity[ i ].LPos	= Const[ "LPos"..i ]
							Constraint.Entity[ i ].WPos = Const[ "WPos"..i ]
						end
									
						if(!Const[ent]:IsWorld())then table.insert( Entities, Const[ent] ) end
					end
					
					if(Const["WPos"..i])then
						if(!Const["Ent1"]:IsWorld())then
							Constraint["WPos"..i] = Const[ "WPos"..i ] - Const["Ent1"]:GetPos()
						else
							Constraint["WPos"..i] = Const[ "WPos"..i ] - Const["Ent4"]:GetPos()
						end
					end
				end	
			end
			
			Constraint.Type = Const.Type
			if(Const.BuildDupeInfo)then Constraint.BuildDupeInfo = table.Copy(Const.BuildDupeInfo) end
		end		

	end

	return Constraint, Entities

end

--[[
	Name: Copy
	Desc: Copy an entity and all entities constrained
	Params: <entity> Entity
	Returns: <table> Entities, <table> Constraints
]]
local function Copy( Ent, EntTable, ConstraintTable, Offset )


	local phys

	local index = Ent:EntIndex()
	
	EntTable[index] = CopyEntTable(Ent, Offset)

	if ( !constraint.HasConstraints( Ent ) ) then 
		local PhysObjs = EntTable[Ent:EntIndex()].PhysicsObjects
		for i=0, Ent:GetPhysicsObjectCount() do
			phys = Ent:GetPhysicsObjectNum(i)
			if(IsValid(phys))then
				phys:EnableMotion(PhysObjs[i].Frozen)
			end
		end
		return EntTable, ConstraintTable 
	end

	local index 
	for k, Constraint in pairs( Ent.Constraints ) do

		index = Constraint:GetCreationID()
		Constraint.Identity = index
		
		if ( index and !ConstraintTable[ index ] ) then
			local ConstTable, ents = CopyConstraintTable( table.Copy(Constraint:GetTable()), Offset )
			ConstraintTable[ index ] = ConstTable
			
			for j,e in pairs(ents) do
				if ( e and ( e:IsWorld() or e:IsValid() ) ) and ( !EntTable[ e:EntIndex() ] ) then
					Copy( e, EntTable, ConstraintTable, Offset )
				end
			end
		end

	end

	local PhysObjs = EntTable[Ent:EntIndex()].PhysicsObjects
	for i=0, Ent:GetPhysicsObjectCount() do
		phys = Ent:GetPhysicsObjectNum(i)
		if(IsValid(phys))then
			phys:EnableMotion(PhysObjs[i].Frozen)
		end		
	end
	
	return EntTable, ConstraintTable
end
AdvDupe2.duplicator.Copy = Copy

--[[
	Name: LoadSents
	Desc: Loads the entities list and the whitelist for spawning props
	Params:
	Returns:
]]
local function LoadSents()
	AdvDupe2.duplicator.EntityList = {prop_physics=true, prop_ragdoll=true, prop_vehicle_prisoner_pod=true, prop_vehicle_airboat=true, prop_vehicle_jeep=true, prop_vehicle_jeep_old=true, phys_magnet=true, prop_effect=true}
	AdvDupe2.duplicator.WhiteList = {prop_physics=true, prop_ragdoll=true, prop_vehicle_prisoner_pod=true, prop_vehicle_airboat=true, prop_vehicle_jeep=true, prop_vehicle_jeep_old=true, phys_magnet=true, prop_effect=true}
	local exclusion = {prop_effect= true, gmod_player_start=true, gmod_ghost=true, lua_run=true, gmod_wire_hologram=true}
	for _,v in pairs(scripted_ents.GetList( )) do
		if _:sub(1,4) == "base" then continue end
		if _:sub(1,4) == "info" then continue end
		if _:sub(1,4) == "func" then continue end
		if exclusion[_] then continue end
		if v.t.AdminSpawnable and !v.t.Spawnable then
			AdvDupe2.duplicator.EntityList[_] = false
		else
			AdvDupe2.duplicator.EntityList[_] = true
		end
		AdvDupe2.duplicator.WhiteList[_] = true
	end
end
//concommand.Add("advdupe2_reloadwhitelist", LoadSents)
hook.Add( "InitPostEntity", "LoadDuplicatingEntities", LoadSents)

--[[
	Name: AreaCopy
	Desc: Copy based on a box
	Params: <entity> Entity
	Returns: <table> Entities, <table> Constraints
]]
//Need to make a get entities function for constraints
function AdvDupe2.duplicator.AreaCopy( Entities, Offset, CopyOutside )
	local EntTable = {}
	local ConstraintTable = {}

	for _,Ent in pairs(Entities)do

		local phys

		local index = Ent:EntIndex()
		EntTable[index] = CopyEntTable(Ent, Offset)
		
		if ( !constraint.HasConstraints( Ent ) ) then
			local PhysObjs = EntTable[Ent:EntIndex()].PhysicsObjects
			for i=0, Ent:GetPhysicsObjectCount() do
				 phys = Ent:GetPhysicsObjectNum(i)
				if(IsValid(phys))then
					phys:EnableMotion(PhysObjs[i].Frozen)	//Restore the frozen state of the entity and all of its objects
				end
			end
			continue
		end

		local index
		local add
		for k, Constraint in pairs( Ent.Constraints ) do

			/*if(!Constraint.BuildDupeInfo)then
				Constraint.BuildDupeInfo = {}
			end*/

			if(!Constraint.Identity)then
				index = Constraint:GetCreationID()
				Constraint.Identity = Constraint:GetCreationID()
			else	
				index = Constraint.Identity
			end
	
			if ( index and !ConstraintTable[ index ] ) then
				local ConstTable, ents = CopyConstraintTable( table.Copy(Constraint:GetTable()), Offset )
				//If the entity is constrained to an entity outside of the area box, don't copy the constraint.
				if(!CopyOutside)then
					add = true
					for j,e in pairs(ents)do
						if(!Entities[e:EntIndex()])then add=false end
					end
					if(add)then ConstraintTable[ index ] = ConstTable  end
				else	//Copy entities and constraints outside of the box that are constrained to entities inside the box
					for k,v in pairs(ents)do
						ConstraintTable[ index ] = ConstTable
						if(v:EntIndex()!=_)then
							local AddEnts, AddConstrs = Copy(v, {}, {}, Offset)
							for j,e in pairs(AddEnts)do
								if(!EntTable[j])then EntTable[j] = e end
							end
							
							for j,e in pairs(AddConstrs)do
								if(!ConstraintTable[j])then ConstraintTable[j] = e end
							end
						end
					end
				end
			end
		end
		
		local PhysObjs = EntTable[Ent:EntIndex()].PhysicsObjects
		for i=0, Ent:GetPhysicsObjectCount() do
			phys = Ent:GetPhysicsObjectNum(i)
			if(IsValid(phys))then
				phys:EnableMotion(PhysObjs[i].Frozen)	//Restore the frozen state of the entity and all of its objects
			end	
		end

	end

	return EntTable, ConstraintTable
end

--[[
	Name: CreateConstraintFromTable
	Desc: Creates a constraint from a given table
	Params: <table>Constraint, <table> EntityList, <table> EntityTable
	Returns: <entity> CreatedConstraint
]]
local function CreateConstraintFromTable(Constraint, EntityList, EntityTable, Player, DontEnable)

	local Factory = duplicator.ConstraintType[ Constraint.Type ]

	if not Factory then return end

	local first --Ent1 or Ent in the constraint's table
	local second --Any other Ent that is not Ent1 or Ent
	
	-- Build the argument list for the Constraint's spawn function
	local Args = {}
	local Val
	for k, Key in pairs( Factory.Args ) do

		Val = Constraint[ Key ]
			
		if Key == "pl" or Key == "ply" then
			Val = Player
		end
			
		for i=1, 4 do 
		--	if(!ValidEntity(Constraint.Entity[i])) then Player:ChatPrint("DUPLICATOR: ERROR, Invalid constraints, maybe wrong file version.")return end
			if ( Constraint.Entity and Constraint.Entity[ i ] ) then
				if Key == "Ent"..i or Key == "Ent" then
					if ( Constraint.Entity[ i ].World ) then
						Val = GetWorldEntity()
					else				
						Val = EntityList[ Constraint.Entity[ i ].Index ]

						if not ValidEntity(Val) then
							if(Player)then
								Player:ChatPrint("DUPLICATOR: ERROR, "..Constraint.Type.." Constraint could not find an entity!")
							else
								print("DUPLICATOR: ERROR, "..Constraint.Type.." Constraint could not find an entity!")
							end		
							return
						else	
							if(IsValid(Val:GetPhysicsObject()))then
								Val:GetPhysicsObject():EnableMotion(false)
							end
							--Important for perfect duplication
							--Get which entity is which so we can reposition them before constraining
							if(Key== "Ent" || Key == "Ent1")then
								first=Val
								firstindex = Constraint.Entity[ i ].Index 
							else
								second=Val
								secondindex = Constraint.Entity[ i ].Index 
							end
									
						end		
					end
						
				end
				
				if Key == "Bone"..i or Key == "Bone" then Val = Constraint.Entity[ i ].Bone end

				if Key == "LPos"..i then
					if (Constraint.Entity[i].World && Constraint.Entity[i].LPos)then
						if(i==2 || i==4)then
							Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[1].Index]:GetPos()
						elseif(i==1)then
							if(Constraint.Entity[2])then
								Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[2].Index]:GetPos()
							else
								Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[4].Index]:GetPos()
							end
						end
					elseif( Constraint.Entity[i].LPos ) then
						Val = Constraint.Entity[ i ].LPos
					end
				end

				if Key == "Length"..i then Val = Constraint.Entity[ i ].Length end
			end
			if Key == "WPos"..i then
				if(!Constraint.Entity[1].World)then
					Val = Constraint["WPos"..i] + EntityList[Constraint.Entity[1].Index]:GetPos()
				else
					Val = Constraint["WPos"..i] + EntityList[Constraint.Entity[4].Index]:GetPos()
				end
			end
				
		end
		-- If there's a missing argument then unpack will stop sending at that argument
		Val = Val or false
		table.insert( Args, Val )
		
	end

	local Bone1
	local Bone1Index
	local ReEnableFirst
	local Bone2
	local Bone2Index
	local ReEnableSecond
	if(Constraint.BuildDupeInfo)then
						
		if second ~= nil and not second:IsWorld() and Constraint.BuildDupeInfo.EntityPos ~= nil then
			if(!DontEnable)then ReEnableSecond = second:GetPhysicsObject():IsMoveable() end
			second:GetPhysicsObject():EnableMotion(false)
			second:SetPos(first:GetPos()-Constraint.BuildDupeInfo.EntityPos)
			if(Constraint.BuildDupeInfo.Bone2) then
				Bone2Index = Constraint.BuildDupeInfo.Bone2
				Bone2 = second:GetPhysicsObjectNum(Bone2Index)
				Bone2:EnableMotion(false)
				Bone2:SetPos(second:GetPos() + Constraint.BuildDupeInfo.Bone2Pos)
				Bone2:SetAngle(Constraint.BuildDupeInfo.Bone2Angle)
			end
		end
						
		if first ~= nil and Constraint.BuildDupeInfo.Ent1Ang ~= nil then
			if(!DontEnable)then ReEnableFirst = first:GetPhysicsObject():IsMoveable() end
			first:GetPhysicsObject():EnableMotion(false)
			first:SetAngles(Constraint.BuildDupeInfo.Ent1Ang)
			if(Constraint.BuildDupeInfo.Bone1) then
				Bone1Index = Constraint.BuildDupeInfo.Bone1
				Bone1 = first:GetPhysicsObjectNum(Bone1Index)
				Bone1:EnableMotion(false)
				Bone1:SetPos(first:GetPos() + Constraint.BuildDupeInfo.Bone1Pos)
				Bone1:SetAngle(Constraint.BuildDupeInfo.Bone1Angle)
			end
		end
							
		if second ~= nil and Constraint.BuildDupeInfo.Ent2Ang ~= nil then
			second:SetAngles(Constraint.BuildDupeInfo.Ent2Ang)
		end
							
		if second ~= nil and Constraint.BuildDupeInfo.Ent4Ang ~= nil then
			second:SetAngles(Constraint.BuildDupeInfo.Ent4Ang)
		end
	end
	
	local Ent 
	local status = pcall( function() Ent = Factory.Func( unpack(Args) ) end )
	if not status or not Ent then 
		if(Player)then
			AdvDupe2.Notify(ply, "ERROR, Failed to create "..Constraint.Type.." Constraint!", NOTIFY_ERROR)
		else
			print("DUPLICATOR: ERROR, Failed to create "..Constraint.Type.." Constraint!")
		end
		return 
	end

	Ent.BuildDupeInfo = table.Copy(Constraint.BuildDupeInfo)
	
	//Move the entities back after constraining them
	if(EntityTable)then
		if(first!=nil)then
			first:SetPos(EntityTable[firstindex].BuildDupeInfo.PosReset)
			first:SetAngles(EntityTable[firstindex].BuildDupeInfo.AngleReset)
			if(Bone1)then
				Bone1:SetPos(EntityTable[firstindex].BuildDupeInfo.PosReset + EntityTable[firstindex].BuildDupeInfo.PhysicsObjects[Bone1Index].Pos)
				Bone1:SetAngle(EntityTable[firstindex].PhysicsObjects[Bone1Index].Angle)
				Bone1:Sleep()
			end
			first:GetPhysicsObject():Sleep()
			if(ReEnableFirst)then first:GetPhysicsObject():EnableMotion(true) end
		end
		if(second!=nil)then
			second:SetPos(EntityTable[secondindex].BuildDupeInfo.PosReset)
			second:SetAngles(EntityTable[secondindex].BuildDupeInfo.AngleReset)
			if(Bone2)then
				Bone2:SetPos(EntityTable[secondindex].BuildDupeInfo.PosReset + EntityTable[secondindex].BuildDupeInfo.PhysicsObjects[Bone2Index].Pos)
				Bone2:SetAngle(EntityTable[secondindex].PhysicsObjects[Bone2Index].Angle)
				Bone2:Sleep()
			end
			second:GetPhysicsObject():Sleep()
			if(ReEnableSecond)then second:GetPhysicsObject():EnableMotion(true) end
		end
	end

	if(Ent and Ent.length)then Ent.length = Constraint["length"] end //Fix for weird bug with ropes

	return Ent
end

local function ApplyEntityModifiers( Player, Ent )
	if(!Ent.EntityMods)then return end
	if(Ent.EntityMods["CollisionGroupMod"])then Ent:SetCollisionGroup(Ent.EntityMods["CollisionGroupMod"]) end
	local status, error
	for Type, ModFunction in pairs( duplicator.EntityModifiers ) do
		if ( Ent.EntityMods[ Type ] ) then
			status, error = pcall(ModFunction, Player, Ent, Ent.EntityMods[ Type ] )
			if(!status)then
				Player:ChatPrint('Error applying entity modifer, "'..tostring(Type)..'". ERROR: '..error)
			end
		end
	end
	if(Ent.EntityMods["mass"] && duplicator.EntityModifiers["mass"])then
		status, error = pcall(duplicator.EntityModifiers["mass"], Player, Ent, Ent.EntityMods["mass"] )
		if(!status)then
			Player:ChatPrint('Error applying entity modifer, "mass". ERROR: '..error)
		end
	end

end

local function ApplyBoneModifiers( Player, Ent )
	if(!Ent.BoneMods || !Ent.PhysicsObjects)then return end
	
	local status, error, PhysObject
	for Type, ModFunction in pairs( duplicator.BoneModifiers ) do
		for Bone, Args in pairs( Ent.PhysicsObjects ) do
			if ( Ent.BoneMods[ Bone ] && Ent.BoneMods[ Bone ][ Type ] ) then 
				PhysObject = Ent:GetPhysicsObjectNum( Bone )
				if ( Ent.PhysicsObjects[ Bone ] ) then
					status, error = pcall(ModFunction, Player, Ent, Bone, PhysObject, Ent.BoneMods[ Bone ][ Type ] )
					if(!status)then
						Player:ChatPrint('Error applying bone modifer, "'..tostring(Type)..'". ERROR: '..error)
					end
				end
			end
		end
	end
	
end

--[[
	Name: DoGenericPhysics
	Desc: Applies bone data, generically.
	Params: <player> Player, <table> data
	Returns: <entity> Entity, <table> data
]]
local function DoGenericPhysics( Entity, data, Player )

	if (!data) then return end
	if (!data.PhysicsObjects) then return end
	local Phys
	for Bone, Args in pairs( data.PhysicsObjects ) do
		Phys = Entity:GetPhysicsObjectNum(Bone)
		if ( IsValid(Phys) ) then	
			Phys:SetPos( Args.Pos )
			Phys:SetAngle( Args.Angle )
			//if ( Args.Frozen == true ) then 
				Phys:EnableMotion( false ) 
			//end		
			Player:AddFrozenPhysicsObject( Entity, Phys )
		end	
	end
end

local function reportclass(ply,class)
	umsg.Start("AdvDupe2_ReportClass", ply)
		umsg.String(class)
	umsg.End()
end

local function reportmodel(ply,model)
	umsg.Start("AdvDupe2_ReportModel", ply)
		umsg.String(model)
	umsg.End()
end

--[[
	Name: GenericDuplicatorFunction
	Desc: Override the default duplicator's GenericDuplicatorFunction function
	Params: <player> Player, <table> data
	Returns: <entity> Entity
]]
local function GenericDuplicatorFunction( data, Player )

	local Entity = ents.Create( data.Class )
	if ( !ValidEntity(Entity) ) then 
		if(Player)then
			reportclass(Player,data.Class)
		else
			 print("Advanced Duplicator 2 Invalid Class: "..data.Class)
		end
		return nil
	end
		
	if( !util.IsValidModel(data.Model) )then
		if(Player)then
			reportmodel(Player,data.Model)
		else
			print("Advanced Duplicator 2 Invalid Model: "..data.Model)
		end
		return nil
	end
	
	duplicator.DoGeneric( Entity, data )
	Entity:Spawn()
	Entity:Activate()
	DoGenericPhysics( Entity, data, Player )	
	
	table.Add( Entity:GetTable(), data )
	
	return Entity
	
end

--[[
	Name: MakeProp
	Desc: Make prop without spawn effects
	Params: <player> Player, <vector> Pos, <angle> Ang, <string> Model, <table> PhysicsObject, <table> Data
	Returns: <entity> Prop
]]
local function MakeProp(Player, Pos, Ang, Model, PhysicsObject, Data)

	if( !util.IsValidModel(Model) )then
		if(Player)then
			reportmodel(Player,Data.Model)
		else
			print("Advanced Duplicator 2 Invalid Model: "..Model)
		end
		return nil
	end
		
	Data.Pos = Pos
	Data.Angle = Ang
	Data.Model = Model
	Data.Frozen = true
	// Make sure this is allowed
	if( Player )then
		if ( !gamemode.Call( "PlayerSpawnProp", Player, Model ) ) then return false end
	end

	local Prop = ents.Create( "prop_physics" )
	if !IsValid(Prop) then return false end
	
	duplicator.DoGeneric( Prop, Data )
	Prop:Spawn()
	Prop:Activate()
	DoGenericPhysics( Prop, Data, Player )
	duplicator.DoFlex( Prop, Data.Flex, Data.FlexScale )
	
	return Prop
end

--[[
	Name: CreateEntityFromTable
	Desc: Creates an entity from a given table
	Params: <table> EntTable, <player> Player
	Returns: nil
]]
local function CreateEntityFromTable(EntTable, Player)

	local EntityClass = duplicator.FindEntityClass( EntTable.Class )
	if ( !Player:IsAdmin( ) && !Player:IsSuperAdmin() && !SinglePlayer())then
		if(!AdvDupe2.duplicator.EntityList[EntTable.Class])then 
			Player:ChatPrint([[Entity Class Black listed, "]]..EntTable.Class..[["]]) 
			return nil 
		end
	end
	
	local sent = false
	local status, valid
	local GENERIC = false
	// This class is unregistered. Instead of failing try using a generic
	// Duplication function to make a new copy.
	if (!EntityClass) then
		GENERIC = true
		sent = true

		/*if(EntTable.Class=="prop_effect")then
			sent = gamemode.Call( "PlayerSpawnEffect", Player, EntTable.Model)
		else
			sent = gamemode.Call( "PlayerSpawnSENT", Player, EntTable.Class)
		end
		
		if(!sent)then
			print("Advanced Duplicator 2: Creation rejected for class, : "..EntTable.Class)
			return nil
		end*/
		
		if( SinglePlayer() || AdvDupe2.duplicator.WhiteList[EntTable.Class]  || (EntTable.BuildDupeInfo.IsNPC && (tobool(GetConVarString("AdvDupe2_AllowNPCPasting")) && string.sub(EntTable.Class, 1, 4)=="npc_")))then
			status, valid = pcall(GenericDuplicatorFunction, EntTable, Player )
		else
			print("Advanced Duplicator 2: ENTITY CLASS IS BLACKLISTED, CLASS NAME: "..EntTable.Class)
			return nil
		end
	end
	
	if(!GENERIC)then
		
		// Build the argument list for the Entitie's spawn function
		local ArgList = {}
		local Arg
		for iNumber, Key in pairs( EntityClass.Args ) do

			Arg = nil
		
			// Translate keys from old system
			if ( Key == "pos" || Key == "position" ) then Key = "Pos" end
			if ( Key == "ang" || Key == "Ang" || Key == "angle" ) then Key = "Angle" end
			if ( Key == "model" ) then Key = "Model" end
			if ( Key == "VehicleTable" )then
				EntTable[Key]["KeyValues"] = {vehiclescript=EntTable[Key]["KeyValues"].vehiclescript, limitview=EntTable[Key]["KeyValues"].limitview}
			end
			
			Arg = EntTable[ Key ]
			
			// Special keys
			if ( Key == "Data" ) then Arg = EntTable end
			
			// If there's a missing argument then unpack will stop sending at that argument
			if ( Arg == nil ) then Arg = false end
			
			ArgList[ iNumber ] = Arg
			
		end
		// Create and return the entity
		if(EntTable.Class=="prop_physics")then
			valid = MakeProp(Player, unpack(ArgList)) //Create prop_physics like this because if the model doesn't exist it will cause
		elseif( SinglePlayer() || AdvDupe2.duplicator.WhiteList[EntTable.Class] || (EntTable.BuildDupeInfo.IsNPC && (tobool(GetConVarString("AdvDupe2_AllowNPCPasting")) && string.sub(EntTable.Class, 1, 4)=="npc_")))then
			//Create sents using their spawn function with the arguments we stored earlier
			sent = true

			/*if(!EntTable.BuildDupeInfo.IsVehicle || !EntTable.BuildDupeInfo.IsNPC || EntTable.Class!="prop_ragdoll")then	//These three are auto done
				sent = gamemode.Call( "PlayerSpawnSENT", Player, EntTable.Class)
			end
			
			if(!sent)then
				print("Advanced Duplicator 2: Creation rejected for class, : "..EntTable.Class)
				return nil
			end			*/				
			
			status,valid = pcall(  EntityClass.Func, Player, unpack(ArgList) )
		else
			print("Advanced Duplicator 2: ENTITY CLASS IS BLACKLISTED, CLASS NAME: "..EntTable.Class)
			return nil
		end
	end

	//If its a valid entity send it back to the entities list so we can constrain it
	if( status!=false and IsValid(valid) )then
		if(sent)then
			local iNumPhysObjects = valid:GetPhysicsObjectCount()
			local PhysObj
			for Bone = 0, iNumPhysObjects-1 do 
				PhysObj = valid:GetPhysicsObjectNum( Bone )
				if IsValid(PhysObj) then
					PhysObj:EnableMotion(false)
					Player:AddFrozenPhysicsObject( valid, PhysObj )
				end
			end
			if(EntTable.Skin)then valid:SetSkin(EntTable.Skin) end
			/*if(Player)then
				if(!valid:IsVehicle() && EntTable.Class!="prop_ragdoll" && !valid:IsNPC())then	//These three get called automatically
					if(EntTable.Class=="prop_effect")then
						gamemode.Call("PlayerSpawnedEffect", Player, valid:GetModel(), valid)
					else
						gamemode.Call("PlayerSpawnedSENT", Player, valid)
					end
				end
			end*/
		else
			gamemode.Call( "PlayerSpawnedProp", Player, valid:GetModel(), valid )
		end
		
		valid:GetPhysicsObject():Wake()
		
		return valid
	else
		if(valid==false)then 
			return false
		else
			return nil
		end
	end
	
end

--[[
	Name: Paste
	Desc: Override the default duplicator's paste function
	Params: <player> Player, <table> Entities, <table> Constraints
	Returns: <table> Entities, <table> Constraints
]]

function AdvDupe2.duplicator.Paste( Player, EntityList, ConstraintList, Position, AngleOffset, OrigPos, Parenting )

	table.SortByMember(ConstraintList, "Identity", function(a, b) return a > b end)

	local CreatedEntities = {}
	--
	-- Create entities
	--
	local proppos
	for k, v in pairs( EntityList ) do
		if(!v.BuildDupeInfo)then v.BuildDupeInfo={} end
		v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
		proppos = v.PhysicsObjects[0].Pos
		v.BuildDupeInfo.PhysicsObjects[0].Pos = Vector(0,0,0)
		if( OrigPos )then
			for i,p in pairs(v.BuildDupeInfo.PhysicsObjects) do
				v.PhysicsObjects[i].Pos = p.Pos + proppos + OrigPos
				v.PhysicsObjects[i].Frozen = true
			end
			v.Pos = v.PhysicsObjects[0].Pos
			v.Angle = v.PhysicsObjects[0].Angle
			v.BuildDupeInfo.PosReset = v.Pos
			v.BuildDupeInfo.AngleReset = v.Angle
		else
			for i,p in pairs(v.BuildDupeInfo.PhysicsObjects)do
				v.PhysicsObjects[i].Pos, v.PhysicsObjects[i].Angle = LocalToWorld(p.Pos + proppos, p.Angle, Position, AngleOffset)
				v.PhysicsObjects[i].Frozen = true
			end
			v.Pos = v.PhysicsObjects[0].Pos
			v.BuildDupeInfo.PosReset = v.Pos
			v.Angle = v.PhysicsObjects[0].Angle
			v.BuildDupeInfo.AngleReset = v.Angle
		end

		
		local Ent = CreateEntityFromTable(v, Player)

		if Ent then
			if(Player)then Player:AddCleanup( "AdvDupe2", Ent ) end
			Ent.BoneMods = table.Copy( v.BoneMods )
			Ent.EntityMods = table.Copy( v.EntityMods )
			Ent.PhysicsObjects = table.Copy( v.PhysicsObjects )
			if(v.CollisionGroup)then Ent:SetCollisionGroup(v.CollisionGroup) end
			ApplyEntityModifiers( Player, Ent )
			ApplyBoneModifiers( Player, Ent )
			Ent:SetNotSolid(true)
		elseif(Ent==false)then
			Ent = nil
			ConstraintList = {}
			break
		else
			Ent = nil
		end
		
		CreatedEntities[k] = Ent
	end

	local CreatedConstraints = {}
	local Entity
	--
	-- Create constraints
	--
	
	for k, Constraint in pairs( ConstraintList ) do
		Entity = CreateConstraintFromTable( Constraint, CreatedEntities, EntityList, Player )
		if(IsValid(Entity))then
			table.insert( CreatedConstraints, Entity )
		end
	end
	
	if(Player)then
	
		undo.Create "AdvDupe2_Paste"
		
			for _,v in pairs( CreatedEntities ) do
				--If the entity has a PostEntityPaste function tell it to use it now
				if v.PostEntityPaste then
					v:PostEntityPaste( Player, v, CreatedEntities )
				end
				v:GetPhysicsObject():EnableMotion(false)

				if(EntityList[_].BuildDupeInfo.DupeParentID && Parenting)then
					v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
				end
				v:SetNotSolid(false)
				undo.AddEntity( v )
			end
			
			undo.SetPlayer( Player )
			
		undo.Finish()
		
		//if(Tool)then AdvDupe2.FinishPasting(Player, true) end
	else
	
		for _,v in pairs( CreatedEntities ) do
				--If the entity has a PostEntityPaste function tell it to use it now
			if v.PostEntityPaste then
				v:PostEntityPaste( Player, v, CreatedEntities )
			end
			v:GetPhysicsObject():EnableMotion(false)

			if(EntityList[_].BuildDupeInfo.DupeParentID && Parenting)then
				v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
			end
				
			v:SetNotSolid(false)
		end
	end
	
	return CreatedEntities, CreatedConstraints
end


local function AdvDupe2_Spawn()

	local Queue = AdvDupe2.JobManager.Queue[AdvDupe2.JobManager.CurrentPlayer]
	
	if(IsValid(Queue.Player))then 
		if(Queue.Entity)then
			if(Queue.Current==1)then 
				
				AdvDupe2.InitProgressBar(Queue.Player,"Pasting:")
				Queue.Player.AdvDupe2.Queued = false
			end
			local newpos
			if(Queue.Current>#Queue.SortedEntities)then
				Queue.Entity = false
				Queue.Constraint = true
				Queue.Current = 1
				return
			end
			if(!Queue.SortedEntities[Queue.Current])then Queue.Current = Queue.Current+1 return end
			
			local k = Queue.SortedEntities[Queue.Current]
			local v = Queue.EntityList[k]

			if(!v.BuildDupeInfo)then v.BuildDupeInfo={} end
			if(v.LocalPos)then
				for i,p in pairs(v.PhysicsObjects) do
					v.PhysicsObjects[i] = {Pos=v.LocalPos, Angle=v.LocalAngle} 
				end
			end

			v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
			proppos = v.PhysicsObjects[0].Pos
			v.BuildDupeInfo.PhysicsObjects[0].Pos = Vector(0,0,0)
			if( Queue.OrigPos )then
				for i,p in pairs(v.BuildDupeInfo.PhysicsObjects) do
					v.PhysicsObjects[i].Pos = p.Pos + proppos + Queue.OrigPos
					v.PhysicsObjects[i].Frozen = true
				end
				v.Pos = v.PhysicsObjects[0].Pos
				v.Angle = v.PhysicsObjects[0].Angle
				v.BuildDupeInfo.PosReset = v.Pos
				v.BuildDupeInfo.AngleReset = v.Angle
			else
				for i,p in pairs(v.BuildDupeInfo.PhysicsObjects)do
					
					v.PhysicsObjects[i].Pos, v.PhysicsObjects[i].Angle = LocalToWorld(p.Pos + proppos, p.Angle, Queue.PositionOffset, Queue.AngleOffset)
					v.PhysicsObjects[i].Frozen = true
				end
				v.Pos = v.PhysicsObjects[0].Pos
				v.BuildDupeInfo.PosReset = v.Pos
				v.Angle = v.PhysicsObjects[0].Angle
				v.BuildDupeInfo.AngleReset = v.Angle
			end

			local Ent = CreateEntityFromTable(v, Queue.Player)
			
			if Ent then
				Queue.Player:AddCleanup( "AdvDupe2", Ent )
				Ent.BoneMods = table.Copy( v.BoneMods )
				Ent.EntityMods = table.Copy( v.EntityMods )
				Ent.PhysicsObjects = table.Copy( v.PhysicsObjects )

				ApplyEntityModifiers( Queue.Player, Ent )
				ApplyBoneModifiers( Queue.Player, Ent )

				local Phys = Ent:GetPhysicsObject()
				if(IsValid(Phys))then Phys:EnableMotion(false) Phys:Sleep() end
				if(!Queue.DisableProtection)then Ent:SetNotSolid(true) end
			elseif(Ent==false)then
				Ent = nil
				Queue.Entity = false
				Queue.Constraint = true
				Queue.Current = 1
				Queue.ConstraintList = {}
			else
				Ent = nil
			end
			Queue.CreatedEntities[ k ] = Ent
			
			local perc = math.floor((Queue.Percent*Queue.Current)*100)
			AdvDupe2.UpdateProgressBar(Queue.Player,perc)
			Queue.Current = Queue.Current+1
			if(Queue.Current>#Queue.SortedEntities)then
				Queue.Entity = false
				Queue.Constraint = true
				Queue.Current = 1
			end
			
			if(#AdvDupe2.JobManager.Queue>=AdvDupe2.JobManager.CurrentPlayer+1)then   
				AdvDupe2.JobManager.CurrentPlayer = AdvDupe2.JobManager.CurrentPlayer+1
			else   
				AdvDupe2.JobManager.CurrentPlayer = 1
			end
		else
			if(#Queue.ConstraintList>0)then
			
				if(#AdvDupe2.JobManager.Queue==0)then 
					hook.Remove("Tick", "AdvDupe2_Spawning")
					AdvDupe2.JobManager.PastingHook = false
				end
				if(!Queue.ConstraintList[Queue.Current])then Queue.Current = Queue.Current+1 return end
				
				local Entity = CreateConstraintFromTable( Queue.ConstraintList[Queue.Current], Queue.CreatedEntities, Queue.EntityList, Queue.Player, true )
				
				if IsValid(Entity) then
					table.insert( Queue.CreatedConstraints, Entity )
				end
			elseif(Queue.ConstraintList && Queue.ConstraintList!={})then
				local tbl = {}
				for k,v in pairs(Queue.ConstraintList)do
					table.insert(tbl, v)
				end
				Queue.ConstraintList = tbl
				Queue.Current=0
			end
			local perc = math.floor((Queue.Percent*(Queue.Current+Queue.Plus))*100)
			AdvDupe2.UpdateProgressBar(Queue.Player,perc)
			Queue.Current = Queue.Current+1
		
			
			if(Queue.Current>#Queue.ConstraintList)then
				
				local unfreeze = tobool(Queue.Player:GetInfo("advdupe2_paste_unfreeze")) or false
				local preservefrozenstate = tobool(Queue.Player:GetInfo("advdupe2_preserve_freeze")) or false
			
				//Remove the undo for stopping pasting
				local undos = undo.GetTable()[Queue.Player:UniqueID()]
				local str = "AdvDupe2_"..Queue.Player:UniqueID()
				for i=#undos, 1, -1 do
					if(undos[i] && undos[i].Name == str)then
						undos[i] = nil
						umsg.Start( "Undone", Queue.Player )
							umsg.Long( i )
						umsg.End()
						break
					end
				end

				undo.Create "AdvDupe2"
					local phys
					local edit
					for _,v in pairs( Queue.CreatedEntities ) do
						if(!IsValid(v))then v = nil continue end
						edit = true
						if(Queue.EntityList[_].BuildDupeInfo.DupeParentID!=nil && Queue.Parenting)then
							v:SetParent(Queue.CreatedEntities[Queue.EntityList[_].BuildDupeInfo.DupeParentID])
							if(v.Constraints!=nil)then
								for i,c in pairs(v.Constraints)do
									if(c && constraints[c.Type])then
										edit=false
										break
									end
								end
							end
							if(edit && IsValid(v:GetPhysicsObject()))then
								v:SetCollisionGroup(COLLISION_GROUP_WORLD)
								v:GetPhysicsObject():EnableMotion(false)
								v:GetPhysicsObject():Sleep()
							end
						else
							edit=false
						end
					
					
						--If the entity has a PostEntityPaste function tell it to use it now
						if v.PostEntityPaste then
							v:PostEntityPaste( Queue.Player, v, Queue.CreatedEntities )
						end
						
						if(unfreeze)then
							for i=0, v:GetPhysicsObjectCount() do
								phys = v:GetPhysicsObjectNum(i)
								if(IsValid(phys))then
									phys:EnableMotion(true)	//Unfreeze the entitiy and all of its objects
									phys:Wake()
								end
							end
						elseif(preservefrozenstate)then
							for i=0, v:GetPhysicsObjectCount() do
								phys = v:GetPhysicsObjectNum(i)
								if(IsValid(phys))then
									if(Queue.EntityList[_].BuildDupeInfo.PhysicsObjects[i].Frozen)then
										phys:EnableMotion(true)	//Restore the entity and all of its objects to their original frozen state
										phys:Wake()
									else 
										Queue.Player:AddFrozenPhysicsObject( v, phys ) 
										phys:Sleep()
									end
								end
							end
						else
							for i=0, v:GetPhysicsObjectCount() do
								phys = v:GetPhysicsObjectNum(i)
								if(IsValid(phys))then
									if(phys:IsMoveable())then
										phys:EnableMotion(false)	//Freeze the entitiy and all of its objects
										Queue.Player:AddFrozenPhysicsObject( v, phys )
									end
									phys:Sleep()
								end
							end
						end
						
						if(!edit || !Queue.DisableParents)then 
							v:SetNotSolid(false)
						end
						
						undo.AddEntity( v )
					end
					undo.SetCustomUndoText("Undone "..(Queue.Name or "Advanced Duplication"))
					undo.SetPlayer( Queue.Player )
				undo.Finish()

				hook.Call("AdvDupe_FinishPasting", nil, {{EntityList=Queue.EntityList, CreatedEntities=Queue.CreatedEntities, ConstraintList=Queue.ConstraintList, CreatedConstraints=Queue.CreatedConstraints, HitPos=Queue.PositionOffset}}, 1)
				AdvDupe2.FinishPasting(Queue.Player, true)
				
				table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
				if(#AdvDupe2.JobManager.Queue==0)then
					hook.Remove("Tick", "AdvDupe2_Spawning")
					AdvDupe2.JobManager.PastingHook = false
				end
			end
			if(#AdvDupe2.JobManager.Queue>=AdvDupe2.JobManager.CurrentPlayer+1)then   
				AdvDupe2.JobManager.CurrentPlayer = AdvDupe2.JobManager.CurrentPlayer+1
			else   
				AdvDupe2.JobManager.CurrentPlayer = 1
			end
	
		end
	else
		table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
		if(#AdvDupe2.JobManager.Queue==0)then 
			hook.Remove("Tick", "AdvDupe2_Spawning")
			AdvDupe2.JobManager.PastingHook = false
		end
	end
end

local function ErrorCatchSpawning()

	local status, error = pcall(AdvDupe2_Spawn)
	if(!status)then
		//PUT ERROR LOGGING HERE
		
		local Queue = AdvDupe2.JobManager.Queue[AdvDupe2.JobManager.CurrentPlayer]
		
		local undos = undo.GetTable()[Queue.Player:UniqueID()]
		local str = "AdvDupe2_"..Queue.Player:UniqueID()
		for i=#undos, 1, -1 do
			if(undos[i] && undos[i].Name == str)then
				undos[i] = nil
				umsg.Start( "Undone", Queue.Player )
					umsg.Long( i )
				umsg.End()
				break
			end
		end
		
		for k,v in pairs(Queue.CreatedEntities)do
			if(IsValid(v))then v:Remove() end
		end
		Queue.Player:ChatPrint([[Error spawning your contraptions, "]]..error..[["]])
		AdvDupe2.FinishPasting(Queue.Player, true)
		
		table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
	
		
		if(#AdvDupe2.JobManager.Queue==0)then 
			hook.Remove("Tick", "AdvDupe2_Spawning")
			AdvDupe2.JobManager.PastingHook = false
		else
			if(#Queue<AdvDupe2.JobManager.CurrentPlayer)then    
				AdvDupe2.JobManager.CurrentPlayer = 1
			end
		end
		
	end
end

local function RemoveSpawnedEntities(tbl, i)
	if(!AdvDupe2.JobManager.Queue[i])then return end //Without this some errors come up, double check the errors without this line

	for k,v in pairs(AdvDupe2.JobManager.Queue[i].CreatedEntities)do
		if(IsValid(v))then
			v:Remove()
		end
	end

	AdvDupe2.FinishPasting(AdvDupe2.JobManager.Queue[i].Player, false)
	table.remove(AdvDupe2.JobManager.Queue, i)
	if(#AdvDupe2.JobManager.Queue==0)then
		hook.Remove("Tick", "AdvDupe2_Spawning")
		AdvDupe2.JobManager.PastingHook = false
	end
end

function AdvDupe2.InitPastingQueue(Player, PositionOffset, AngleOffset, OrigPos, Constrs, Parenting, DisableParents, DisableProtection)

	local i = #AdvDupe2.JobManager.Queue+1
	AdvDupe2.JobManager.Queue[i] = {}
	local Queue = AdvDupe2.JobManager.Queue[i]
	Queue.Player = Player
	Queue.SortedEntities = {}
	Queue.EntityList = table.Copy(Player.AdvDupe2.Entities)
	if(Constrs)then
		Queue.ConstraintList = table.Copy(Player.AdvDupe2.Constraints)
	else
		Queue.ConstraintList = {}
	end
	Queue.OrigPos = OrigPos
	for k,v in pairs(Player.AdvDupe2.Entities)do
		table.insert(Queue.SortedEntities, k)
	end

	Queue.Current = 1
	Queue.Name = Player.AdvDupe2.Name
	Queue.Entity = true
	Queue.Constraint = false
	Queue.Parenting = Parenting
	Queue.DisableParents = DisableParents
	Queue.DisableProtection = DisableProtection
	Queue.CreatedEntities = {}
	Queue.CreatedConstraints = {}
	Queue.PositionOffset = PositionOffset or Vector(0,0,0)
	Queue.AngleOffset = AngleOffset or Angle(0,0,0)
	Queue.Plus = #Queue.SortedEntities
	Queue.Percent = 1/(#Queue.SortedEntities+#Queue.ConstraintList)
	AdvDupe2.InitProgressBar(Player,"Queued:")
	Player.AdvDupe2.Queued = true
	if(!AdvDupe2.JobManager.PastingHook)then	
		hook.Add("Tick", "AdvDupe2_Spawning", ErrorCatchSpawning)
		AdvDupe2.JobManager.PastingHook = true
		AdvDupe2.JobManager.CurrentPlayer = 1
	end
	
	undo.Create("AdvDupe2_"..Player:UniqueID())
		undo.SetPlayer(Player)
		undo.SetCustomUndoText(string.format("Undone Advanced Duplication \"%s\"",Player.AdvDupe2.Name))
		undo.AddFunction(RemoveSpawnedEntities, i)
	undo.Finish()
	
end