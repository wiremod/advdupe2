--[[
	Title: Adv. Duplicator 2 Module
	
	Desc: Provides advanced duplication functionality for the Adv. Dupe 2 tool.
	
	Author: TB
	
	Version: 1.0
]]

require "duplicator"

AdvDupe2.duplicator = {} 

AdvDupe2.JobManager = {}
AdvDupe2.JobManager.PastingHook = false
AdvDupe2.JobManager.Queue = {}

local constraints = {Weld=true,  Axis=true, Ballsocket=true, Elastic=true, Hydraulic=true, Motor=true, Muscle=true, Pulley=true, Rope=true, Slider=true, Winch=true}

local function FilterEntityTable(tab)
	local varType
	for k,v in pairs(tab)do
		varType=TypeID(v)
		if(varType==5)then
			tab[k] = FilterEntityTable(tab[k])
		elseif(varType==6 or varType==9)then
			tab[k]=nil
		end
	end
	return tab
end

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
	-- Filter duplicator blocked entities out.
	if Ent.DoNotDuplicate then return nil end

	if(not IsValid(Ent:GetPhysicsObject()))then return nil end

	local Tab = {}

	if Ent.PreEntityCopy then
		local status, valid = pcall(Ent.PreEntityCopy, Ent)
		if(not status)then
			print("AD2 PreEntityCopy Error: "..tostring(valid))
		end
	end

	local EntityClass = duplicator.FindEntityClass( Ent:GetClass() )
	
	local EntTable = table.Copy(Ent:GetTable())
	
	if EntityClass then
		local varType
		for iNumber, Key in pairs( EntityClass.Args ) do
			-- Translate keys from old system
			if(Key=="Pos" or Key=="Model" or Key=="Ang" or Key=="Angle" or Key=="ang" or Key=="angle" or Key=="pos" or Key=="position" or Key=="model")then
				continue
			end
			
			varType=TypeID(EntTable[Key])
			if(varType==5)then
				Tab[ Key ] = FilterEntityTable(EntTable[Key])
				continue
			elseif(varType==9 || varType==6)then
				continue
			end

			Tab[ Key ] = EntTable[ Key ]
		end
		
	end	 

	Tab.BoneMods = table.Copy( Ent.BoneMods )
	if(Ent.EntityMods)then
		Tab.EntityMods = table.Copy(Ent.EntityMods)
	end

	if Ent.PostEntityCopy then
		local status, valid = pcall(Ent.PostEntityCopy, Ent)
		if(not status)then
			print("AD2 PostEntityCopy Error: "..tostring(valid))
		end
	end

	Tab.Pos 			= Ent:GetPos()
	Tab.Class 			= Ent:GetClass()
	Tab.Model 			= Ent:GetModel()
	Tab.Skin 			= Ent:GetSkin()
	Tab.CollisionGroup 	= Ent:GetCollisionGroup()
	Tab.ModelScale 		= Ent:GetModelScale()
	
	if(Tab.Skin==0)then	Tab.Skin = nil end
	if(Tab.ModelScale == 1)then Tab.ModelScale = nil end

	if(Tab.Class == "gmod_cameraprop")then
		Tab.key = Ent:GetNetworkedInt("key")
	end
	-- Allow the entity to override the class
	-- This is a hack for the jeep, since it's real class is different from the one it reports as
	-- (It reports a different class to avoid compatibility problems)
	if Ent.ClassOverride then Tab.Class = Ent.ClassOverride end

	Tab.PhysicsObjects = {}

	-- Physics Objects
	local PhysObj
	for Bone = 0, Ent:GetPhysicsObjectCount()-1 do 
		PhysObj = Ent:GetPhysicsObjectNum( Bone )
		if IsValid(PhysObj) then
			Tab.PhysicsObjects[ Bone ] = Tab.PhysicsObjects[ Bone ] or {}
			if(PhysObj:IsMoveable())then Tab.PhysicsObjects[ Bone ].Frozen = true end
			PhysObj:EnableMotion(false)
			Tab.PhysicsObjects[ Bone ].Pos = PhysObj:GetPos() - Tab.Pos
			Tab.PhysicsObjects[ Bone ].Angle = PhysObj:GetAngles()
		end
	end

	Tab.PhysicsObjects[0].Pos = Tab.Pos - Offset

	Tab.Pos = nil
	if(Tab.Class~="prop_physics")then
		if(not Tab.BuildDupeInfo)then Tab.BuildDupeInfo = {} end
		Tab.BuildDupeInfo.IsNPC = Ent:IsNPC()
		Tab.BuildDupeInfo.IsVehicle = Ent:IsVehicle()
	end
	if( IsValid(Ent:GetParent()) ) then
		if(not Tab.BuildDupeInfo)then Tab.BuildDupeInfo = {} end
		Tab.PhysicsObjects[ 0 ].Angle = Ent:GetAngles()
		Tab.BuildDupeInfo.DupeParentID = Ent:GetParent():EntIndex()
	end

	-- Flexes
	local FlexNum = Ent:GetFlexNum()
	Tab.Flex = Tab.Flex or {}
	local weight
	local flexes
	for i = 0, FlexNum do
		weight = Ent:GetFlexWeight( i )
		if(weight~=0)then
			Tab.Flex[ i ] = weight
			flexes = true
		end
	end
	if(flexes or Ent:GetFlexScale()~=1)then
		Tab.FlexScale = Ent:GetFlexScale()
	else
		Tab.Flex = nil
	end
	
	-- Body Groups
	Tab.BodyG = {}
	for k, v in pairs(Ent:GetBodyGroups()) do
		if ( Ent:GetBodygroup( v.id ) > 0 ) then
			Tab.BodyG[ v.id ] = Ent:GetBodygroup( v.id )
		end
	end
	
	if(table.Count(Tab.BodyG)==0)then
		Tab.BodyG = nil
	end
	
	-- Bone Manipulator
	if ( Ent:HasBoneManipulations() ) then
	
		Tab.BoneManip = {}
		local t
		local s
		local a
		local p
		for i=0, Ent:GetBoneCount() do
			t={}
			s = Ent:GetManipulateBoneScale( i )
			a = Ent:GetManipulateBoneAngles( i )
			p = Ent:GetManipulateBonePosition( i )
			
			if ( s != Vector( 1, 1, 1 ) ) then	t[ 's' ] = s end
			if ( a != Angle( 0, 0, 0 ) ) then	t[ 'a' ] = a end
			if ( p != Vector( 0, 0, 0 ) ) then	t[ 'p' ] = p end
		
			if ( t['s'] or t['a'] or t['p'] ) then
				Tab.BoneManip[ i ] = t
			end
		
		end
	
	end

	if Ent.GetNetworkVars then
		Tab.DT = Ent:GetNetworkVars()
	end

	// Make this function on your SENT if you want to modify the
	//  returned table specifically for your entity.
	if Ent.OnEntityCopyTableFinish then
		local status, valid = pcall(Ent.OnEntityCopyTableFinish, Ent, Tab)
		if(not status)then
			print("AD2 OnEntityCopyTableFinish Error: "..tostring(valid))
		end
	end

	return Tab

end


--[[
	Name: CopyConstraintTable
	Desc: Create a table for constraints
	Params: <table> Constraints
	Returns: <table> Constraints, <table> Entities
]]
local function CopyConstraintTable( Const, Offset )
	if(Const==nil)then return nil, {} end

	-- Filter duplicator blocked constraints out.
	if Const.DoNotDuplicate then return nil, {} end

	local Type = duplicator.ConstraintType[ Const.Type ]
	if(not Type)then return nil, {} end
	local Constraint = {}
	local Entities = {}

	Const.Constraint = nil
	Const.OnDieFunctions=nil
	Constraint.Entity={}
	for k, key in pairs( Type.Args ) do
		if(key~="pl" and not string.find(key, "Ent") and not string.find(key, "Bone"))then
			Constraint[key] = Const[ key ]
		end
	end	

	if((Const["Ent"] and Const["Ent"]:IsWorld()) or IsValid(Const["Ent"]))then
		Constraint.Entity[ 1 ] = {}
		Constraint.Entity[ 1 ].Index = Const["Ent"]:EntIndex()
		if(not Const["Ent"]:IsWorld())then table.insert( Entities, Const["Ent"] ) end
		Constraint.Type = Const.Type
		if(Const.BuildDupeInfo)then Constraint.BuildDupeInfo = table.Copy(Const.BuildDupeInfo) end
	else
		local ent
		for i=1,4 do
			ent = "Ent"..i

			if((Const[ent] and Const[ent]:IsWorld()) or IsValid(Const[ent]))then
				Constraint.Entity[ i ] 				= {}
				Constraint.Entity[ i ].Index 		= Const[ent]:EntIndex()
				Constraint.Entity[ i ].Bone			= Const[ "Bone"..i ]
				Constraint.Entity[ i ].Length		= Const[ "Length"..i ]
				Constraint.Entity[ i ].World		= Const[ "World"..i ]

				if Const[ ent ]:IsWorld() then
					Constraint.Entity[ i ].World = true
					if ( Const[ "LPos"..i ] ) then
						if(i~= 4 and i~=2)then
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

				if(not Const[ent]:IsWorld())then table.insert( Entities, Const[ent] ) end
			end

			if(Const["WPos"..i])then
				if(not Const["Ent1"]:IsWorld())then
					Constraint["WPos"..i] = Const[ "WPos"..i ] - Const["Ent1"]:GetPos()
				else
					Constraint["WPos"..i] = Const[ "WPos"..i ] - Const["Ent4"]:GetPos()
				end
			end
		end	

		Constraint.Type = Const.Type
		if(Const.BuildDupeInfo)then Constraint.BuildDupeInfo = table.Copy(Const.BuildDupeInfo) end
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

	local index = Ent:EntIndex()
	if(EntTable[index])then return EntTable, ConstraintTable end

	EntTable[index] = CopyEntTable(Ent, Offset)
	if(EntTable[index]==nil)then return EntTable, ConstraintTable end

	if ( not constraint.HasConstraints( Ent ) ) then 
		for k,v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects)do
			Ent:GetPhysicsObjectNum(k):EnableMotion(v.Frozen)
		end
		return EntTable, ConstraintTable 
	end

	local ConstTable, EntTab
	for k, Constraint in pairs( Ent.Constraints ) do
		index = Constraint:GetCreationID()
		if(index and not ConstraintTable[index])then
			Constraint.Identity = index
			ConstTable, EntTab = CopyConstraintTable( table.Copy(Constraint:GetTable()), Offset )
			ConstraintTable[index] = ConstTable
			for j,e in pairs(EntTab) do
				if ( e and ( e:IsWorld() or e:IsValid() ) ) and ( not EntTable[e:EntIndex()] ) then
					Copy( e, EntTable, ConstraintTable, Offset )
				end
			end
		end
	end

	for k,v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects)do
		Ent:GetPhysicsObjectNum(k):EnableMotion(v.Frozen)
	end

	return EntTable, ConstraintTable
end
AdvDupe2.duplicator.Copy = Copy

--[[
	Name: AreaCopy
	Desc: Copy based on a box
	Params: <entity> Entity
	Returns: <table> Entities, <table> Constraints
]]
function AdvDupe2.duplicator.AreaCopy( Entities, Offset, CopyOutside )
	local Constraints, EntTable, ConstraintTable = {}, {}, {}
	local index, add, AddEnts, AddConstrs, ConstTable, EntTab
	
	for _,Ent in pairs(Entities) do

		index = Ent:EntIndex()
		EntTable[index] = CopyEntTable(Ent, Offset)
		if(EntTable[index]~=nil)then
		
			if ( not constraint.HasConstraints( Ent ) ) then
				for k,v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects)do
					Ent:GetPhysicsObjectNum(k):EnableMotion(v.Frozen)
				end
			else
				for k,v in pairs(Ent.Constraints)do
					-- Filter duplicator blocked constraints out.
					if v.DoNotDuplicate then continue end
					index = v:GetCreationID()

					if(index and not Constraints[index])then
						v.Identity = v:GetCreationID()
						Constraints[index] = v
					end
				end
				
				for k,v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects)do
					Ent:GetPhysicsObjectNum(k):EnableMotion(v.Frozen)
				end
			end
		end
	end

	for _, Constraint in pairs( Constraints ) do
		ConstTable, EntTab = CopyConstraintTable( table.Copy(Constraint:GetTable()), Offset )
		//If the entity is constrained to an entity outside of the area box, don't copy the constraint.
		if(not CopyOutside)then
			add = true
			for k,v in pairs(EntTab)do
				if(not Entities[v:EntIndex()])then add=false end
			end
			if(add)then ConstraintTable[_] = ConstTable  end
		else	//Copy entities and constraints outside of the box that are constrained to entities inside the box
			ConstraintTable[_] = ConstTable
			for k,v in pairs(EntTab)do
				Copy(v, EntTable, ConstraintTable, Offset)
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
			if ( Constraint.Entity and Constraint.Entity[ i ] ) then
				if Key == "Ent"..i or Key == "Ent" then
					if ( Constraint.Entity[ i ].World ) then
						Val = game.GetWorld()
					else				
						Val = EntityList[ Constraint.Entity[ i ].Index ]

						if not IsValid(Val) then
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
							if(Key== "Ent" or Key == "Ent1")then
								first=Val
								firstindex = Constraint.Entity[ i ].Index 
							else
								second=Val
								secondindex = Constraint.Entity[ i ].Index 
							end
									
						end		
					end

				end

				if Key == "Bone"..i or Key == "Bone" then Val = Constraint.Entity[ i ].Bone or 0 end

				if Key == "LPos"..i then
					if (Constraint.Entity[i].World and Constraint.Entity[i].LPos)then
						if(i==2 or i==4)then
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
				if(not Constraint.Entity[1].World)then
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
			local SecondPhys = second:GetPhysicsObject()
			if IsValid(SecondPhys) then
				if not DontEnable then ReEnableSecond = SecondPhys:IsMoveable() end
				SecondPhys:EnableMotion(false)
				second:SetPos(first:GetPos()-Constraint.BuildDupeInfo.EntityPos)
				if(Constraint.BuildDupeInfo.Bone2) then
					Bone2Index = Constraint.BuildDupeInfo.Bone2
					Bone2 = second:GetPhysicsObjectNum(Bone2Index)
					if IsValid(Bone2) then
						Bone2:EnableMotion(false)
						Bone2:SetPos(second:GetPos() + Constraint.BuildDupeInfo.Bone2Pos)
						Bone2:SetAngles(Constraint.BuildDupeInfo.Bone2Angle)
					end
				end
			end
		end

		if first ~= nil and Constraint.BuildDupeInfo.Ent1Ang ~= nil then
			local FirstPhys = first:GetPhysicsObject()
			if IsValid(FirstPhys) then
				if not DontEnable then ReEnableFirst = FirstPhys:IsMoveable() end
				FirstPhys:EnableMotion(false)
				first:SetAngles(Constraint.BuildDupeInfo.Ent1Ang)
				if(Constraint.BuildDupeInfo.Bone1) then
					Bone1Index = Constraint.BuildDupeInfo.Bone1
					Bone1 = first:GetPhysicsObjectNum(Bone1Index)
					if IsValid(Bone1) then
						Bone1:EnableMotion(false)
						Bone1:SetPos(first:GetPos() + Constraint.BuildDupeInfo.Bone1Pos)
						Bone1:SetAngles(Constraint.BuildDupeInfo.Bone1Angle)
					end
				end
			end
		end

		if second ~= nil and Constraint.BuildDupeInfo.Ent2Ang ~= nil then
			second:SetAngles(Constraint.BuildDupeInfo.Ent2Ang)
		end

		if second ~= nil and Constraint.BuildDupeInfo.Ent4Ang ~= nil then
			second:SetAngles(Constraint.BuildDupeInfo.Ent4Ang)
		end
	end

	local status, Ent = pcall( Factory.Func, unpack(Args))

	if not status or not Ent then 
		if(Player)then
			AdvDupe2.Notify(Player, "ERROR, Failed to create "..Constraint.Type.." Constraint!", NOTIFY_ERROR)
		else
			print("DUPLICATOR: ERROR, Failed to create "..Constraint.Type.." Constraint!")
		end
		return 
	end

	Ent.BuildDupeInfo = table.Copy(Constraint.BuildDupeInfo)

	//Move the entities back after constraining them
	if(EntityTable)then
		if(first~=nil)then
			first:SetPos(EntityTable[firstindex].BuildDupeInfo.PosReset)
			first:SetAngles(EntityTable[firstindex].BuildDupeInfo.AngleReset)
			if(IsValid(Bone1) and Bone1Index~=0)then
				Bone1:SetPos(EntityTable[firstindex].BuildDupeInfo.PosReset + EntityTable[firstindex].BuildDupeInfo.PhysicsObjects[Bone1Index].Pos)
				Bone1:SetAngles(EntityTable[firstindex].PhysicsObjects[Bone1Index].Angle)
			end

			local FirstPhys = first:GetPhysicsObject()
			if IsValid(FirstPhys) then
				if ReEnableFirst then
					FirstPhys:EnableMotion(true)
				end
			end
		end
		if(second~=nil)then
			second:SetPos(EntityTable[secondindex].BuildDupeInfo.PosReset)
			second:SetAngles(EntityTable[secondindex].BuildDupeInfo.AngleReset)
			if(IsValid(Bone2) and Bone2Index~=0)then
				Bone2:SetPos(EntityTable[secondindex].BuildDupeInfo.PosReset + EntityTable[secondindex].BuildDupeInfo.PhysicsObjects[Bone2Index].Pos)
				Bone2:SetAngles(EntityTable[secondindex].PhysicsObjects[Bone2Index].Angle)
			end

			local SecondPhys = second:GetPhysicsObject()
			if IsValid(SecondPhys) then
				if ReEnableSecond then
					SecondPhys:EnableMotion(true)
				end
			end
		end
	end

	if(Ent and Ent.length)then Ent.length = Constraint["length"] end //Fix for weird bug with ropes

	return Ent
end

local function ApplyEntityModifiers( Player, Ent )
	if(not Ent.EntityMods)then return end
	local status, error
	for Type, Data in pairs( Ent.EntityMods ) do
		local ModFunction = duplicator.EntityModifiers[ Type ]
		if ( ModFunction ) then
			status, error = pcall(ModFunction, Player, Ent, Data )
			if(not status)then
				if(Player)then
					Player:ChatPrint('Error applying entity modifer, "'..tostring(Type)..'". ERROR: '..error)
				else
					print('Error applying entity modifer, "'..tostring(Type)..'". ERROR: '..error)
				end
			end
		end
	end
	if(Ent.EntityMods["mass"] and duplicator.EntityModifiers["mass"])then
		status, error = pcall(duplicator.EntityModifiers["mass"], Player, Ent, Ent.EntityMods["mass"] )
		if(not status)then
			if(Player)then
				Player:ChatPrint('Error applying entity modifer, "mass". ERROR: '..error)
			else
				print('Error applying entity modifer, "'..tostring(Type)..'". ERROR: '..error)
			end
		end
	end

end

local function ApplyBoneModifiers( Player, Ent )
	if(not Ent.BoneMods or not Ent.PhysicsObjects)then return end

	local status, error, PhysObject
	for Type, ModFunction in pairs( duplicator.BoneModifiers ) do
		for Bone, Args in pairs( Ent.PhysicsObjects ) do
			if ( Ent.BoneMods[ Bone ] and Ent.BoneMods[ Bone ][ Type ] ) then 
				PhysObject = Ent:GetPhysicsObjectNum( Bone )
				if ( Ent.PhysicsObjects[ Bone ] ) then
					status, error = pcall(ModFunction, Player, Ent, Bone, PhysObject, Ent.BoneMods[ Bone ][ Type ] )
					if(not status)then
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

	if (not data) then return end
	if (not data.PhysicsObjects) then return end
	local Phys
	if(Player)then
		for Bone, Args in pairs( data.PhysicsObjects ) do
			Phys = Entity:GetPhysicsObjectNum(Bone)
			if ( IsValid(Phys) ) then	
				Phys:SetPos( Args.Pos )
				Phys:SetAngles( Args.Angle )
				Phys:EnableMotion( false ) 	
				Player:AddFrozenPhysicsObject( Entity, Phys )
			end	
		end
	else
		for Bone, Args in pairs( data.PhysicsObjects ) do
			Phys = Entity:GetPhysicsObjectNum(Bone)
			if ( IsValid(Phys) ) then	
				Phys:SetPos( Args.Pos )
				Phys:SetAngles( Args.Angle )
				Phys:EnableMotion( false ) 	
			end	
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
	if ( not IsValid(Entity) ) then 
		if(Player)then
			reportclass(Player,data.Class)
		else
			 print("Advanced Duplicator 2 Invalid Class: "..data.Class)
		end
		return nil
	end

	if( not util.IsValidModel(data.Model) and not file.Exists( data.Model, "GAME" ) )then
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

	if( not util.IsValidModel(Model) and not file.Exists( Data.Model, "GAME" ) )then
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
		if ( not gamemode.Call( "PlayerSpawnProp", Player, Model ) ) then return false end
	end

	local Prop = ents.Create( "prop_physics" )
	if not IsValid(Prop) then return false end

	duplicator.DoGeneric( Prop, Data )
	Prop:Spawn()
	Prop:Activate()
	DoGenericPhysics( Prop, Data, Player )
	if(Data.Flex)then duplicator.DoFlex( Prop, Data.Flex, Data.FlexScale ) end

	return Prop
end

local function RestoreBodyGroups( ent, BodyG )
	for k, v in pairs( BodyG ) do
		ent:SetBodygroup( k, v )
	end
end

--[[
	Name: CreateEntityFromTable
	Desc: Creates an entity from a given table
	Params: <table> EntTable, <player> Player
	Returns: nil
]]
local function IsAllowed(Player, Class, EntityClass)
	if ( scripted_ents.GetMember( Class, "DoNotDuplicate" ) ) then return false end

	if ( IsValid( Player ) and !Player:IsAdmin()) then
		if !duplicator.IsAllowed(Class) then return false end
		if ( !scripted_ents.GetMember( Class, "Spawnable" ) and not EntityClass ) then return false end
		if ( scripted_ents.GetMember( Class, "AdminOnly" ) ) then return false end
	end
	return true
end

local function CreateEntityFromTable(EntTable, Player)

	local EntityClass = duplicator.FindEntityClass( EntTable.Class )
	if not IsAllowed(Player, EntTable.Class, EntityClass) then
		Player:ChatPrint([[Entity Class Black listed, "]]..EntTable.Class..[["]]) 
		return nil 
	end

	local sent = false
	local status, valid
	local GENERIC = false

	// This class is unregistered. Instead of failing try using a generic
	// Duplication function to make a new copy.
	if (not EntityClass) then
		GENERIC = true
		sent = true

		if(EntTable.Class=="prop_effect")then
			sent = gamemode.Call( "PlayerSpawnEffect", Player, EntTable.Model)
		else
			sent = gamemode.Call( "PlayerSpawnSENT", Player, EntTable.Class)
		end

		if(sent==false)then
			print("Advanced Duplicator 2: Creation rejected for class, : "..EntTable.Class)
			return nil
		else
			sent = true
		end

		if IsAllowed(Player, EntTable.Class, EntityClass) then
			status, valid = pcall(GenericDuplicatorFunction, EntTable, Player )
		else
			print("Advanced Duplicator 2: ENTITY CLASS IS BLACKLISTED, CLASS NAME: "..EntTable.Class)
			return nil
		end
	end

	if(not GENERIC)then

		// Build the argument list for the Entitie's spawn function
		local ArgList = {}
		local Arg
		for iNumber, Key in pairs( EntityClass.Args ) do

			Arg = nil
			// Translate keys from old system
			if ( Key == "pos" or Key == "position" ) then Key = "Pos" end
			if ( Key == "ang" or Key == "Ang" or Key == "angle" ) then Key = "Angle" end
			if ( Key == "model" ) then Key = "Model" end
			if ( Key == "VehicleTable" and EntTable[Key] and EntTable[Key].KeyValues)then
				EntTable[Key].KeyValues = {vehiclescript=EntTable[Key].KeyValues.vehiclescript, limitview=EntTable[Key].KeyValues.limitview}
			end

			Arg = EntTable[ Key ]

			// Special keys
			if ( Key == "Data" ) then Arg = EntTable end

			// If there's a missing argument then unpack will stop sending at that argument
			ArgList[ iNumber ] = Arg or false

		end
		
		// Create and return the entity
		if(EntTable.Class=="prop_physics")then
			valid = MakeProp(Player, unpack(ArgList)) //Create prop_physics like this because if the model doesn't exist it will cause
		elseif IsAllowed(Player, EntTable.Class, EntityClass) then
			//Create sents using their spawn function with the arguments we stored earlier
			sent = true

			if(not EntTable.BuildDupeInfo.IsVehicle and not EntTable.BuildDupeInfo.IsNPC and EntTable.Class~="prop_ragdoll")then	//These three are auto done
				sent = hook.Call("PlayerSpawnSENT", nil, Player, EntTable.Class)
			end

			if(sent==false)then
				print("Advanced Duplicator 2: Creation rejected for class, : "..EntTable.Class)
				return nil
			else
				sent = true
			end		
			
			status,valid = pcall(  EntityClass.Func, Player, unpack(ArgList) )
		else
			print("Advanced Duplicator 2: ENTITY CLASS IS BLACKLISTED, CLASS NAME: "..EntTable.Class)
			return nil
		end
	end

	//If its a valid entity send it back to the entities list so we can constrain it
	if( status~=false and IsValid(valid) )then
		if(sent)then
			local iNumPhysObjects = valid:GetPhysicsObjectCount()
			local PhysObj
			if(Player)then
				for Bone = 0, iNumPhysObjects-1 do 
					PhysObj = valid:GetPhysicsObjectNum( Bone )
					if IsValid(PhysObj) then
						PhysObj:EnableMotion(false)
						Player:AddFrozenPhysicsObject( valid, PhysObj )
					end
				end
			else
				for Bone = 0, iNumPhysObjects-1 do 
					PhysObj = valid:GetPhysicsObjectNum( Bone )
					if IsValid(PhysObj) then
						PhysObj:EnableMotion(false)
					end
				end
			end
			if(EntTable.Skin)then valid:SetSkin(EntTable.Skin) end
			if ( EntTable.BodyG ) then RestoreBodyGroups( valid, EntTable.BodyG ) end

			if valid.RestoreNetworkVars then
				valid:RestoreNetworkVars(EntTable.DT)
			end
			
			if GENERIC then
				if(EntTable.Class=="prop_effect")then
					gamemode.Call("PlayerSpawnedEffect", Player, valid:GetModel(), valid)
				else
					gamemode.Call("PlayerSpawnedSENT", Player, valid)
				end
			end
			
		elseif(Player)then
			gamemode.Call( "PlayerSpawnedProp", Player, valid:GetModel(), valid )
		end

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

	local CreatedEntities = {}
	--
	-- Create entities
	--
	local proppos
	DisablePropCreateEffect = true
	for k, v in pairs( EntityList ) do
		if(not v.BuildDupeInfo)then v.BuildDupeInfo={} end
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
			if(Ent.OnDuplicated)then Ent:OnDuplicated(v) end
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
					local status, valid = pcall(v.PostEntityPaste, v, Player, v, CreatedEntities)
					if(not status)then
						print("AD2 PostEntityPaste Error: "..tostring(valid))
					end
				end
				v:GetPhysicsObject():EnableMotion(false)

				if(EntityList[_].BuildDupeInfo.DupeParentID and Parenting)then
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
				local status, valid = pcall(v.PostEntityPaste, v, Player, v, CreatedEntities)
				if(not status)then
					print("AD2 PostEntityPaste Error: "..tostring(valid))
				end
			end
			v:GetPhysicsObject():EnableMotion(false)

			if(EntityList[_].BuildDupeInfo.DupeParentID and Parenting)then
				v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
			end

			v:SetNotSolid(false)
		end
	end
	DisablePropCreateEffect = nil
	hook.Call("AdvDupe_FinishPasting", nil, {{EntityList=EntityList, CreatedEntities=CreatedEntities, ConstraintList=ConstraintList, CreatedConstraints=CreatedConstraints, HitPos=OrigPos or Position, Player=Player}}, 1)
	
	return CreatedEntities, CreatedConstraints
end

local ticktotal = 0
local function AdvDupe2_Spawn()
	
	ticktotal = ticktotal + AdvDupe2.SpawnRate
	if(ticktotal<1)then
		return
	end
	
	ticktotal = ticktotal - 1
		
	
	local Queue = AdvDupe2.JobManager.Queue[AdvDupe2.JobManager.CurrentPlayer]

	if(not Queue or not IsValid(Queue.Player))then
		if Queue then
			table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
		end
		if(#AdvDupe2.JobManager.Queue==0)then 
			hook.Remove("Tick", "AdvDupe2_Spawning")
			DisablePropCreateEffect = nil
			AdvDupe2.JobManager.PastingHook = false
		end
		return
	end

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
		if(not Queue.SortedEntities[Queue.Current])then Queue.Current = Queue.Current+1 return end

		local k = Queue.SortedEntities[Queue.Current]
		local v = Queue.EntityList[k]

		if(not v.BuildDupeInfo)then v.BuildDupeInfo={} end
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

			local Phys = Ent:GetPhysicsObject()
			if(IsValid(Phys))then Phys:EnableMotion(false) end
			if(not Queue.DisableProtection)then Ent:SetNotSolid(true) end
			if(v.CollisionGroup)then Ent:SetCollisionGroup(v.CollisionGroup) end
			if(Ent.OnDuplicated)then Ent:OnDuplicated(v) end
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
		
		AdvDupe2.UpdateProgressBar(Queue.Player, math.floor((Queue.Percent*Queue.Current)*100))
		Queue.Current = Queue.Current+1
		if(Queue.Current>#Queue.SortedEntities)then
			
			for _,Ent in pairs(Queue.CreatedEntities)do
				ApplyEntityModifiers( Queue.Player, Ent )
				ApplyBoneModifiers( Queue.Player, Ent )
			
				--If the entity has a PostEntityPaste function tell it to use it now
				if Ent.PostEntityPaste then
					local status, valid = pcall(Ent.PostEntityPaste, Ent, Queue.Player, Ent, Queue.CreatedEntities)
					if(not status)then
						print("AD2 PostEntityPaste Error: "..tostring(valid))
					end
				end
			end
		
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
				DisablePropCreateEffect = nil
				AdvDupe2.JobManager.PastingHook = false
			end
			if(not Queue.ConstraintList[Queue.Current])then Queue.Current = Queue.Current+1 return end

			local Entity = CreateConstraintFromTable( Queue.ConstraintList[Queue.Current], Queue.CreatedEntities, Queue.EntityList, Queue.Player, true )
			if IsValid(Entity) then
				table.insert( Queue.CreatedConstraints, Entity )
			end
		elseif(table.Count(Queue.ConstraintList)>0)then
			local tbl = {}
			for k,v in pairs(Queue.ConstraintList)do
				table.insert(tbl, v)
			end
			Queue.ConstraintList = tbl
			Queue.Current=0
		end

		AdvDupe2.UpdateProgressBar(Queue.Player, math.floor((Queue.Percent*(Queue.Current+Queue.Plus))*100))
		Queue.Current = Queue.Current+1

		if(Queue.Current>#Queue.ConstraintList)then

			local unfreeze = tobool(Queue.Player:GetInfo("advdupe2_paste_unfreeze")) or false
			local preservefrozenstate = tobool(Queue.Player:GetInfo("advdupe2_preserve_freeze")) or false

			//Remove the undo for stopping pasting
			local undos = undo.GetTable()[Queue.Player:UniqueID()]
			local str = "AdvDupe2_"..Queue.Player:UniqueID()
			for i=#undos, 1, -1 do
				if(undos[i] and undos[i].Name == str)then
					undos[i] = nil
					-- Undo module netmessage
					net.Start( "Undo_Undone" )
					net.WriteInt( i, 16 )
					net.Send( Queue.Player )
					break
				end
			end

			undo.Create "AdvDupe2"
				local phys
				local edit
				local mass
				for _,v in pairs( Queue.CreatedEntities ) do
					if(not IsValid(v))then 
						v = nil
					else
						edit = true
						if(Queue.EntityList[_].BuildDupeInfo.DupeParentID~=nil and Queue.Parenting)then
							v:SetParent(Queue.CreatedEntities[Queue.EntityList[_].BuildDupeInfo.DupeParentID])
							if(v.Constraints~=nil)then
								for i,c in pairs(v.Constraints)do
									if(c and constraints[c.Type])then
										edit=false
										break
									end
								end
							end
							if(edit and IsValid(v:GetPhysicsObject()))then
								mass = v:GetPhysicsObject():GetMass()
								v:PhysicsInitShadow(false, false)
								v:SetCollisionGroup(COLLISION_GROUP_WORLD)
								v:GetPhysicsObject():EnableMotion(false)
								v:GetPhysicsObject():Sleep()
								v:GetPhysicsObject():SetMass(mass)
							end
						else
							edit=false
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
								end
							end
						end

						if(not edit or not Queue.DisableParents)then 
							v:SetNotSolid(false)
						end

						undo.AddEntity( v )
					end
				end
				undo.SetCustomUndoText("Undone "..(Queue.Name or "Advanced Duplication"))
				undo.SetPlayer( Queue.Player )
			undo.Finish()

			hook.Call("AdvDupe_FinishPasting", nil, {{EntityList=Queue.EntityList, CreatedEntities=Queue.CreatedEntities, ConstraintList=Queue.ConstraintList, CreatedConstraints=Queue.CreatedConstraints, HitPos=Queue.PositionOffset, Player=Queue.Player}}, 1)
			AdvDupe2.FinishPasting(Queue.Player, true)

			table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
			if(#AdvDupe2.JobManager.Queue==0)then
				hook.Remove("Tick", "AdvDupe2_Spawning")
				DisablePropCreateEffect = nil
				AdvDupe2.JobManager.PastingHook = false
			end
		end
		if(#AdvDupe2.JobManager.Queue>=AdvDupe2.JobManager.CurrentPlayer+1)then   
			AdvDupe2.JobManager.CurrentPlayer = AdvDupe2.JobManager.CurrentPlayer+1
		else   
			AdvDupe2.JobManager.CurrentPlayer = 1
		end
	end
end

local function ErrorCatchSpawning()

	local status, error = pcall(AdvDupe2_Spawn)

	if(not status)then
		//PUT ERROR LOGGING HERE
		
		if(not AdvDupe2.JobManager.Queue)then
			print("[AdvDupe2Notify]\t"..error)
			AdvDupe2.JobManager.Queue = {}
			return
		end
		
		local Queue = AdvDupe2.JobManager.Queue[AdvDupe2.JobManager.CurrentPlayer]
		if(not Queue)then
			print("[AdvDupe2Notify]\t"..error)
			return
		end
		
		if(IsValid(Queue.Player))then
			AdvDupe2.Notify(Queue.Player, error)
			
			local undos = undo.GetTable()[Queue.Player:UniqueID()]
			local str = "AdvDupe2_"..Queue.Player:UniqueID()
			for i=#undos, 1, -1 do
				if(undos[i] and undos[i].Name == str)then
					undos[i] = nil
					-- Undo module netmessage
					net.Start( "Undo_Undone" )
					net.WriteInt( i, 16 )
					net.Send( Queue.Player )
					break
				end
			end
		else
			print("[AdvDupe2Notify]\t"..error)
		end

		for k,v in pairs(Queue.CreatedEntities)do
			if(IsValid(v))then v:Remove() end
		end

		if(IsValid(Queue.Player))then
			AdvDupe2.FinishPasting(Queue.Player, true)
		end

		table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)

		if(#AdvDupe2.JobManager.Queue==0)then 
			hook.Remove("Tick", "AdvDupe2_Spawning")
			DisablePropCreateEffect = nil
			AdvDupe2.JobManager.PastingHook = false
		else
			if(#Queue<AdvDupe2.JobManager.CurrentPlayer)then    
				AdvDupe2.JobManager.CurrentPlayer = 1
			end
		end

	end
end

local function RemoveSpawnedEntities(tbl, i)
	if(not AdvDupe2.JobManager.Queue[i])then return end //Without this some errors come up, double check the errors without this line

	for k,v in pairs(AdvDupe2.JobManager.Queue[i].CreatedEntities)do
		if(IsValid(v))then
			v:Remove()
		end
	end

	AdvDupe2.FinishPasting(AdvDupe2.JobManager.Queue[i].Player, false)
	table.remove(AdvDupe2.JobManager.Queue, i)
	if(#AdvDupe2.JobManager.Queue==0)then
		hook.Remove("Tick", "AdvDupe2_Spawning")
		DisablePropCreateEffect = nil
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

	if(Player.AdvDupe2.Name)then
		print("[AdvDupe2NotifyPaste]\t Player: "..Player:Nick().." Pasted File, "..Player.AdvDupe2.Name.." with, "..#Queue.SortedEntities.." Entities and "..#Player.AdvDupe2.Constraints.." Constraints.")
	else
		print("[AdvDupe2NotifyPaste]\t Player: "..Player:Nick().." Pasted, "..#Queue.SortedEntities.." Entities and "..#Player.AdvDupe2.Constraints.." Constraints.")
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
	if(not AdvDupe2.JobManager.PastingHook)then
		DisablePropCreateEffect = true
		hook.Add("Tick", "AdvDupe2_Spawning", ErrorCatchSpawning)
		AdvDupe2.JobManager.PastingHook = true
		AdvDupe2.JobManager.CurrentPlayer = 1
	end

	undo.Create("AdvDupe2_"..Player:UniqueID())
		undo.SetPlayer(Player)
		undo.SetCustomUndoText("Undone " .. (Player.AdvDupe2.Name or ""))
		undo.AddFunction(RemoveSpawnedEntities, i)
	undo.Finish()
end
