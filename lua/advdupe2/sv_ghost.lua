
util.AddNetworkString("AdvDupe2_SendGhosts")
util.AddNetworkString("AdvDupe2_AddGhost")

function AdvDupe2.SendGhost(ply, AddOne)
	net.Start("AdvDupe2_AddGhost")
		net.WriteString(AddOne.Model)
		net.WriteInt(#AddOne.PhysicsObjects, 8)
		for i=0, #AddOne.PhysicsObjects do
			net.WriteAngle(AddOne.PhysicsObjects[i].Angle)
			net.WriteVector(AddOne.PhysicsObjects[i].Pos)
		end
	net.Send(ply)
end

function AdvDupe2.SendGhosts(ply)
	if(not ply.AdvDupe2.Entities)then return end

	local cache = {}
	local temp = {}
	local mdls = {}
	local cnt = 1
	local add = true
	local head

	for k,v in pairs(ply.AdvDupe2.Entities)do
		temp[cnt] = v
		for i=1,#cache do
			if(cache[i]==v.Model)then
				mdls[cnt] = i
				add=false
				break
			end
		end
		if(add)then
			mdls[cnt] = table.insert(cache, v.Model)
		else
			add = true
		end
		if(k==ply.AdvDupe2.HeadEnt.Index)then
			head = cnt
		end
		cnt = cnt+1
	end

	if(!head)then
		AdvDupe2.Notify(ply, "Invalid head entity for ghosts.", NOTIFY_ERROR);
		return
	end

	net.Start("AdvDupe2_SendGhosts")
		net.WriteInt(head, 16)
		net.WriteFloat(ply.AdvDupe2.HeadEnt.Z)
		net.WriteVector(ply.AdvDupe2.HeadEnt.Pos)
		net.WriteInt(#cache, 16)
		for i=1,#cache do
			net.WriteString(cache[i])
		end
		net.WriteInt(cnt-1, 16)
		for i=1, #temp do
			net.WriteInt(mdls[i], 16)
			net.WriteInt(#temp[i].PhysicsObjects, 8)
			for k=0, #temp[i].PhysicsObjects do
				net.WriteAngle(temp[i].PhysicsObjects[k].Angle)
				net.WriteVector(temp[i].PhysicsObjects[k].Pos)
			end
		end
	net.Send(ply)

end
