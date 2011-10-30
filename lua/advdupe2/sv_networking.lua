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
	if file.Exists(path..".txt") then
		for i = 1, AdvDupe2.FileRenameTryLimit do
			if not file.Exists(path.."_"..i..".txt") then
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
	Name: AdvDupe2_SendFile
	Desc: Client has responded and is ready for the next chunk of data
	Params: Network table, Network ID
	Returns:
]]
function AdvDupe2_SendFile(ID)
	
	local Net = AdvDupe2.Network.Networks[ID]
	local Network = AdvDupe2.Network
	
	if(!IsValid(Net.Player))then
		AdvDupe2.Network.Networks[ID] = nil
		return
	end
	
	local status = 0
	
	local data = ""
	for i=1,tonumber(GetConVarString("AdvDupe2_ServerDataChunks")) do
		status = 0
		if(Net.LastPos==1)then status = 1 AdvDupe2.InitProgressBar(Net.Player,"Downloading:") end
		data = string.sub(Net.File, Net.LastPos, Net.LastPos+tonumber(GetConVarString("AdvDupe2_MaxDownloadBytes")))

		Net.LastPos=Net.LastPos+tonumber(GetConVarString("AdvDupe2_MaxDownloadBytes"))+1
		if(Net.LastPos>=Net.Length)then status = 2 end

		umsg.Start("AdvDupe2_RecieveFile", Net.Player)
			umsg.Short(status)
			umsg.String(data)
		umsg.End()
		
		if(status==2)then break end
	end
	
	AdvDupe2.UpdateProgressBar(Net.Player, math.floor((Net.LastPos/Net.Length)*100))
	
	if(Net.LastPos>=Net.Length)then
		Net.Player.AdvDupe2.Downloading = false
		AdvDupe2.RemoveProgressBar(Net.Player)
		if(Net.Player.AdvDupe2.Entities && !Net.Player.AdvDupe2.GhostEntities)then
			AdvDupe2.StartGhosting(Net.Player)
		end
		
		AdvDupe2.Network.Networks[ID] = nil
		return 
	end
	
	local Cur_Time = CurTime()
	local time = Network.SvStaggerSendRate - Cur_Time
	
	timer.Simple(time, AdvDupe2_SendFile, ID)
	
	if(time > 0)then
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate")) + time
	else
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate"))
	end
	
end


--[[
	Name: EstablishNetwork
	Desc: Add user to the queue and set up to begin data sending
	Params: Player, File data
	Returns:
]]
function AdvDupe2.EstablishNetwork(ply, file)
	if(!IsValid(ply))then return end
	
	if(!tobool(GetConVarString("AdvDupe2_AllowDownloading")))then
		AdvDupe2.Notify(ply,"Downloading is not allowed!",NOTIFY_ERROR,5)
		return
	end

	file = AdvDupe2.Null.esc(file)

	local id = ply:UniqueID()
	ply.AdvDupe2.Downloading = true
	AdvDupe2.Network.Networks[id] = {Player = ply, File=file, Length = #file, LastPos=1}
	
	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.SvStaggerSendRate - Cur_Time

	if(time > 0)then
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate")) + time
		timer.Simple(time, AdvDupe2_SendFile, id)
	else
		AdvDupe2.Network.SvStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ServerSendRate"))
		AdvDupe2_SendFile(id)
	end
	
end

function AdvDupe2.RecieveNextStep(id)
	if(!IsValid(AdvDupe2.Network.ClientNetworks[id].Player))then AdvDupe2.Network.ClientNetworks[id] = nil return end
	umsg.Start("AdvDupe2_RecieveNextStep", AdvDupe2.Network.ClientNetworks[id].Player)
		umsg.Short(tonumber(GetConVarString("AdvDupe2_MaxUploadBytes")))
		umsg.Short(tonumber(GetConVarString("AdvDupe2_ClientDataChunks")))
	umsg.End()
end

//===========================================
//=========	   Client To Server	    =========
//===========================================


local function GetPlayersFolder(ply)
	local path
	if SinglePlayer() then
		path = string.format("%s", AdvDupe2.DataFolder)
	else
		path = string.format("%s/%s", AdvDupe2.DataFolder, ply:SteamID():gsub(":","_"))
	end
	return path
end

--[[
	Name: AdvDupe2_InitRecieveFile
	Desc: Start the file recieving process and send the servers settings to the client
	Params: concommand
	Returns:
]]
local function AdvDupe2_InitRecieveFile( ply, cmd, args )
	if(!IsValid(ply))then return end
	if(!tobool(GetConVarString("AdvDupe2_AllowUploading")))then
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(true)
		umsg.End()
		AdvDupe2.Notify(ply, "Uploading is not allowed!",NOTIFY_ERROR,5)
		return
	elseif(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
		umsg.Start("AdvDupe2_UploadRejected", ply)
			umsg.Bool(false)
		umsg.End()
		AdvDupe2.Notify(ply, "Duplicator is Busy!",NOTIFY_ERROR,5)
		return
	end
	
	local path = args[1]
	local area = tonumber(args[2])
	
	if(area==0)then
		path = GetPlayersFolder(ply).."/"..path
	elseif(area==1)then
		if(!tobool(GetConVarString("AdvDupe2_AllowPublicFolder")))then
			umsg.Start("AdvDupe2_UploadRejected", ply)
				umsg.Bool(true)
			umsg.End()
			AdvDupe2.Notify(ply,"Public Folder is disabled."..dupe,NOTIFY_ERROR)
			return
		end
		path = AdvDupe2.DataFolder.."/=Public=/"..path
	else
		path = "adv_duplicator/"..ply:SteamIDSafe().."/"..path
	end
	
	local id = ply:UniqueID()
	if(AdvDupe2.Network.ClientNetworks[id])then return false end
	ply.AdvDupe2.Downloading = true
	ply.AdvDupe2.Uploading = true
	
	AdvDupe2.Network.ClientNetworks[id] = {Player = ply, Data = "", Size = 0, Name = path, SubN = args[3], SubQ = args[4], ParentID = tonumber(args[5]), Parts = 0}
	
	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.ClStaggerSendRate - Cur_Time
	if(time > 0)then
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate")) + time
		AdvDupe2.Network.ClientNetworks[id].NextSend = time + Cur_Time
		timer.Simple(time, AdvDupe2.RecieveNextStep, id)
	else
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate"))
		AdvDupe2.Network.ClientNetworks[id].NextSend = Cur_Time
		AdvDupe2.RecieveNextStep(id)
	end

end
concommand.Add("AdvDupe2_InitRecieveFile", AdvDupe2_InitRecieveFile)


local function AdvDupe2_SetNextResponse(id)

	local Cur_Time = CurTime()
	local time = AdvDupe2.Network.ClStaggerSendRate - Cur_Time
	if(time > 0)then
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate")) + time
		AdvDupe2.Network.ClientNetworks[id].NextSend = time + Cur_Time
		timer.Simple(time, AdvDupe2.RecieveNextStep, id)
	else
		AdvDupe2.Network.ClStaggerSendRate = Cur_Time + tonumber(GetConVarString("AdvDupe2_ClientSendRate"))
		AdvDupe2.Network.ClientNetworks[id].NextSend = Cur_Time
		AdvDupe2.RecieveNextStep(id)
	end

end

--[[
	Name: AdvDupe2_RecieveFile
	Desc: Recieve file data from the client to save on the server
	Params: concommand
	Returns:
]]
local function AdvDupe2_RecieveFile(ply, cmd, args)
	if(!IsValid(ply))then return end
	
	local id = ply:UniqueID()
	if(!AdvDupe2.Network.ClientNetworks[id])then return end
	local Net = AdvDupe2.Network.ClientNetworks[id]
	
	//Someone tried to mess with upload concommands
	if(Net.NextSend - CurTime()>0)then
		AdvDupe2.Network.ClientNetworks[id]=nil
		ply.AdvDupe2.Downloading = false
		ply.AdvDupe2.Uploading = false
		
		umsg.Start("AdvDupe2_UploadRejected")
			umsg.Bool(true)
		umsg.End()
		AdvDupe2.Notify(ply,"Upload Rejected!",NOTIFY_GENERIC,5)
	end

	local data = args[2]
	
	Net.Data = Net.Data..data
	Net.Parts = Net.Parts + 1
	
	if(tonumber(args[1])!=0)then
		Net.Data = string.gsub(Net.Data, Net.SubN, "\10")
		Net.Data = string.gsub(Net.Data, Net.SubQ, [["]])
		Net.Name = CheckFileNameSv(Net.Name)
		local filename = string.Explode("/", Net.Name)
		Net.FileName = string.sub(filename[#filename], 1, -5)

		file.Write(Net.Name, AdvDupe2.Null.invesc(Net.Data))

		umsg.Start("AdvDupe2_AddFile",ply)
			umsg.String(Net.FileName)
			umsg.Short(Net.ParentID)
			umsg.Bool(true)
		umsg.End()
		
		AdvDupe2.Network.ClientNetworks[id]=nil
		ply.AdvDupe2.Downloading = false
		ply.AdvDupe2.Uploading = false
		if(ply.AdvDupe2.Entities && !ply.AdvDupe2.GhostEntities)then
			AdvDupe2.StartGhosting(ply)
		end
		
		umsg.Start("AdvDupe2_UploadRejected")
			umsg.Bool(false)
		umsg.End()
		AdvDupe2.Notify(ply,"File successfully uploaded!",NOTIFY_GENERIC,5)
		return
	end
	
	if(Net.Parts == tonumber(GetConVarString("AdvDupe2_ClientDataChunks")))then
		Net.Parts = 0
		AdvDupe2_SetNextResponse(id)
	end
end
concommand.Add("AdvDupe2_RecieveFile", AdvDupe2_RecieveFile)
