--[[
	Title: Miscellaneous
	
	Desc: Contains miscellaneous (serverside) things AD2 needs to function that don't fit anywhere else.
	
	Author: TB
	
	Version: 1.0
]]

--[[
	Name: SavePositions
	Desc: Save the position of the entities to prevent sagging on dupe.
	Params: <entity> Constraint
	Returns: nil
]]

local function SavePositions( Constraint )

	if IsValid(Constraint) then

		Constraint.Identity = Constraint:GetCreationID()

		if Constraint.BuildDupeInfo then return end
		
		if not Constraint.BuildDupeInfo then Constraint.BuildDupeInfo = {} end
			
		local Ent1
		local Ent2
		if IsValid(Constraint.Ent) then
			Constraint.BuildDupeInfo.Ent1Ang = Constraint.Ent:GetAngles()
		end

		if IsValid(Constraint.Ent1) then
			Constraint.BuildDupeInfo.Ent1Ang = Constraint.Ent1:GetAngles()
			if(Constraint.Ent1:GetPhysicsObjectCount()>1)then
				Constraint.BuildDupeInfo.Bone1 = Constraint["Bone1"]
				Constraint.BuildDupeInfo.Bone1Pos = Constraint.Ent1:GetPhysicsObjectNum(Constraint["Bone1"]):GetPos() - Constraint.Ent1:GetPos()
				Constraint.BuildDupeInfo.Bone1Angle = Constraint.Ent1:GetPhysicsObjectNum(Constraint["Bone1"]):GetAngles()
			end
			if IsValid(Constraint.Ent2) then
				Constraint.BuildDupeInfo.EntityPos = Constraint.Ent1:GetPos() - Constraint.Ent2:GetPos()
				Constraint.BuildDupeInfo.Ent2Ang = Constraint.Ent2:GetAngles()
				if(Constraint.Ent2:GetPhysicsObjectCount()>1)then
					Constraint.BuildDupeInfo.Bone2 = Constraint["Bone2"]
					Constraint.BuildDupeInfo.Bone2Pos = Constraint.Ent2:GetPhysicsObjectNum(Constraint["Bone2"]):GetPos() - Constraint.Ent2:GetPos()
					Constraint.BuildDupeInfo.Bone2Angle = Constraint.Ent2:GetPhysicsObjectNum(Constraint["Bone2"]):GetAngles()
				end
			elseif IsValid(Constraint.Ent4) then
				Constraint.BuildDupeInfo.EntityPos = Constraint.Ent1:GetPos() - Constraint.Ent4:GetPos()
				Constraint.BuildDupeInfo.Ent4Ang = Constraint.Ent4:GetAngles()
				if(Constraint.Ent4:GetPhysicsObjectCount()>1)then
					Constraint.BuildDupeInfo.Bone2 = Constraint["Bone4"]
					Constraint.BuildDupeInfo.Bone2Pos = Constraint.Ent4:GetPhysicsObjectNum(Constraint["Bone4"]):GetPos() - Constraint.Ent4:GetPos()
					Constraint.BuildDupeInfo.Bone2Angle = Constraint.Ent4:GetPhysicsObjectNum(Constraint["Bone4"]):GetAngles()
				end
			end
				
		end

	end
	
end


local function FixMagnet(Magnet)
	Magnet.Entity = Magnet
end

//Find out when a Constraint is created
timer.Simple(0, function()
					hook.Add( "OnEntityCreated", "AdvDupe2_SavePositions", function(entity)

						if not IsValid( entity ) then return end
						
						local a,b = entity:GetClass():match("^(.-)_(.+)")

						if b == "magnet" then
							timer.Simple( 0, function() FixMagnet(entity) end)
						end
						
						if a == "phys" then
							if(b=="constraintsystem")then return end
							timer.Simple( 0, function() SavePositions(entity) end)
						end

					end )
				end)

--	Register camera entity class
--	fixes key not being saved (Conna)
local function CamRegister(Player, Pos, Ang, Key, Locked, Toggle, Vel, aVel, Frozen, Nocollide)
	if (!Key) then return end
	
	local Camera = ents.Create("gmod_cameraprop")
	Camera:SetAngles(Ang)
	Camera:SetPos(Pos)
	Camera:Spawn()
	Camera:SetKey(Key)
	Camera:SetPlayer(Player)
	Camera:SetLocked(Locked)
	Camera.toggle = Toggle
	Camera:SetTracking(NULL, Vector(0))
	
	if (Toggle == 1) then
		numpad.OnDown(Player, Key, "Camera_Toggle", Camera)
	else
		numpad.OnDown(Player, Key, "Camera_On", Camera)
		numpad.OnUp(Player, Key, "Camera_Off", Camera)
	end
	
	if (Nocollide) then Camera:GetPhysicsObject():EnableCollisions(false) end
	
	-- Merge table
	local Table = {
		key			= Key,
		toggle 		= Toggle,
		locked      = Locked,
		pl			= Player,
		nocollide 	= nocollide
	}
	table.Merge(Camera:GetTable(), Table)
	
	-- remove any camera that has the same key defined for this player then add the new one
	local ID = Player:UniqueID()
	GAMEMODE.CameraList[ID] = GAMEMODE.CameraList[ID] or {}
	local List = GAMEMODE.CameraList[ID]
	if (List[Key] and List[Key] != NULL ) then
		local Entity = List[Key]
		Entity:Remove()
	end
	List[Key] = Camera
	return Camera
	
end
duplicator.RegisterEntityClass("gmod_cameraprop", CamRegister, "Pos", "Ang", "key", "locked", "toggle", "Vel", "aVel", "frozen", "nocollide")