--Save a file to the client
local function SaveFile(ply, cmd, args)
	if(not ply.AdvDupe2 or not ply.AdvDupe2.Entities or next(ply.AdvDupe2.Entities)==nil)then AdvDupe2.Notify(ply,"Duplicator is empty, nothing to save.", NOTIFY_ERROR) return end
	if(not game.SinglePlayer() and CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
		AdvDupe2.Notify(ply,"Cannot save at the moment. Please Wait...", NOTIFY_ERROR)
		return
	end
	
	if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
		AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
		return false 
	end

	ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay")+2)
	
	local name = string.Explode("/", args[1])
	ply.AdvDupe2.Name = name[#name]
	
	net.Start("AdvDupe2_SetDupeInfo")
		net.WriteString(ply.AdvDupe2.Name)
		net.WriteString(ply:Nick())
		net.WriteString(os.date("%d %B %Y"))
		net.WriteString(os.date("%I:%M %p"))
		net.WriteString("")
		net.WriteString(args[2] or "")
		net.WriteString(table.Count(ply.AdvDupe2.Entities))
		net.WriteString(#ply.AdvDupe2.Constraints)
	net.Send(ply)
	
	local Tab = {Entities = ply.AdvDupe2.Entities, Constraints = ply.AdvDupe2.Constraints, HeadEnt = ply.AdvDupe2.HeadEnt, Description=args[2]}

	AdvDupe2.Encode( Tab, AdvDupe2.GenerateDupeStamp(ply), function(data)
		AdvDupe2.SendToClient(ply, data, 0)
	end)
end
concommand.Add("AdvDupe2_SaveFile", SaveFile)

function AdvDupe2.SendToClient(ply, data, autosave)
	if(not IsValid(ply))then return end
	ply.AdvDupe2.Downloading = true
	AdvDupe2.InitProgressBar(ply,"Saving:")

	net.Start("AdvDupe2_ReceiveFile")
	net.WriteUInt(autosave, 8)
	net.WriteStream(data, function()
		ply.AdvDupe2.Downloading = false
	end)
	net.Send(ply)
end

function AdvDupe2.LoadDupe(ply,success,dupe,info,moreinfo)
	if(not IsValid(ply))then return end
			
	if not success then 
		AdvDupe2.Notify(ply,"Could not open "..dupe,NOTIFY_ERROR)
		return
	end
			
	if(not game.SinglePlayer())then
		if(tonumber(GetConVarString("AdvDupe2_MaxConstraints"))~=0 and #dupe["Constraints"]>tonumber(GetConVarString("AdvDupe2_MaxConstraints")))then
			AdvDupe2.Notify(ply,"Amount of constraints is greater than "..GetConVarString("AdvDupe2_MaxConstraints"),NOTIFY_ERROR)
			return false
		end
	end

	ply.AdvDupe2.Entities = {}
	ply.AdvDupe2.Constraints = {}
	ply.AdvDupe2.HeadEnt={}

	if(info.ad1)then

		ply.AdvDupe2.HeadEnt.Index = tonumber(moreinfo.Head)
		local spx,spy,spz = moreinfo.StartPos:match("^(.-),(.-),(.+)$")
		ply.AdvDupe2.HeadEnt.Pos = Vector(tonumber(spx) or 0, tonumber(spy) or 0, tonumber(spz) or 0)
		local z = (tonumber(moreinfo.HoldPos:match("^.-,.-,(.+)$")) or 0)*-1
		ply.AdvDupe2.HeadEnt.Z = z
		ply.AdvDupe2.HeadEnt.Pos.Z = ply.AdvDupe2.HeadEnt.Pos.Z + z
		local Pos
		local Ang
		for k,v in pairs(dupe["Entities"])do
			Pos = nil
			Ang = nil
			if(v.SavedParentIdx)then 
				if(not v.BuildDupeInfo)then v.BuildDupeInfo = {} end
				v.BuildDupeInfo.DupeParentID = v.SavedParentIdx
				Pos = v.LocalPos*1
				Ang = v.LocalAngle*1
			end
			for i,p in pairs(v.PhysicsObjects)do
				p.Pos = Pos or (p.LocalPos*1)
				p.Pos.Z = p.Pos.Z - z
				p.Angle = Ang or (p.LocalAngle*1)
				p.LocalPos = nil
				p.LocalAngle = nil
				p.Frozen = not p.Frozen -- adv dupe 2 does this wrong way 
			end
			v.LocalPos = nil
			v.LocalAngle = nil
		end

		ply.AdvDupe2.Entities = dupe["Entities"]
		ply.AdvDupe2.Constraints = dupe["Constraints"]
		
	else	
		ply.AdvDupe2.Entities = dupe["Entities"]
		ply.AdvDupe2.Constraints = dupe["Constraints"]
		ply.AdvDupe2.HeadEnt = dupe["HeadEnt"]
	end
	AdvDupe2.ResetOffsets(ply, true)
end

local function AdvDupe2_ReceiveFile(len, ply)
	if not IsValid(ply) then return end
	if not ply.AdvDupe2 then ply.AdvDupe2 = {} end

	ply.AdvDupe2.Name = string.match(net.ReadString(), "([%w_ ]+)") or "Advanced Duplication"

	local stream = net.ReadStream(ply, function(data)
		if data then
			AdvDupe2.LoadDupe(ply, AdvDupe2.Decode(data))
		else
			AdvDupe2.Notify(ply, "Duplicator Upload Failed!", NOTIFY_ERROR, 5)
		end
		ply.AdvDupe2.Uploading = false
	end)

	if ply.AdvDupe2.Uploading then
		if stream then
			stream:Remove()
		end
		AdvDupe2.Notify(ply, "Duplicator is Busy!", NOTIFY_ERROR, 5)
	elseif stream then
		ply.AdvDupe2.Uploading = true
		AdvDupe2.InitProgressBar(ply, "Opening: ")
	end
end
net.Receive("AdvDupe2_ReceiveFile", AdvDupe2_ReceiveFile)
