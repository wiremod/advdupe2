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
		local BuildDupeInfo = {}
		Constraint.BuildDupeInfo = BuildDupeInfo
			
		local Ent1, Ent2
		if IsValid(Constraint.Ent) then
			if Constraint.Ent:GetPhysicsObjectCount()>1 then
				BuildDupeInfo.Ent1Ang = Constraint.Ent:GetAngles()
			else
				BuildDupeInfo.Ent1Ang = Constraint.Ent:GetPhysicsObject():GetAngles()
			end
		end

		if IsValid(Constraint.Ent1) then
			if Constraint.Ent1:GetPhysicsObjectCount()>1 then
				local Bone = Constraint.Ent1:GetPhysicsObjectNum(Constraint.Bone1)
				BuildDupeInfo.Ent1Ang = Constraint.Ent1:GetAngles()
				BuildDupeInfo.Ent1Pos = Constraint.Ent1:GetPos()
				BuildDupeInfo.Bone1 = Constraint.Bone1
				BuildDupeInfo.Bone1Pos = Bone:GetPos() - Constraint.Ent1:GetPos()
				BuildDupeInfo.Bone1Angle = Bone:GetAngles()
			else
				local Bone = Constraint.Ent1:GetPhysicsObject()
				BuildDupeInfo.Ent1Ang = Bone:GetAngles()
				BuildDupeInfo.Ent1Pos = Bone:GetPos()
			end

			if IsValid(Constraint.Ent2) then
				if Constraint.Ent2:GetPhysicsObjectCount()>1 then
					local Bone = Constraint.Ent2:GetPhysicsObjectNum(Constraint.Bone2)
					BuildDupeInfo.EntityPos = BuildDupeInfo.Ent1Pos - Constraint.Ent2:GetPos()
					BuildDupeInfo.Ent2Ang = Constraint.Ent2:GetAngles()
					BuildDupeInfo.Bone2 = Constraint.Bone2
					BuildDupeInfo.Bone2Pos = Bone:GetPos() - Constraint.Ent2:GetPos()
					BuildDupeInfo.Bone2Angle = Bone:GetAngles()
				else
					local Bone = Constraint.Ent2:GetPhysicsObject()
					BuildDupeInfo.EntityPos = BuildDupeInfo.Ent1Pos - Bone:GetPos()
					BuildDupeInfo.Ent2Ang = Bone:GetAngles()
				end
			elseif IsValid(Constraint.Ent4) then
				if Constraint.Ent4:GetPhysicsObjectCount()>1 then
					local Bone = Constraint.Ent4:GetPhysicsObjectNum(Constraint.Bone4)
					BuildDupeInfo.Bone2 = Constraint.Bone4
					BuildDupeInfo.EntityPos = BuildDupeInfo.Ent1Pos - Constraint.Ent4:GetPos()
					BuildDupeInfo.Ent2Ang = Constraint.Ent4:GetAngles()
					BuildDupeInfo.Bone2Pos = Bone:GetPos() - Constraint.Ent4:GetPos()
					BuildDupeInfo.Bone2Angle = Bone:GetAngles()
				else
					local Bone = Constraint.Ent4:GetPhysicsObject()
					BuildDupeInfo.EntityPos = BuildDupeInfo.Ent1Pos - Bone:GetPos()
					BuildDupeInfo.Ent2Ang = Bone:GetAngles()
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
