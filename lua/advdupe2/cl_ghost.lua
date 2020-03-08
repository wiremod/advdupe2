function AdvDupe2.LoadGhosts(dupe, info, moreinfo, name, preview)

	AdvDupe2.RemoveGhosts()
	AdvDupe2.Ghosting = true

	AdvDupe2.GhostToSpawn = {}
	local count = 0

	local time
	local desc
	local date
	local creator

	if(info.ad1)then
		time = moreinfo["Time"] or ""
		desc = info["Description"] or ""
		date = info["Date"] or ""
		creator = info["Creator"] or ""

		AdvDupe2.HeadEnt = dupe.HeadEnt.Index
		AdvDupe2.HeadPos = dupe.HeadEnt.Pos
		local z = dupe.HeadEnt.Z
		AdvDupe2.HeadZPos = z
		AdvDupe2.HeadPos.Z = AdvDupe2.HeadPos.Z + z

		local Pos
		local Ang
		for k,v in pairs(dupe["Entities"])do

			if(v.SavedParentIdx)then
				if(not v.BuildDupeInfo)then v.BuildDupeInfo = {} end
				v.BuildDupeInfo.DupeParentID = v.SavedParentIdx
				Pos = v.LocalPos*1
				Ang = v.LocalAngle*1
			else
				Pos = nil
				Ang = nil
			end
			for i,p in pairs(v.PhysicsObjects)do
				p.Pos = Pos or (p.LocalPos*1)
				p.Pos.Z = p.Pos.Z - z
				p.Angle = Ang or (p.LocalAngle*1)
				p.LocalPos = nil
				p.LocalAngle = nil
			end
			v.LocalPos = nil
			v.LocalAngle = nil
			AdvDupe2.GhostToSpawn[count] = {Model=v.Model, PhysicsObjects=v.PhysicsObjects}
			if(AdvDupe2.HeadEnt == k)then
				AdvDupe2.HeadEnt = count
			end
			count = count + 1
		end

		AdvDupe2.HeadOffset = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Pos
		AdvDupe2.HeadAngle = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Angle

	else
		time = info["time"] or ""
		desc = dupe["Description"] or ""
		date = info["date"] or ""
		creator = info["name"] or ""

		AdvDupe2.HeadEnt = dupe["HeadEnt"].Index
		AdvDupe2.HeadZPos = dupe["HeadEnt"].Z
		AdvDupe2.HeadPos = dupe["HeadEnt"].Pos
		AdvDupe2.HeadOffset = dupe["Entities"][AdvDupe2.HeadEnt].PhysicsObjects[0].Pos
		AdvDupe2.HeadAngle = dupe["Entities"][AdvDupe2.HeadEnt].PhysicsObjects[0].Angle

		for k,v in pairs(dupe["Entities"])do
			AdvDupe2.GhostToSpawn[count] = {Model=v.Model, PhysicsObjects=v.PhysicsObjects}
			if(AdvDupe2.HeadEnt == k)then
				AdvDupe2.HeadEnt = count
			end
			count = count + 1
		end
	end

	if(not preview)then
		AdvDupe2.Info.File:SetText("File: "..name)
		AdvDupe2.Info.Creator:SetText("Creator: "..creator)
		AdvDupe2.Info.Date:SetText("Date: "..date)
		AdvDupe2.Info.Time:SetText("Time: "..time)
		AdvDupe2.Info.Size:SetText("Size: "..string.NiceSize(tonumber(info.size) or 0))
		AdvDupe2.Info.Desc:SetText("Desc: "..(desc or ""))
		AdvDupe2.Info.Entities:SetText("Entities: "..table.Count(dupe["Entities"]))
		AdvDupe2.Info.Constraints:SetText("Constraints: "..table.Count(dupe["Constraints"]))
	end

	AdvDupe2.StartGhosting()
	AdvDupe2.Preview = preview

end

function AdvDupe2.RemoveGhosts()

	if(AdvDupe2.Ghosting)then
		hook.Remove("Tick", "AdvDupe2_SpawnGhosts")
		AdvDupe2.Ghosting = false
		if(not AdvDupe2.BusyBar)then
			AdvDupe2.RemoveProgressBar()
		end
	end

	if(AdvDupe2.GhostEntities)then
		for k,v in pairs(AdvDupe2.GhostEntities)do
			if(IsValid(v))then
				v:Remove()
			end
		end
	end

	if(IsValid(AdvDupe2.HeadGhost))then
		AdvDupe2.HeadGhost:Remove()
	end
	AdvDupe2.HeadGhost = nil
	AdvDupe2.CurrentGhost = 1
	AdvDupe2.GhostEntities = nil
	AdvDupe2.Preview = false
end

--Creates a ghost from the given entity's table
local function MakeGhostsFromTable(EntTable)

	if(not EntTable)then return end
	if(not EntTable.Model or EntTable.Model=="" or EntTable.Model[#EntTable.Model-3]~=".")then EntTable.Model="models/error.mdl" end

	local GhostEntity = ClientsideModel(EntTable.Model, RENDERGROUP_TRANSLUCENT)

	-- If there are too many entities we might not spawn..
	if not IsValid(GhostEntity) then
		AdvDupe2.RemoveGhosts()
		AdvDupe2.Notify("Too many entities to spawn ghosts", NOTIFY_ERROR)
		return
	end

	GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )	--Was broken, making ghosts invisible
	GhostEntity:SetColor( Color(255, 255, 255, 150) )
	GhostEntity.Phys = EntTable.PhysicsObjects[0]

	if util.IsValidRagdoll(EntTable.Model) then
		GhostEntity:SetupBones()
		local parents = {}
		local angs = {}
		local ref = {}
		for k, v in pairs( EntTable.PhysicsObjects ) do
			local bone = GhostEntity:TranslatePhysBoneToBone(k)
			local parentbone = GhostEntity:GetBoneParent(bone)
			if parentbone == -1 then
				ref[bone] = GhostEntity:GetBoneMatrix(bone):GetInverseTR()
			else
				parentbone = GhostEntity:TranslatePhysBoneToBone(GhostEntity:TranslateBoneToPhysBone(parentbone))
				parents[bone] = parentbone
				ref[bone] = GhostEntity:GetBoneMatrix(bone):GetInverseTR() * GhostEntity:GetBoneMatrix(parentbone)
			end
			local m = Matrix() m:SetAngles(v.Angle)
			angs[bone] = m
		end
		for bone, ang in pairs( angs ) do
			if parents[bone] and angs[parents[bone]] then
				local localrotation = angs[parents[bone]]:GetInverseTR() * ang
				local m = ref[bone] * localrotation
				GhostEntity:ManipulateBoneAngles(bone, m:GetAngles())
			else
				local pos = GhostEntity:GetBonePosition(bone)
				GhostEntity:ManipulateBonePosition(bone, -pos)
				GhostEntity:ManipulateBoneAngles(bone, ref[bone]:GetAngles())
			end
		end
	end

	return GhostEntity
end

local function SpawnGhosts()
	if AdvDupe2.CurrentGhost==AdvDupe2.HeadEnt then AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + 1 end

	local g = AdvDupe2.GhostToSpawn[AdvDupe2.CurrentGhost]
	if g then
		AdvDupe2.GhostEntities[AdvDupe2.CurrentGhost] = MakeGhostsFromTable(g)
		if(not AdvDupe2.BusyBar)then
			AdvDupe2.ProgressBar.Percent = AdvDupe2.CurrentGhost/AdvDupe2.TotalGhosts*100
		end
		AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + 1
		AdvDupe2.UpdateGhosts(true)
	else
		AdvDupe2.Ghosting = false
		hook.Remove("Tick", "AdvDupe2_SpawnGhosts")
		if(not AdvDupe2.BusyBar)then
			AdvDupe2.RemoveProgressBar()
		end
	end
end

net.Receive("AdvDupe2_SendGhosts", 	function(len, ply, len2)
	AdvDupe2.RemoveGhosts()
	AdvDupe2.GhostToSpawn = {}
	AdvDupe2.HeadEnt = net.ReadInt(16)
	AdvDupe2.HeadZPos = net.ReadFloat()
	AdvDupe2.HeadPos = net.ReadVector()
	local cache = {}
	for i=1, net.ReadInt(16) do
		cache[i] = net.ReadString()
	end

	for i=1, net.ReadInt(16) do
		AdvDupe2.GhostToSpawn[i] = {Model = cache[net.ReadInt(16)], PhysicsObjects = {}}
		for k=0, net.ReadInt(8) do
			AdvDupe2.GhostToSpawn[i].PhysicsObjects[k] = {Angle = net.ReadAngle(), Pos = net.ReadVector()}
		end
	end

	AdvDupe2.GhostEntities = {}
	AdvDupe2.HeadGhost = MakeGhostsFromTable(AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt])
	AdvDupe2.HeadOffset = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Pos
	AdvDupe2.HeadAngle = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Angle
	AdvDupe2.GhostEntities[AdvDupe2.HeadEnt] = AdvDupe2.HeadGhost
	AdvDupe2.CurrentGhost = 1
	AdvDupe2.TotalGhosts = #AdvDupe2.GhostToSpawn

	if(AdvDupe2.TotalGhosts>1)then
		AdvDupe2.Ghosting = true
		if(not AdvDupe2.BusyBar)then
			AdvDupe2.InitProgressBar("Ghosting: ")
			AdvDupe2.BusyBar = false
		end
		hook.Add("Tick", "AdvDupe2_SpawnGhosts", SpawnGhosts)
	else
		AdvDupe2.Ghosting = false
	end
end)

net.Receive("AdvDupe2_AddGhost", function(len, ply, len2)
	local ghost = {Model = net.ReadString(), PhysicsObjects = {}}
	for k=0, net.ReadInt(8) do
		ghost.PhysicsObjects[k] = {Angle = net.ReadAngle(), Pos = net.ReadVector()}
	end
	AdvDupe2.GhostEntities[AdvDupe2.CurrentGhost] = MakeGhostsFromTable(ghost)
	AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + 1
end)

function AdvDupe2.StartGhosting()
	AdvDupe2.RemoveGhosts()
	if(not AdvDupe2.GhostToSpawn)then return end
	AdvDupe2.Ghosting = true
	AdvDupe2.GhostEntities = {}
	AdvDupe2.HeadGhost = MakeGhostsFromTable(AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt])
	AdvDupe2.GhostEntities[AdvDupe2.HeadEnt] = AdvDupe2.HeadGhost
	AdvDupe2.CurrentGhost = 1
	AdvDupe2.TotalGhosts = #AdvDupe2.GhostToSpawn

	if AdvDupe2.TotalGhosts > 1 then
		if(not AdvDupe2.BusyBar)then
			AdvDupe2.InitProgressBar("Ghosting: ")
			AdvDupe2.BusyBar = false
		end
		hook.Add("Tick", "AdvDupe2_SpawnGhosts", SpawnGhosts)
	else
		AdvDupe2.Ghosting = false
	end
end
usermessage.Hook("AdvDupe2_StartGhosting", function()
	AdvDupe2.StartGhosting()
end)

usermessage.Hook("AdvDupe2_RemoveGhosts", AdvDupe2.RemoveGhosts)

--Update the ghost's postion and angles based on where the player is looking and the offsets
local Lheadpos, Lheadang = Vector(), Angle()
function AdvDupe2.UpdateGhosts(force)
	if not IsValid(AdvDupe2.HeadGhost) then
		AdvDupe2.RemoveGhosts()
		AdvDupe2.Notify("Invalid ghost parent.", NOTIFY_ERROR)
		return
	end

	local trace = util.TraceLine(util.GetPlayerTrace(LocalPlayer(), LocalPlayer():GetAimVector()))
	if (not trace.Hit) then return end
	
	local origin, offsetang, headpos, headang
	if(tobool(GetConVarNumber("advdupe2_original_origin")))then
		headpos = AdvDupe2.HeadPos + AdvDupe2.HeadOffset
		headang = AdvDupe2.HeadAngle
		origin = AdvDupe2.HeadPos
		offsetang = Angle()
	else
		local headangle = AdvDupe2.HeadAngle
		if(tobool(GetConVarNumber("advdupe2_offset_world")))then headangle = Angle(0,0,0) end
		trace.HitPos.Z = trace.HitPos.Z + math.Clamp(AdvDupe2.HeadZPos + GetConVarNumber("advdupe2_offset_z") or 0, -16000, 16000)
		origin = trace.HitPos
		offsetang = Angle(math.Clamp(GetConVarNumber("advdupe2_offset_pitch") or 0,-180,180), math.Clamp(GetConVarNumber("advdupe2_offset_yaw") or 0,-180,180), math.Clamp(GetConVarNumber("advdupe2_offset_roll") or 0,-180,180))
		headpos, headang = LocalToWorld(AdvDupe2.HeadOffset, headangle, origin, offsetang)
	end

	if math.abs(Lheadpos.x - headpos.x)>0.01 or math.abs(Lheadpos.y - headpos.y)>0.01 or math.abs(Lheadpos.z - headpos.z)>0.01 or
	   math.abs(Lheadang.p - headang.p)>0.01 or math.abs(Lheadang.y - headang.y)>0.01 or math.abs(Lheadang.r - headang.r)>0.01 or force then

		Lheadpos = headpos
		Lheadang = headang

		AdvDupe2.HeadGhost:SetPos(headpos)
		AdvDupe2.HeadGhost:SetAngles(headang)

		for k, ghost in ipairs(AdvDupe2.GhostEntities) do
			local phys = ghost.Phys
			local pos, ang = LocalToWorld(phys.Pos, phys.Angle, origin, offsetang)
			ghost:SetPos(pos)
			ghost:SetAngles(ang)
		end

	end
end
