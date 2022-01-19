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

local constraints = {
	Weld       = true,
	Axis       = true,
	Ballsocket = true,
	Elastic    = true,
	Hydraulic  = true,
	Motor      = true,
	Muscle     = true,
	Pulley     = true,
	Rope       = true,
	Slider     = true,
	Winch      = true
}

local serializable = {
	[TYPE_BOOL]   = true,
	[TYPE_NUMBER] = true,
	[TYPE_VECTOR] = true,
	[TYPE_ANGLE]  = true,
	[TYPE_TABLE]  = true,
	[TYPE_STRING] = true
}

local function CopyClassArgTable(tab)
	local done = {}
	local function recursiveCopy(oldtable)
		local newtable = {}
		done[oldtable] = newtable
		for k, v in pairs(oldtable) do
			local varType = TypeID(v)
			if serializable[varType] then
				if varType == TYPE_TABLE then
					if done[v] then
						newtable[k] = done[v]
					else
						newtable[k] = recursiveCopy(v)
					end
				else
					newtable[k] = v
				end
			else
				print("[AdvDupe2] ClassArg table with key \"" .. tostring(k) .. "\" has unsupported value of type \"".. type(v) .."\"!\n")
			end
		end
		return newtable
	end
	return recursiveCopy(tab)
end

--[[
	Name: CopyEntTable
	Desc: Returns a copy of the passed entity's table
	Params: <entity> Ent
	Returns: <table> enttable
]]

--[[---------------------------------------------------------
	Returns a copy of the passed entity's table
---------------------------------------------------------]]

local gtSetupTable = {
	POS = {
		["pos"     ] = true,
		["position"] = true,
		["Pos"     ] = true,
		["Position"] = true
	},
	ANG = {
		["ang"     ] = true,
		["angle"   ] = true,
		["Ang"     ] = true,
		["Angle"   ] = true
	},
	MODEL = {
		["model"   ] = true,
		["Model"   ] = true
	},
	PLAYER = {
		["pl"      ] = true,
		["ply"     ] = true
	},
	ENT1 = {
		["Ent"     ] = true,
		["Ent1"    ] = true,
	},
	COMPARE = {
		V1 = Vector(1, 1, 1),
		A0 = Angle (0, 0, 0),
		V0 = Vector(0, 0, 0)
	},
	TVEHICLE = {
		["VehicleTable"] = true
	},
	SPECIAL = {
		["Data"] = true
	}
}

function AdvDupe2.duplicator.IsCopyable(Ent)
	return not Ent.DoNotDuplicate and duplicator.IsAllowed(Ent:GetClass()) and IsValid(Ent:GetPhysicsObject())
end

local function CopyEntTable(Ent, Offset)
	-- Filter duplicator blocked entities out.
	if not AdvDupe2.duplicator.IsCopyable(Ent) then return nil end

	local Tab = {}

	if Ent.PreEntityCopy then
		local status, valid = pcall(Ent.PreEntityCopy, Ent)
		if (not status) then print("AD2 PreEntityCopy Error: " .. tostring(valid)) end
	end

	local EntityClass = duplicator.FindEntityClass(Ent:GetClass())

	local EntTable = Ent:GetTable()

	if EntityClass then
		for iNumber, Key in pairs(EntityClass.Args) do
			-- Ignore keys from old system
			if (not gtSetupTable.POS[Key] and
					not gtSetupTable.ANG[Key] and
					not gtSetupTable.MODEL[Key]) then
				local varType = TypeID(EntTable[Key])
				if serializable[varType] then
					if varType == TYPE_TABLE then
						Tab[Key] = CopyClassArgTable(EntTable[Key])
					else
						Tab[Key] = EntTable[Key]
					end
				elseif varType ~= TYPE_NIL then
					print("[AdvDupe2] Entity ClassArg \"" .. Key .. "\" of type \"" .. Ent:GetClass() ..
									"\" has unsupported value of type \"" .. type(EntTable[Key]) .. "\"!\n")
				end
			end
		end
	end

	Tab.BoneMods = table.Copy(Ent.BoneMods)
	if(Ent.EntityMods)then
		Tab.EntityMods = table.Copy(Ent.EntityMods)
	end

	if Ent.PostEntityCopy then
		local status, valid = pcall(Ent.PostEntityCopy, Ent)
		if(not status)then
			print("AD2 PostEntityCopy Error: "..tostring(valid))
		end
	end

	Tab.Pos   = Ent:GetPos()
	Tab.Class = Ent:GetClass()
	Tab.Model = Ent:GetModel()
	Tab.Skin  = Ent:GetSkin()
	Tab.CollisionGroup = Ent:GetCollisionGroup()
	Tab.ModelScale = Ent:GetModelScale()

	if (Tab.Skin == 0) then Tab.Skin = nil end
	if (Tab.ModelScale == 1) then Tab.ModelScale = nil end

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
	for Bone = 0, Ent:GetPhysicsObjectCount() - 1 do
		PhysObj = Ent:GetPhysicsObjectNum(Bone)
		if IsValid(PhysObj) then
			Tab.PhysicsObjects[Bone] = Tab.PhysicsObjects[Bone] or {}
			if (PhysObj:IsMoveable()) then Tab.PhysicsObjects[Bone].Frozen = true end
			PhysObj:EnableMotion(false)
			Tab.PhysicsObjects[Bone].Pos = PhysObj:GetPos() - Tab.Pos
			Tab.PhysicsObjects[Bone].Angle = PhysObj:GetAngles()
		end
	end

	Tab.PhysicsObjects[0].Pos = Tab.Pos - Offset

	Tab.Pos = nil
	if (Tab.Class ~= "prop_physics") then
		if (not Tab.BuildDupeInfo) then Tab.BuildDupeInfo = {} end
		Tab.BuildDupeInfo.IsNPC = Ent:IsNPC()
		Tab.BuildDupeInfo.IsVehicle = Ent:IsVehicle()
	end
	if (IsValid(Ent:GetParent())) then
		if (not Tab.BuildDupeInfo) then Tab.BuildDupeInfo = {} end
		Tab.PhysicsObjects[0].Angle = Ent:GetAngles()
		Tab.BuildDupeInfo.DupeParentID = Ent:GetParent():EntIndex()
	end

	-- Flexes
	local FlexNum = Ent:GetFlexNum()
	Tab.Flex = Tab.Flex or {}
	local weight
	local flexes
	for i = 0, FlexNum do
		weight = Ent:GetFlexWeight(i)
		if (weight ~= 0) then
			Tab.Flex[i] = weight
			flexes = true
		end
	end
	if (flexes or Ent:GetFlexScale() ~= 1) then
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

	if(next(Tab.BodyG)==nil)then
		Tab.BodyG = nil
	end

	-- Bone Manipulator
	if (Ent:HasBoneManipulations()) then

		Tab.BoneManip = {}
		local t, s, a, p
		local c = gtSetupTable.COMPARE
		for i = 0, Ent:GetBoneCount() do
			t = {}
			s = Ent:GetManipulateBoneScale(i)
			a = Ent:GetManipulateBoneAngles(i)
			p = Ent:GetManipulateBonePosition(i)

			-- Avoid making a vector just to compare it
			if (s ~= c.V1) then t['s'] = s end
			if (a ~= c.A0) then t['a'] = a end
			if (p ~= c.V0) then t['p'] = p end

			if (t['s'] or t['a'] or t['p']) then
				Tab.BoneManip[i] = t
			end

		end

	end

	if Ent.GetNetworkVars then Tab.DT = Ent:GetNetworkVars() end

	-- Make this function on your SENT if you want to modify the
	-- returned table specifically for your entity.
	if Ent.OnEntityCopyTableFinish then
		local status, valid = pcall(Ent.OnEntityCopyTableFinish, Ent, Tab)
		if (not status) then
			print("AD2 OnEntityCopyTableFinish Error: " .. tostring(valid))
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
local function CopyConstraintTable(Const, Offset)
	if (Const == nil) then return nil, {} end

	-- Filter duplicator blocked constraints out.
	if Const.DoNotDuplicate then return nil, {} end

	local Type = duplicator.ConstraintType[Const.Type]
	if (not Type) then return nil, {} end
	local Constraint = {}
	local Entities = {}

	Const.Constraint = nil
	Const.OnDieFunctions = nil
	Constraint.Entity = {}
	for k, key in pairs(Type.Args) do
		if (key ~= "pl" and not string.find(key, "Ent") and not string.find(key, "Bone")) then
			Constraint[key] = Const[key]
		end
	end

	if ((Const["Ent"] and Const["Ent"]:IsWorld()) or IsValid(Const["Ent"])) then
		Constraint.Entity[1] = {}
		Constraint.Entity[1].Index = Const["Ent"]:EntIndex()
		if (not Const["Ent"]:IsWorld()) then table.insert(Entities, Const["Ent"]) end
		Constraint.Type = Const.Type
		if (Const.BuildDupeInfo) then Constraint.BuildDupeInfo = table.Copy(Const.BuildDupeInfo) end
	else
		for i = 1, 4 do
			local ent  = "Ent"  .. i
			local lpos = "LPos" .. i
			local wpos = "WPos" .. i

			if ((Const[ent] and Const[ent]:IsWorld()) or IsValid(Const[ent])) then
				Constraint.Entity[i] = {}
				Constraint.Entity[i].Index  = Const[ent]:EntIndex()
				Constraint.Entity[i].Bone   = Const["Bone"   .. i]
				Constraint.Entity[i].Length = Const["Length" .. i]
				Constraint.Entity[i].World  = Const["World"  .. i]

				if Const[ent]:IsWorld() then
					Constraint.Entity[i].World = true
					if (Const[lpos]) then
						if (i ~= 4 and i ~= 2) then
							if (Const["Ent2"]) then
								Constraint.Entity[i].LPos = Const[lpos] - Const["Ent2"]:GetPos()
								Constraint[lpos]   = Const[lpos] - Const["Ent2"]:GetPos()
							elseif (Const["Ent4"]) then
								Constraint.Entity[i].LPos = Const[lpos] - Const["Ent4"]:GetPos()
								Constraint[lpos]   = Const[lpos] - Const["Ent4"]:GetPos()
							end
						elseif (Const["Ent1"]) then
							Constraint.Entity[i].LPos = Const[lpos] - Const["Ent1"]:GetPos()
							Constraint[lpos]   = Const[lpos] - Const["Ent1"]:GetPos()
						end
					else
						Constraint.Entity[i].LPos = Offset
						Constraint[lpos]   = Offset
					end
				else
					Constraint.Entity[i].LPos = Const[lpos]
					Constraint.Entity[i].WPos = Const[wpos]
				end

				if (not Const[ent]:IsWorld()) then table.insert(Entities, Const[ent]) end
			end

			if (Const[wpos]) then
				if (not Const["Ent1"]:IsWorld()) then
					Constraint[wpos] = Const[wpos] - Const["Ent1"]:GetPos()
				else
					Constraint[wpos] = Const[wpos] - Const["Ent4"]:GetPos()
				end
			end
		end

		Constraint.Type = Const.Type
		if (Const.BuildDupeInfo) then
			Constraint.BuildDupeInfo = table.Copy(Const.BuildDupeInfo)
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
local function Copy(Ent, EntTable, ConstraintTable, Offset)

	local index = Ent:EntIndex()
	if EntTable[index] then return EntTable, ConstraintTable end

	local EntData = CopyEntTable(Ent, Offset)
	if EntData == nil then return EntTable, ConstraintTable end
	EntTable[index] = EntData

	if Ent.Constraints then
		for k, Constraint in pairs(Ent.Constraints) do
			if Constraint:IsValid() then
				index = Constraint:GetCreationID()
				if index and not ConstraintTable[index] then
					local ConstTable, EntTab = CopyConstraintTable(table.Copy(Constraint:GetTable()), Offset)
					ConstraintTable[index] = ConstTable
					for j, e in pairs(EntTab) do
						if e and (e:IsWorld() or e:IsValid()) then
							Copy(e, EntTable, ConstraintTable, Offset)
						end
					end
				end
			end
		end
	end

	do -- Wiremod Wire Connections
		if istable(Ent.Inputs) then
			for k, v in pairs(Ent.Inputs) do
				if isentity(v.Src) and v.Src:IsValid() then
					Copy(v.Src, EntTable, ConstraintTable, Offset)
				end
			end
		end

		if istable(Ent.Outputs) then
			for k, v in pairs(Ent.Outputs) do
				if istable(v.Connected) then
					for k, v in pairs(v.Connected) do
						if isentity(v.Entity) and v.Entity:IsValid() then
							Copy(v.Entity, EntTable, ConstraintTable, Offset)
						end
					end
				end
			end
		end
	end

	do -- Parented stuff
		local parent = Ent:GetParent()
		if IsValid(parent) then Copy(parent, EntTable, ConstraintTable, Offset) end
		for k, child in pairs(Ent:GetChildren()) do
			Copy(child, EntTable, ConstraintTable, Offset)
		end
	end

	for k, v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects) do
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
function AdvDupe2.duplicator.AreaCopy(Entities, Offset, CopyOutside)
	local Constraints, EntTable, ConstraintTable = {}, {}, {}
	local index, add, AddEnts, AddConstrs, ConstTable, EntTab

	for _, Ent in pairs(Entities) do
		index = Ent:EntIndex()
		EntTable[index] = CopyEntTable(Ent, Offset)
		if (EntTable[index] ~= nil) then

			if (not constraint.HasConstraints(Ent)) then
				for k, v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects) do
					Ent:GetPhysicsObjectNum(k):EnableMotion(v.Frozen)
				end
			else
				for k, v in pairs(Ent.Constraints) do
					-- Filter duplicator blocked constraints out.
					if not v.DoNotDuplicate then
						index = v:GetCreationID()
						if (index and not Constraints[index]) then
							Constraints[index] = v
						end
					end
				end

				for k, v in pairs(EntTable[Ent:EntIndex()].PhysicsObjects) do
					Ent:GetPhysicsObjectNum(k):EnableMotion(v.Frozen)
				end
			end
		end
	end

	for _, Constraint in pairs(Constraints) do
		ConstTable, EntTab = CopyConstraintTable(table.Copy(Constraint:GetTable()), Offset)
		-- If the entity is constrained to an entity outside of the area box, don't copy the constraint.
		if (not CopyOutside) then
			add = true
			for k, v in pairs(EntTab) do
				if (not Entities[v:EntIndex()]) then add = false end
			end
			if (add) then ConstraintTable[_] = ConstTable end
		else -- Copy entities and constraints outside of the box that are constrained to entities inside the box
			ConstraintTable[_] = ConstTable
			for k, v in pairs(EntTab) do
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
	local Factory = duplicator.ConstraintType[Constraint.Type]
	if not Factory then return end

	local first, firstindex -- Ent1 or Ent in the constraint's table
	local second, secondindex -- Any other Ent that is not Ent1 or Ent
	local Args = {} -- Build the argument list for the Constraint's spawn function
	for k, Key in ipairs(Factory.Args) do

		local Val = Constraint[Key]

		if gtSetupTable.PLAYER[Key] then Val = Player end

		for i = 1, 4 do
			if (Constraint.Entity and Constraint.Entity[i]) then
				if Key == "Ent" .. i or Key == "Ent" then
					if (Constraint.Entity[i].World) then
						Val = game.GetWorld()
					else
						Val = EntityList[Constraint.Entity[i].Index]

						if not IsValid(Val) then
							if (Player) then
								Player:ChatPrint("DUPLICATOR: ERROR, " .. Constraint.Type .. " Constraint could not find an entity!")
							else
								print("DUPLICATOR: ERROR, " .. Constraint.Type .. " Constraint could not find an entity!")
							end
							return
						else
							if (IsValid(Val:GetPhysicsObject())) then
								Val:GetPhysicsObject():EnableMotion(false)
							end
							-- Important for perfect duplication
							-- Get which entity is which so we can reposition them before constraining
							if (gtSetupTable.ENT1[Key]) then
								first = Val
								firstindex = Constraint.Entity[i].Index
							else
								second = Val
								secondindex = Constraint.Entity[i].Index
							end

						end
					end

				end

				if Key == "Bone" .. i or Key == "Bone" then
					Val = Constraint.Entity[i].Bone or 0
				end

				if Key == "LPos" .. i then
					if (Constraint.Entity[i].World and Constraint.Entity[i].LPos) then
						if (i == 2 or i == 4) then
							Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[1].Index]:GetPos()
						elseif (i == 1) then
							if (Constraint.Entity[2]) then
								Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[2].Index]:GetPos()
							else
								Val = Constraint.Entity[i].LPos + EntityList[Constraint.Entity[4].Index]:GetPos()
							end
						end
					elseif (Constraint.Entity[i].LPos) then
						Val = Constraint.Entity[i].LPos
					end
				end

				if Key == "Length" .. i then
					Val = Constraint.Entity[i].Length
				end
			end
			if Key == "WPos" .. i then
				if (not Constraint.Entity[1].World) then
					Val = Constraint[Key] + EntityList[Constraint.Entity[1].Index]:GetPos()
				else
					Val = Constraint[Key] + EntityList[Constraint.Entity[4].Index]:GetPos()
				end
			end

		end

		Args[k] = Val
	end

	local Bone1, Bone1Index, ReEnableFirst
	local Bone2, Bone2Index, ReEnableSecond
	local buildInfo = Constraint.BuildDupeInfo
	if (buildInfo) then

		if first ~= nil and second ~= nil and not second:IsWorld() and buildInfo.EntityPos ~= nil then
			local SecondPhys = second:GetPhysicsObject()
			if IsValid(SecondPhys) then
				if not DontEnable then ReEnableSecond = SecondPhys:IsMoveable() end
				SecondPhys:EnableMotion(false)
				second:SetPos(first:GetPos() - buildInfo.EntityPos)
				if (buildInfo.Bone2) then
					Bone2Index = buildInfo.Bone2
					Bone2 = second:GetPhysicsObjectNum(Bone2Index)
					if IsValid(Bone2) then
						Bone2:EnableMotion(false)
						Bone2:SetPos(second:GetPos() + buildInfo.Bone2Pos)
						Bone2:SetAngles(buildInfo.Bone2Angle)
					end
				end
			end
		end

		if first ~= nil and not first:IsWorld() and buildInfo.Ent1Ang ~= nil then
			local FirstPhys = first:GetPhysicsObject()
			if IsValid(FirstPhys) then
				if not DontEnable then ReEnableFirst = FirstPhys:IsMoveable() end
				FirstPhys:EnableMotion(false)
				first:SetAngles(buildInfo.Ent1Ang)
				if (buildInfo.Bone1) then
					Bone1Index = buildInfo.Bone1
					Bone1 = first:GetPhysicsObjectNum(Bone1Index)
					if IsValid(Bone1) then
						Bone1:EnableMotion(false)
						Bone1:SetPos(first:GetPos() + buildInfo.Bone1Pos)
						Bone1:SetAngles(buildInfo.Bone1Angle)
					end
				end
			end
		end

		if second ~= nil and not second:IsWorld() then
			if buildInfo.Ent2Ang ~= nil then
				second:SetAngles(buildInfo.Ent2Ang)
			elseif buildInfo.Ent4Ang ~= nil then
				second:SetAngles(buildInfo.Ent4Ang)
			end
		end
	end

	local ok, Ent = pcall(Factory.Func, unpack(Args, 1, #Factory.Args))

	if not ok or not Ent then
		if (Player) then
			AdvDupe2.Notify(Player, "ERROR, Failed to create " .. Constraint.Type .. " Constraint!", NOTIFY_ERROR)
		else
			print("DUPLICATOR: ERROR, Failed to create " .. Constraint.Type .. " Constraint!")
		end
		return
	end

	Ent.BuildDupeInfo = table.Copy(buildInfo)

	-- Move the entities back after constraining them. No point in moving the world though.
	if (EntityTable) then
		local fEnt = EntityTable[firstindex]
		local sEnt = EntityTable[secondindex]

		if (first ~= nil and not first:IsWorld()) then
			first:SetPos(fEnt.BuildDupeInfo.PosReset)
			first:SetAngles(fEnt.BuildDupeInfo.AngleReset)
			if (IsValid(Bone1) and Bone1Index ~= 0) then
				Bone1:SetPos(fEnt.BuildDupeInfo.PosReset +
										 fEnt.BuildDupeInfo.PhysicsObjects[Bone1Index].Pos)
				Bone1:SetAngles(fEnt.PhysicsObjects[Bone1Index].Angle)
			end

			local FirstPhys = first:GetPhysicsObject()
			if IsValid(FirstPhys) then
				if ReEnableFirst then
					FirstPhys:EnableMotion(true)
				end
			end
		end

		if (second ~= nil and not second:IsWorld()) then
			second:SetPos(sEnt.BuildDupeInfo.PosReset)
			second:SetAngles(sEnt.BuildDupeInfo.AngleReset)
			if (IsValid(Bone2) and Bone2Index ~= 0) then
				Bone2:SetPos(sEnt.BuildDupeInfo.PosReset +
										 sEnt.BuildDupeInfo.PhysicsObjects[Bone2Index].Pos)
				Bone2:SetAngles(sEnt.PhysicsObjects[Bone2Index].Angle)
			end

			local SecondPhys = second:GetPhysicsObject()
			if IsValid(SecondPhys) then
				if ReEnableSecond then
					SecondPhys:EnableMotion(true)
				end
			end
		end
	end

	if (Ent and Ent.length) then
		Ent.length = Constraint["length"]
	end -- Fix for weird bug with ropes

	return Ent
end

local function ApplyEntityModifiers(Player, Ent)
	if not Ent.EntityMods then return end
	if Ent.EntityMods.trail then
		Ent.EntityMods.trail.EndSize = math.Clamp(tonumber(Ent.EntityMods.trail.EndSize) or 0, 0, 1024)
		Ent.EntityMods.trail.StartSize = math.Clamp(tonumber(Ent.EntityMods.trail.StartSize) or 0, 0, 1024)
	end

	for Type, Data in SortedPairs(Ent.EntityMods) do
		local ModFunction = duplicator.EntityModifiers[Type]
		if (ModFunction) then
			local ok, err = pcall(ModFunction, Player, Ent, Data)
			if (not ok) then
				if (Player) then
					Player:ChatPrint('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
				else
					print('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
				end
			end
		end
	end
	if (Ent.EntityMods["mass"] and duplicator.EntityModifiers["mass"]) then
		local ok, err = pcall(duplicator.EntityModifiers["mass"], Player, Ent, Ent.EntityMods["mass"])
		if (not ok) then
			if (Player) then
				Player:ChatPrint('Error applying entity modifer, "mass". ERROR: ' .. err)
			else
				print('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
			end
		end
	end
	if(Ent.EntityMods["buoyancy"] and duplicator.EntityModifiers["buoyancy"]) then
		local ok, err = pcall(duplicator.EntityModifiers["buoyancy"], Player, Ent, Ent.EntityMods["buoyancy"])
		if (not ok) then
			if (Player) then
				Player:ChatPrint('Error applying entity modifer, "buoyancy". ERROR: ' .. err)
			else
				print('Error applying entity modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
			end
		end
	end
end

local function ApplyBoneModifiers(Player, Ent)
	if (not Ent.BoneMods or not Ent.PhysicsObjects) then return end

	for Type, ModFunction in pairs(duplicator.BoneModifiers) do
		for Bone, Args in pairs(Ent.PhysicsObjects) do
			if (Ent.BoneMods[Bone] and Ent.BoneMods[Bone][Type]) then
				local PhysObj = Ent:GetPhysicsObjectNum(Bone)
				if (Ent.PhysicsObjects[Bone]) then
					local ok, err = pcall(ModFunction, Player, Ent, Bone, PhysObj, Ent.BoneMods[Bone][Type])
					if (not ok) then
						Player:ChatPrint('Error applying bone modifer, "' .. tostring(Type) .. '". ERROR: ' .. err)
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
local function DoGenericPhysics(Entity, data, Player)

	if (not data) then return end
	if (not data.PhysicsObjects) then return end
	local Phys
	if (Player) then
		for Bone, Args in pairs(data.PhysicsObjects) do
			Phys = Entity:GetPhysicsObjectNum(Bone)
			if (IsValid(Phys)) then
				Phys:SetPos(Args.Pos)
				Phys:SetAngles(Args.Angle)
				Phys:EnableMotion(false)
				Player:AddFrozenPhysicsObject(Entity, Phys)
			end
		end
	else
		for Bone, Args in pairs(data.PhysicsObjects) do
			Phys = Entity:GetPhysicsObjectNum(Bone)
			if (IsValid(Phys)) then
				Phys:SetPos(Args.Pos)
				Phys:SetAngles(Args.Angle)
				Phys:EnableMotion(false)
			end
		end
	end
end

local function reportclass(ply, class)
	net.Start("AdvDupe2_ReportClass")
	net.WriteString(class)
	net.Send(ply)
end

local function reportmodel(ply, model)
	net.Start("AdvDupe2_ReportClass")
	net.WriteString(model)
	net.Send(ply)
end

--[[
	Name: GenericDuplicatorFunction
	Desc: Override the default duplicator's GenericDuplicatorFunction function
	Params: <player> Player, <table> data
	Returns: <entity> Entity
]]
local function GenericDuplicatorFunction(data, Player)

	local Entity = ents.Create(data.Class)
	if (not IsValid(Entity)) then
		if (Player) then
			reportclass(Player, data.Class)
		else
			print("Advanced Duplicator 2 Invalid Class: " .. data.Class)
		end
		return nil
	end

	if (not util.IsValidModel(data.Model) and not file.Exists(data.Model, "GAME")) then
		if (Player) then
			reportmodel(Player, data.Model)
		else
			print("Advanced Duplicator 2 Invalid Model: " .. data.Model)
		end
		return nil
	end

	duplicator.DoGeneric(Entity, data)
	Entity:Spawn()
	Entity:Activate()
	DoGenericPhysics(Entity, data, Player)

	table.Add(Entity:GetTable(), data)
	return Entity
end

--[[
	Name: MakeProp
	Desc: Make prop without spawn effects
	Params: <player> Player, <vector> Pos, <angle> Ang, <string> Model, <table> PhysicsObject, <table> Data
	Returns: <entity> Prop
]]
local function MakeProp(Player, Pos, Ang, Model, PhysicsObject, Data)

	if (not util.IsValidModel(Model) and not file.Exists(Data.Model, "GAME")) then
		if (Player) then
			reportmodel(Player, Data.Model)
		else
			print("Advanced Duplicator 2 Invalid Model: " .. Model)
		end
		return nil
	end

	Data.Pos = Pos
	Data.Angle = Ang
	Data.Model = Model
	Data.Frozen = true
	-- Make sure this is allowed
	if (Player) then
		if (not gamemode.Call("PlayerSpawnProp", Player, Model)) then
			return false
		end
	end

	local Prop = ents.Create("prop_physics")
	if not IsValid(Prop) then return false end

	duplicator.DoGeneric(Prop, Data)
	Prop:Spawn()
	Prop:Activate()
	DoGenericPhysics(Prop, Data, Player)
	if (Data.Flex) then
		duplicator.DoFlex(Prop, Data.Flex, Data.FlexScale)
	end

	return Prop
end

local function RestoreBodyGroups(ent, BodyG)
	for k, v in pairs(BodyG) do
		ent:SetBodygroup(k, v)
	end
end

--[[
	Name: CreateEntityFromTable
	Desc: Creates an entity from a given table
	Params: <table> EntTable, <player> Player
	Returns: nil
]]
local function IsAllowed(Player, Class, EntityClass)
	if (scripted_ents.GetMember(Class, "DoNotDuplicate")) then return false end

	if (IsValid(Player) and not Player:IsAdmin()) then
		if not duplicator.IsAllowed(Class) then return false end
		if (not scripted_ents.GetMember(Class, "Spawnable") and not EntityClass) then return false end
		if (scripted_ents.GetMember(Class, "AdminOnly")) then return false end
	end
	return true
end

local function CreateEntityFromTable(EntTable, Player)

	local EntityClass = duplicator.FindEntityClass(EntTable.Class)
	if not IsAllowed(Player, EntTable.Class, EntityClass) then
		Player:ChatPrint([[Entity Class Black listed, "]] .. EntTable.Class .. [["]])
		return nil
	end

	local sent = false
	local status, valid
	local GENERIC = false

	-- This class is unregistered. Instead of failing try using a generic
	-- Duplication function to make a new copy.
	if (not EntityClass) then
		GENERIC = true
		sent = true

		if Player then
			if(EntTable.Class=="prop_effect")then
				sent = gamemode.Call( "PlayerSpawnEffect", Player, EntTable.Model)
			else
				sent = gamemode.Call( "PlayerSpawnSENT", Player, EntTable.Class)
			end
		else
			sent = true
		end

		if (sent == false) then
			print("Advanced Duplicator 2: Creation rejected for class, : " .. EntTable.Class)
			return nil
		else
			sent = true
		end

		if IsAllowed(Player, EntTable.Class, EntityClass) then
			status, valid = pcall(GenericDuplicatorFunction, EntTable, Player)
		else
			print("Advanced Duplicator 2: ENTITY CLASS IS BLACKLISTED, CLASS NAME: " .. EntTable.Class)
			return nil
		end
	end

	if (not GENERIC) then

		-- Build the argument list for the Entitie's spawn function
		local ArgList, Arg = {}

		for iNumber, Key in pairs(EntityClass.Args) do

			Arg = nil
			-- Translate keys from old system
			if (gtSetupTable.POS[Key]) then Key = "Pos" end
			if (gtSetupTable.ANG[Key]) then Key = "Angle" end
			if (gtSetupTable.MODEL[Key]) then Key = "Model" end
			if (gtSetupTable.TVEHICLE[Key] and EntTable[Key] and EntTable[Key].KeyValues) then
				EntTable[Key].KeyValues = {
					limitview     = EntTable[Key].KeyValues.limitview,
					vehiclescript = EntTable[Key].KeyValues.vehiclescript
				}
			end

			Arg = EntTable[Key]

			-- Special keys
			if (gtSetupTable.SPECIAL[Key]) then
				Arg = EntTable
			end

			ArgList[iNumber] = Arg

		end

		-- Create and return the entity
		if (EntTable.Class == "prop_physics") then
			valid = MakeProp(Player, unpack(ArgList, 1, #EntityClass.Args)) -- Create prop_physics like this because if the model doesn't exist it will cause
		elseif IsAllowed(Player, EntTable.Class, EntityClass) then
			-- Create sents using their spawn function with the arguments we stored earlier
			sent = true

			if Player then
				if (not EntTable.BuildDupeInfo.IsVehicle and not EntTable.BuildDupeInfo.IsNPC and EntTable.Class ~= "prop_ragdoll" and EntTable.Class ~= "prop_effect") then
					sent = hook.Call("PlayerSpawnSENT", nil, Player, EntTable.Class)
				end
			else
				sent = true
			end

			if (sent == false) then
				print("Advanced Duplicator 2: Creation rejected for class, : " .. EntTable.Class)
				return nil
			else
				sent = true
			end

			status, valid = pcall(EntityClass.Func, Player, unpack(ArgList, 1, #EntityClass.Args))
			if not status then ErrorNoHalt(valid) end
		else
			print("Advanced Duplicator 2: ENTITY CLASS IS BLACKLISTED, CLASS NAME: " .. EntTable.Class)
			return nil
		end
	end

	-- If its a valid entity send it back to the entities list so we can constrain it
	if (status ~= false and IsValid(valid)) then
		if (sent) then
			local iNumPhysObjects = valid:GetPhysicsObjectCount()
			local PhysObj
			if (Player) then
				for Bone = 0, iNumPhysObjects - 1 do
					PhysObj = valid:GetPhysicsObjectNum(Bone)
					if IsValid(PhysObj) then
						PhysObj:EnableMotion(false)
						Player:AddFrozenPhysicsObject(valid, PhysObj)
					end
				end
			else
				for Bone = 0, iNumPhysObjects - 1 do
					PhysObj = valid:GetPhysicsObjectNum(Bone)
					if IsValid(PhysObj) then
						PhysObj:EnableMotion(false)
					end
				end
			end
			if (EntTable.Skin) then valid:SetSkin(EntTable.Skin) end
			if (EntTable.BodyG) then RestoreBodyGroups(valid, EntTable.BodyG) end

			if valid.RestoreNetworkVars then
				valid:RestoreNetworkVars(EntTable.DT)
			end

			if GENERIC and Player then
				if(EntTable.Class=="prop_effect")then
					gamemode.Call("PlayerSpawnedEffect", Player, valid:GetModel(), valid)
				else
					gamemode.Call("PlayerSpawnedSENT", Player, valid)
				end
			end

		elseif (Player) then
			gamemode.Call("PlayerSpawnedProp", Player, valid:GetModel(), valid)
		end

		return valid
	else
		if (valid == false) then
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
function AdvDupe2.duplicator.Paste(Player, EntityList, ConstraintList, Position, AngleOffset, OrigPos, Parenting)

	local CreatedEntities = {}
	--
	-- Create entities
	--
	local proppos
	DisablePropCreateEffect = true
	for k, v in pairs(EntityList) do
		if (not v.BuildDupeInfo) then v.BuildDupeInfo = {} end
		v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
		proppos = v.PhysicsObjects[0].Pos
		v.BuildDupeInfo.PhysicsObjects[0].Pos = Vector(0, 0, 0)
		if (OrigPos) then
			for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
				v.PhysicsObjects[i].Pos = p.Pos + proppos + OrigPos
				v.PhysicsObjects[i].Frozen = true
			end
			v.Pos = v.PhysicsObjects[0].Pos
			v.Angle = v.PhysicsObjects[0].Angle
			v.BuildDupeInfo.PosReset = v.Pos
			v.BuildDupeInfo.AngleReset = v.Angle
		else
			for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
				v.PhysicsObjects[i].Pos, v.PhysicsObjects[i].Angle =
					LocalToWorld(p.Pos + proppos, p.Angle, Position, AngleOffset)
				v.PhysicsObjects[i].Frozen = true
			end
			v.Pos = v.PhysicsObjects[0].Pos
			v.BuildDupeInfo.PosReset = v.Pos
			v.Angle = v.PhysicsObjects[0].Angle
			v.BuildDupeInfo.AngleReset = v.Angle
		end

		AdvDupe2.SpawningEntity = true
		local Ent = CreateEntityFromTable(v, Player)
		AdvDupe2.SpawningEntity = false

		if Ent then
			if (Player) then Player:AddCleanup("AdvDupe2", Ent) end
			Ent.BoneMods = table.Copy(v.BoneMods)
			Ent.EntityMods = table.Copy(v.EntityMods)
			Ent.PhysicsObjects = table.Copy(v.PhysicsObjects)
			if (v.CollisionGroup) then Ent:SetCollisionGroup(v.CollisionGroup) end
			if (Ent.OnDuplicated) then Ent:OnDuplicated(v) end
			ApplyEntityModifiers(Player, Ent)
			ApplyBoneModifiers(Player, Ent)
			Ent.SolidMod = not Ent:IsSolid()
			Ent:SetNotSolid(true)
		elseif (Ent == false) then
			Ent = nil
			-- ConstraintList = {}
			-- break
		else
			Ent = nil
		end
		CreatedEntities[k] = Ent
	end

	local CreatedConstraints, Entity = {}
	--
	-- Create constraints
	--
	for k, Constraint in pairs(ConstraintList) do
		Entity = CreateConstraintFromTable(Constraint, CreatedEntities, EntityList, Player)
		if (IsValid(Entity)) then
			table.insert(CreatedConstraints, Entity)
		end
	end

	if (Player) then

		undo.Create("AdvDupe2")
		for _, v in pairs(CreatedEntities) do
			-- If the entity has a PostEntityPaste function tell it to use it now
			if v.PostEntityPaste then
				local status, valid = pcall(v.PostEntityPaste, v, Player, v, CreatedEntities)
				if (not status) then
					print("AD2 PostEntityPaste Error: " .. tostring(valid))
				end
			end
			v:GetPhysicsObject():EnableMotion(false)

			if (EntityList[_].BuildDupeInfo.DupeParentID and Parenting) then
				v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
			end
			v:SetNotSolid(v.SolidMod)
			undo.AddEntity(v)
		end
		undo.SetPlayer(Player)
		undo.Finish()

		-- if(Tool)then AdvDupe2.FinishPasting(Player, true) end
	else

		for _, v in pairs(CreatedEntities) do
			-- If the entity has a PostEntityPaste function tell it to use it now
			if v.PostEntityPaste then
				local status, valid = pcall(v.PostEntityPaste, v, Player, v, CreatedEntities)
				if (not status) then
					print("AD2 PostEntityPaste Error: " .. tostring(valid))
				end
			end
			v:GetPhysicsObject():EnableMotion(false)

			if (EntityList[_].BuildDupeInfo.DupeParentID and Parenting) then
				v:SetParent(CreatedEntities[EntityList[_].BuildDupeInfo.DupeParentID])
			end

			v:SetNotSolid(v.SolidMod)
		end
	end
	DisablePropCreateEffect = nil
	hook.Call("AdvDupe_FinishPasting", nil, {
		{
			EntityList = EntityList,
			CreatedEntities = CreatedEntities,
			ConstraintList = ConstraintList,
			CreatedConstraints = CreatedConstraints,
			HitPos = OrigPos or Position,
			Player = Player
		}
	}, 1)

	return CreatedEntities, CreatedConstraints
end

local function AdvDupe2_Spawn()

	local Queue = AdvDupe2.JobManager.Queue[AdvDupe2.JobManager.CurrentPlayer]

	if (not Queue or not IsValid(Queue.Player)) then
		if Queue then
			table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
		end

		if (#AdvDupe2.JobManager.Queue == 0) then
			hook.Remove("Tick", "AdvDupe2_Spawning")
			DisablePropCreateEffect = nil
			AdvDupe2.JobManager.PastingHook = false
		end
		return
	end

	if (Queue.Entity) then
		if (Queue.Current == 1) then
			AdvDupe2.InitProgressBar(Queue.Player, "Pasting:")
			Queue.Player.AdvDupe2.Queued = false
		end
		local newpos
		if (Queue.Current > #Queue.SortedEntities) then
			Queue.Entity = false
			Queue.Constraint = true
			Queue.Current = 1
			return
		end
		if (not Queue.SortedEntities[Queue.Current]) then
			Queue.Current = Queue.Current + 1
			return
		end

		local k = Queue.SortedEntities[Queue.Current]
		local v = Queue.EntityList[k]

		if (not v.BuildDupeInfo) then v.BuildDupeInfo = {} end
		if (v.LocalPos) then
			for i, p in pairs(v.PhysicsObjects) do
				v.PhysicsObjects[i] = {Pos = v.LocalPos, Angle = v.LocalAngle}
			end
		end

		v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
		proppos = v.PhysicsObjects[0].Pos
		v.BuildDupeInfo.PhysicsObjects[0].Pos = Vector(0, 0, 0)
		if (Queue.OrigPos) then
			for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
				v.PhysicsObjects[i].Pos = p.Pos + proppos + Queue.OrigPos
				v.PhysicsObjects[i].Frozen = true
			end
			v.Pos = v.PhysicsObjects[0].Pos
			v.Angle = v.PhysicsObjects[0].Angle
			v.BuildDupeInfo.PosReset = v.Pos
			v.BuildDupeInfo.AngleReset = v.Angle
		else
			for i, p in pairs(v.BuildDupeInfo.PhysicsObjects) do
				v.PhysicsObjects[i].Pos, v.PhysicsObjects[i].Angle =
					LocalToWorld(p.Pos + proppos, p.Angle, Queue.PositionOffset, Queue.AngleOffset)
				v.PhysicsObjects[i].Frozen = true
			end
			v.Pos = v.PhysicsObjects[0].Pos
			v.BuildDupeInfo.PosReset = v.Pos
			v.Angle = v.PhysicsObjects[0].Angle
			v.BuildDupeInfo.AngleReset = v.Angle
		end

		AdvDupe2.SpawningEntity = true
		local Ent = CreateEntityFromTable(v, Queue.Player)
		AdvDupe2.SpawningEntity = false

		if Ent then
			Queue.Player:AddCleanup("AdvDupe2", Ent)
			Ent.BoneMods = table.Copy(v.BoneMods)
			Ent.EntityMods = table.Copy(v.EntityMods)
			Ent.PhysicsObjects = table.Copy(v.PhysicsObjects)
			Ent.SolidMod = not Ent:IsSolid()

			local Phys = Ent:GetPhysicsObject()
			if (IsValid(Phys)) then Phys:EnableMotion(false) end
			if (not Queue.DisableProtection) then Ent:SetNotSolid(true) end
			if (v.CollisionGroup) then Ent:SetCollisionGroup(v.CollisionGroup) end
			if (Ent.OnDuplicated) then Ent:OnDuplicated(v) end
		elseif (Ent == false) then
			Ent = nil
		else
			Ent = nil
		end
		Queue.CreatedEntities[k] = Ent

		AdvDupe2.UpdateProgressBar(Queue.Player, math.floor((Queue.Percent * Queue.Current) * 100))
		Queue.Current = Queue.Current + 1
		if (Queue.Current > #Queue.SortedEntities) then

			for _, Ent in pairs(Queue.CreatedEntities) do
				ApplyEntityModifiers(Queue.Player, Ent)
				ApplyBoneModifiers(Queue.Player, Ent)

				-- If the entity has a PostEntityPaste function tell it to use it now
				if Ent.PostEntityPaste then
					local status, valid = pcall(Ent.PostEntityPaste, Ent, Queue.Player, Ent, Queue.CreatedEntities)
					if (not status) then
						print("AD2 PostEntityPaste Error: " .. tostring(valid))
					end
				end
			end

			Queue.Entity = false
			Queue.Constraint = true
			Queue.Current = 1
		end

		if (#AdvDupe2.JobManager.Queue >= AdvDupe2.JobManager.CurrentPlayer + 1) then
			AdvDupe2.JobManager.CurrentPlayer = AdvDupe2.JobManager.CurrentPlayer + 1
		else
			AdvDupe2.JobManager.CurrentPlayer = 1
		end
	else
		if (#Queue.ConstraintList > 0) then

			if (#AdvDupe2.JobManager.Queue == 0) then
				hook.Remove("Tick", "AdvDupe2_Spawning")
				DisablePropCreateEffect = nil
				AdvDupe2.JobManager.PastingHook = false
			end
			if (not Queue.ConstraintList[Queue.Current]) then
				Queue.Current = Queue.Current + 1
				return
			end

			local Entity = CreateConstraintFromTable(Queue.ConstraintList[Queue.Current], Queue.CreatedEntities,
																							 Queue.EntityList, Queue.Player, true)
			if IsValid(Entity) then
				table.insert(Queue.CreatedConstraints, Entity)
			end
		elseif (next(Queue.ConstraintList) ~= nil) then
			local tbl = {}
			for k, v in pairs(Queue.ConstraintList) do
				table.insert(tbl, v)
			end
			Queue.ConstraintList = tbl
			Queue.Current = 0
		end

		AdvDupe2.UpdateProgressBar(Queue.Player, math.floor((Queue.Percent * (Queue.Current + Queue.Plus)) * 100))
		Queue.Current = Queue.Current + 1

		if (Queue.Current > #Queue.ConstraintList) then

			local unfreeze = tobool(Queue.Player:GetInfo("advdupe2_paste_unfreeze")) or false
			local preservefrozenstate = tobool(Queue.Player:GetInfo("advdupe2_preserve_freeze")) or false

			-- Remove the undo for stopping pasting
			local undotxt = Queue.Name and ("AdvDupe2 ("..Queue.Name..")") or "AdvDupe2"
			local undos = undo.GetTable()[Queue.Player:UniqueID()]
			for i = #undos, 1, -1 do
				if (undos[i] and undos[i].Name == undotxt) then
					undos[i] = nil
					-- Undo module netmessage
					net.Start("Undo_Undone")
					net.WriteInt(i, 16)
					net.Send(Queue.Player)
					break
				end
			end

			undo.Create(undotxt)
			local phys, edit, mass
			for k, v in pairs(Queue.CreatedEntities) do
				if (not IsValid(v)) then
					v = nil
				else
					edit = true
					if (Queue.EntityList[k].BuildDupeInfo.DupeParentID ~= nil and Queue.Parenting) then
						v:SetParent(Queue.CreatedEntities[Queue.EntityList[k].BuildDupeInfo.DupeParentID])
						if (v.Constraints ~= nil) then
							for i, c in pairs(v.Constraints) do
								if (c and constraints[c.Type]) then
									edit = false
									break
								end
							end
						end
						if (edit and IsValid(v:GetPhysicsObject())) then
							mass = v:GetPhysicsObject():GetMass()
							v:PhysicsInitShadow(false, false)
							v:SetCollisionGroup(COLLISION_GROUP_WORLD)
							v:GetPhysicsObject():EnableMotion(false)
							v:GetPhysicsObject():Sleep()
							v:GetPhysicsObject():SetMass(mass)
						end
					else
						edit = false
					end

					if (unfreeze) then
						for i = 0, v:GetPhysicsObjectCount() do
							phys = v:GetPhysicsObjectNum(i)
							if (IsValid(phys)) then
								phys:EnableMotion(true) -- Unfreeze the entitiy and all of its objects
								phys:Wake()
							end
						end
					elseif (preservefrozenstate) then
						for i = 0, v:GetPhysicsObjectCount() do
							phys = v:GetPhysicsObjectNum(i)
							if (IsValid(phys)) then
								if (Queue.EntityList[k].BuildDupeInfo.PhysicsObjects[i].Frozen) then
									phys:EnableMotion(true) -- Restore the entity and all of its objects to their original frozen state
									phys:Wake()
								else
									Queue.Player:AddFrozenPhysicsObject(v, phys)
								end
							end
						end
					else
						for i = 0, v:GetPhysicsObjectCount() do
							phys = v:GetPhysicsObjectNum(i)
							if (IsValid(phys)) then
								if (phys:IsMoveable()) then
									phys:EnableMotion(false) -- Freeze the entitiy and all of its objects
									Queue.Player:AddFrozenPhysicsObject(v, phys)
								end
							end
						end
					end

					if (not edit or not Queue.DisableParents) then
						v:SetNotSolid(v.SolidMod)
					end

					undo.AddEntity(v)
				end
			end
			undo.SetPlayer(Queue.Player)
			undo.Finish(undotxt)

			hook.Call("AdvDupe_FinishPasting", nil, {
				{
					EntityList = Queue.EntityList,
					CreatedEntities = Queue.CreatedEntities,
					ConstraintList = Queue.ConstraintList,
					CreatedConstraints = Queue.CreatedConstraints,
					HitPos = Queue.PositionOffset,
					Player = Queue.Player
				}
			}, 1)
			AdvDupe2.FinishPasting(Queue.Player, true)

			table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)
			if (#AdvDupe2.JobManager.Queue == 0) then
				hook.Remove("Tick", "AdvDupe2_Spawning")
				DisablePropCreateEffect = nil
				AdvDupe2.JobManager.PastingHook = false
			end
		end
		if (#AdvDupe2.JobManager.Queue >= AdvDupe2.JobManager.CurrentPlayer + 1) then
			AdvDupe2.JobManager.CurrentPlayer = AdvDupe2.JobManager.CurrentPlayer + 1
		else
			AdvDupe2.JobManager.CurrentPlayer = 1
		end
	end
end

local ticktotal = 0
local function ErrorCatchSpawning()

	ticktotal = ticktotal + AdvDupe2.SpawnRate
	while ticktotal >= 1 do
		ticktotal = ticktotal - 1
		local status, err = pcall(AdvDupe2_Spawn)

		if (not status) then
			-- PUT ERROR LOGGING HERE

			if (not AdvDupe2.JobManager.Queue) then
				print("[AdvDupe2Notify]\t" .. err)
				AdvDupe2.JobManager.Queue = {}
				return
			end

			local Queue = AdvDupe2.JobManager.Queue[AdvDupe2.JobManager.CurrentPlayer]
			if (not Queue) then
				print("[AdvDupe2Notify]\t" .. err)
				return
			end

			if (IsValid(Queue.Player)) then
				AdvDupe2.Notify(Queue.Player, err)

				local undos = undo.GetTable()[Queue.Player:UniqueID()]
				local undotxt = Queue.Name and ("AdvDupe2 ("..Queue.Name..")") or "AdvDupe2"
				for i = #undos, 1, -1 do
					if (undos[i] and undos[i].Name == undotxt) then
						undos[i] = nil
						-- Undo module netmessage
						net.Start("Undo_Undone")
						net.WriteInt(i, 16)
						net.Send(Queue.Player)
						break
					end
				end
			else
				print("[AdvDupe2Notify]\t" .. err)
			end

			for k, v in pairs(Queue.CreatedEntities) do
				if (IsValid(v)) then v:Remove() end
			end

			if (IsValid(Queue.Player)) then
				AdvDupe2.FinishPasting(Queue.Player, true)
			end

			table.remove(AdvDupe2.JobManager.Queue, AdvDupe2.JobManager.CurrentPlayer)

			if (#AdvDupe2.JobManager.Queue == 0) then
				hook.Remove("Tick", "AdvDupe2_Spawning")
				DisablePropCreateEffect = nil
				AdvDupe2.JobManager.PastingHook = false
			else
				if (#Queue < AdvDupe2.JobManager.CurrentPlayer) then
					AdvDupe2.JobManager.CurrentPlayer = 1
				end
			end

		end
	end
end

local function RemoveSpawnedEntities(tbl, i)
	if (not AdvDupe2.JobManager.Queue[i]) then return end -- Without this some errors come up, double check the errors without this line

	for k, v in pairs(AdvDupe2.JobManager.Queue[i].CreatedEntities) do
		if (IsValid(v)) then v:Remove() end
	end

	AdvDupe2.FinishPasting(AdvDupe2.JobManager.Queue[i].Player, false)
	table.remove(AdvDupe2.JobManager.Queue, i)
	if (#AdvDupe2.JobManager.Queue == 0) then
		hook.Remove("Tick", "AdvDupe2_Spawning")
		DisablePropCreateEffect = nil
		AdvDupe2.JobManager.PastingHook = false
	end
end

function AdvDupe2.InitPastingQueue(Player, PositionOffset, AngleOffset, OrigPos, Constrs, Parenting, DisableParents, DisableProtection)
	local i = #AdvDupe2.JobManager.Queue + 1
	AdvDupe2.JobManager.Queue[i] = {}
	local Queue = AdvDupe2.JobManager.Queue[i]
	Queue.Player = Player
	Queue.SortedEntities = {}
	Queue.EntityList = table.Copy(Player.AdvDupe2.Entities)
	if (Constrs) then
		Queue.ConstraintList = table.Copy(Player.AdvDupe2.Constraints)
	else
		Queue.ConstraintList = {}
	end
	Queue.OrigPos = OrigPos
	for k, v in pairs(Player.AdvDupe2.Entities) do
		table.insert(Queue.SortedEntities, k)
	end

	if (Player.AdvDupe2.Name) then
		print(
			"[AdvDupe2NotifyPaste]\t Player: " .. Player:Nick() .. " Pasted File, " .. Player.AdvDupe2.Name .. " with, " ..
				#Queue.SortedEntities .. " Entities and " .. #Player.AdvDupe2.Constraints .. " Constraints.")
	else
		print("[AdvDupe2NotifyPaste]\t Player: " .. Player:Nick() .. " Pasted, " .. #Queue.SortedEntities ..
						" Entities and " .. #Player.AdvDupe2.Constraints .. " Constraints.")
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
	Queue.PositionOffset = PositionOffset or Vector(0, 0, 0)
	Queue.AngleOffset = AngleOffset or Angle(0, 0, 0)
	Queue.Plus = #Queue.SortedEntities
	Queue.Percent = 1 / (#Queue.SortedEntities + #Queue.ConstraintList)
	AdvDupe2.InitProgressBar(Player, "Queued:")
	Player.AdvDupe2.Queued = true
	if (not AdvDupe2.JobManager.PastingHook) then
		DisablePropCreateEffect = true
		hook.Add("Tick", "AdvDupe2_Spawning", ErrorCatchSpawning)
		AdvDupe2.JobManager.PastingHook = true
		AdvDupe2.JobManager.CurrentPlayer = 1
	end

	local undotxt = Player.AdvDupe2.Name and ("AdvDupe2 ("..Player.AdvDupe2.Name..")") or "AdvDupe2"
	undo.Create(undotxt)
	undo.SetPlayer(Player)
	undo.AddFunction(RemoveSpawnedEntities, i)
	undo.Finish(undotxt)
end
