--[[
	Title: Adv. Dupe 2 Networking (Serverside)
	
	Desc: Handles file transfers and all that jazz.
	
	Author: TB
	
	Version: 1.0
]]

include "nullesc.lua"
AddCSLuaFile "nullesc.lua"

AdvDupe2.Network = {}

AdvDupe2.Network.Networks = {}
AdvDupe2.Network.ClientNetworks = {}
AdvDupe2.Network.SvStaggerSendRate = 0
AdvDupe2.Network.ClStaggerSendRate = 0

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

--[[
	Name: EstablishNetwork
	Desc: Add user to the queue and set up to begin data sending
	Params: Player, File data
	Returns:
]]
function AdvDupe2.EstablishNetwork(ply, file)
	if(not IsValid(ply))then return end
	local id = ply:UniqueID()
	ply.AdvDupe2.Downloading = true
	AdvDupe2.Network.Networks[id] = {Player = ply, File=AdvDupe2.Null.esc(file), Length = #file, LastPos=1}
	
	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.SvStaggerSendRate - Cur_Time

	if(time > 0)then
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate")) + time
		timer.Simple(time, function() AdvDupe2_SendFile(id) end)
	else
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate"))
		AdvDupe2_SendFile(id)
	end
	
end

--[[
	Name: AdvDupe2_SendFile
	Desc: Client has responded and is ready for the next chunk of data
	Params: Network table, Network ID
	Returns:
]]
function AdvDupe2_SendFile(ID)
	local Net = AdvDupe2.Network.Networks[ID]
	
	if(not IsValid(Net.Player))then
		AdvDupe2.Network.Networks[ID] = nil
		return
	end
	
	local status = 0
	local data = ""

	if(Net.LastPos==1)then status = 1 AdvDupe2.InitProgressBar(Net.Player,"Saving:") end
	data = string.sub(Net.File, Net.LastPos, Net.LastPos+tonumber(GetConVarString("AdvDupe2_MaxDownloadBytes2")))

	Net.LastPos=Net.LastPos+tonumber(GetConVarString("AdvDupe2_MaxDownloadBytes2"))+1

	if(Net.LastPos>=Net.Length)then status = 2 end

	net.Start("AdvDupe2_ReceiveFile")
		net.WriteInt(status, 8)
		net.WriteString(data)
	net.Send(Net.Player)
	
	AdvDupe2.UpdateProgressBar(Net.Player, math.floor((Net.LastPos/Net.Length)*100))
	
	if(Net.LastPos>=Net.Length)then
		Net.Player.AdvDupe2.Downloading = false
		AdvDupe2.RemoveProgressBar(Net.Player)
		AdvDupe2.Network.Networks[ID] = nil
		return 
	end
	
	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.SvStaggerSendRate - Cur_Time
	
	timer.Simple(time, function() AdvDupe2_SendFile(ID) end)
	
	if(time > 0)then
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate")) + time
	else
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate"))
	end
	
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

function AdvDupe2.ReceiveNextStep(id)
	if(not IsValid(AdvDupe2.Network.ClientNetworks[id].Player))then AdvDupe2.Network.ClientNetworks[id] = nil return end
	umsg.Start("AdvDupe2_ReceiveNextStep", AdvDupe2.Network.ClientNetworks[id].Player)
		umsg.Short(tonumber(GetConVarString("AdvDupe2_MaxUploadBytes2")))
	umsg.End()
end

--[[
	Name: AdvDupe2_InitReceiveFile
	Desc: Start the file recieving process and send the servers settings to the client
	Params: concommand
	Returns:
]]
local function AdvDupe2_InitReceiveFile( ply, cmd, args )
	if(not IsValid(ply))then return end
	if(not ply.AdvDupe2)then ply.AdvDupe2={} end
	
	local id = ply:UniqueID()
	if(ply.AdvDupe2.Pasting or ply.AdvDupe2.Downloading or AdvDupe2.Network.ClientNetworks[id])then
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(false)
		umsg.End()
		AdvDupe2.Notify(ply, "Duplicator is Busy!",NOTIFY_ERROR,5)
		return
	end
	
	ply.AdvDupe2.Downloading = true
	ply.AdvDupe2.Uploading = true
	//ply.AdvDupe2.Name = args[1]
	
	AdvDupe2.Network.ClientNetworks[id] = {Player = ply, Data = "", Size = 0}
	
	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.ClStaggerSendRate - Cur_Time
	if(time > 0)then
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate")) + time
		AdvDupe2.Network.ClientNetworks[id].NextSend = time + Cur_Time
		timer.Simple(time, function() AdvDupe2.ReceiveNextStep(id) end)
	else
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate"))
		AdvDupe2.Network.ClientNetworks[id].NextSend = Cur_Time
		AdvDupe2.ReceiveNextStep(id)
	end

end
concommand.Add("AdvDupe2_InitReceiveFile", AdvDupe2_InitReceiveFile)


local function AdvDupe2_SetNextResponse(id)

	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.ClStaggerSendRate - Cur_Time
	if(time > 0)then
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate")) + time
		AdvDupe2.Network.ClientNetworks[id].NextSend = time + Cur_Time
		timer.Simple(time, function() AdvDupe2.ReceiveNextStep(id) end)
	else
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate"))
		AdvDupe2.Network.ClientNetworks[id].NextSend = Cur_Time
		AdvDupe2.ReceiveNextStep(id)
	end

end

--[[
	Name: AdvDupe2_ReceiveFile
	Desc: Receive file data from the client to save on the server
	Params: concommand
	Returns:
]]
local function AdvDupe2_ReceiveFile(len, ply, len2)
	if(not IsValid(ply))then return end

	local id = ply:UniqueID()
	if(not AdvDupe2.Network.ClientNetworks[id])then return end
	local Net = AdvDupe2.Network.ClientNetworks[id]
	
	//Someone tried to mess with upload commands
	if(Net.NextSend - CurTime()>0)then
		AdvDupe2.Network.ClientNetworks[id]=nil
		ply.AdvDupe2.Downloading = false
		ply.AdvDupe2.Uploading = false
		
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(false)
		umsg.End()
		AdvDupe2.Notify(ply,"Upload Rejected!",NOTIFY_GENERIC,5)
		return
	end

	local status = net.ReadBit()
	Net.Data = Net.Data..net.ReadString()

	if(status==1)then
		AdvDupe2.Decode(AdvDupe2.Null.invesc(Net.Data), function(success,dupe,info,moreinfo) AdvDupe2.LoadDupe(ply, success, dupe, info, moreinfo) end)
		AdvDupe2.Network.ClientNetworks[id]=nil
		ply.AdvDupe2.Downloading = false
		ply.AdvDupe2.Uploading = false
					
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(true)
		umsg.End()
		return
	end
	
	AdvDupe2_SetNextResponse(id)
end
net.Receive("AdvDupe2_ReceiveFile", AdvDupe2_ReceiveFile)