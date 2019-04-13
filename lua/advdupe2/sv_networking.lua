
local function CheckFileNameSv(path)
	if file.Exists(path..".txt", "DATA") then
		for i = 1, AdvDupe2.FileRenameTryLimit do
			if not file.Exists(path.."_"..i..".txt", "DATA") then
				return path.."_"..i..".txt"
			end
		end
	end

	return path..".txt"
end

function AdvDupe2.UpdateProgressBar(ply,percent)
	umsg.Start("AdvDupe2_UpdateProgressBar",ply)
		umsg.Char(percent)
	umsg.End()
end

function AdvDupe2.RemoveProgressBar(ply)
	umsg.Start("AdvDupe2_RemoveProgressBar",ply)
	umsg.End()
end

//===========================================
//=========	   Server To Client	    =========
//===========================================

function AdvDupe2.DownloadFile(ply, data, autosave)
	if(not IsValid(ply))then return end
	ply.AdvDupe2.Downloading = true

	net.Start("AdvDupe2_ReceiveFile")
		net.WriteInt(autosave, 8)
		net.WriteStream(data, function()
			ply.AdvDupe2.Downloading = false
		end)
	net.Send(Net.Player)
end


//===========================================
//=========	   Client To Server	    =========
//===========================================

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
	if(game.SinglePlayer())then AdvDupe2.SendGhosts(ply) end
	AdvDupe2.ResetOffsets(ply, true)
end

--[[
	Name: AdvDupe2_ReceiveFile
	Desc: Receive file data from the client to save on the server
	Params: concommand
	Returns:
]]
local function AdvDupe2_ReceiveFile(len, ply)
	if(not IsValid(ply))then return end
	
	if ply.AdvDupe2.Uploading then
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(false)
		umsg.End()
		AdvDupe2.Notify(ply, "Duplicator is Busy!",NOTIFY_ERROR,5)
		return
	end
	
	ply.AdvDupe2.Uploading = true
	
	local name = net.ReadString()
	local _1, _2, _3 = string.find(name, "([%w_]+)")
	if _3 then
		ply.AdvDupe2.Name = string.sub(_3, 1, 32)
	else
		ply.AdvDupe2.Name = "Advanced Duplication"
	end

	net.ReadStream(ply, function(data)
		AdvDupe2.LoadDupe(ply, AdvDupe2.Decode(data))
		ply.AdvDupe2.Uploading = false
					
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(true)
		umsg.End()
	end)
end
net.Receive("AdvDupe2_ReceiveFile", AdvDupe2_ReceiveFile)
