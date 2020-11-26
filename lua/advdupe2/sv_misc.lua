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

local function monitorConstraint(name)
	local oldFunc = constraint[name]
	constraint[name] = function(...)
		local Constraint, b, c = oldFunc(...)
		if Constraint and Constraint:IsValid() then
			SavePositions(Constraint)
		end
		return Constraint, b, c
	end
end
monitorConstraint("AdvBallsocket")
monitorConstraint("Axis")
monitorConstraint("Ballsocket")
monitorConstraint("Elastic")
monitorConstraint("Hydraulic")
monitorConstraint("Keepupright")
monitorConstraint("Motor")
monitorConstraint("Muscle")
monitorConstraint("Pulley")
monitorConstraint("Rope")
monitorConstraint("Slider")
monitorConstraint("Weld")
monitorConstraint("Winch")
