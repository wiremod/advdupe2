--[[
	Title: Miscellaneous
	
	Desc: Contains miscellaneous (serverside) things AD2 needs to function that don't fit anywhere else.
	
	Author: TB
	
	Version: 1.0
]]

--[[
	Name: AdvDupe2_BypassAddConstraintTable
	Desc: Hook into AddConstraintTable to get entities involved when a constraint is created
]]
hook.Add("Initialize","AdvDupe2_BypassAddConstraintTable",function()
	local old = constraint.AddConstraintTable
	function constraint.AddConstraintTable( Ent1, Constraint, Ent2, Ent3, Ent4 )
		if IsValid(Constraint) then
			old( Ent1, Constraint, Ent2, Ent3, Ent4 )

			timer.Simple(0, function()
				if Constraint.BuildDupeInfo then return end
				Constraint.BuildDupeInfo = {}

				if IsValid(Ent1) then
					Constraint.BuildDupeInfo.Ent1Ang = Ent1:GetAngles()
					if(Ent1:GetPhysicsObjectCount()>1)then
						Constraint.BuildDupeInfo.Bone1 = Constraint["Bone1"]
						Constraint.BuildDupeInfo.Bone1Pos = Ent1:GetPhysicsObjectNum(Constraint["Bone1"]):GetPos() - Ent1:GetPos()
						Constraint.BuildDupeInfo.Bone1Angle = Ent1:GetPhysicsObjectNum(Constraint["Bone1"]):GetAngles()
					end
					if IsValid(Ent2) then
						Constraint.BuildDupeInfo.EntityPos = Ent1:GetPos() - Ent2:GetPos()
						Constraint.BuildDupeInfo.Ent2Ang = Ent2:GetAngles()
						if(Ent2:GetPhysicsObjectCount()>1)then
							Constraint.BuildDupeInfo.Bone2 = Constraint["Bone2"]
							Constraint.BuildDupeInfo.Bone2Pos = Ent2:GetPhysicsObjectNum(Constraint["Bone2"]):GetPos() - Ent2:GetPos()
							Constraint.BuildDupeInfo.Bone2Angle = Ent2:GetPhysicsObjectNum(Constraint["Bone2"]):GetAngles()
						end
					elseif IsValid(Ent4) then
						Constraint.BuildDupeInfo.EntityPos = Ent1:GetPos() - Ent4:GetPos()
						Constraint.BuildDupeInfo.Ent2Ang = Ent4:GetAngles()
						if(Ent4:GetPhysicsObjectCount()>1)then
							Constraint.BuildDupeInfo.Bone2 = Constraint["Bone4"]
							Constraint.BuildDupeInfo.Bone2Pos = Ent4:GetPhysicsObjectNum(Constraint["Bone4"]):GetPos() - Ent4:GetPos()
							Constraint.BuildDupeInfo.Bone2Angle = Ent4:GetPhysicsObjectNum(Constraint["Bone4"]):GetAngles()
						end
					end
				end
			end)
		end
	end
end)
