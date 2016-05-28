AdvDupe2 = {
	Version = "1.1.0",
	Revision = 51
}

AdvDupe2.DataFolder = "advdupe2" --name of the folder in data where dupes will be saved

AdvDupe2.FileRenameTryLimit = 256

include "advdupe2/sv_clipboard.lua"
include "advdupe2/sh_codec.lua"
include "advdupe2/sv_file.lua"
include "advdupe2/sv_networking.lua"
include "advdupe2/sv_misc.lua"

AddCSLuaFile "autorun/client/advdupe2_cl_init.lua"
AddCSLuaFile "advdupe2/cl_networking.lua"
AddCSLuaFile "advdupe2/cl_file.lua"
AddCSLuaFile "advdupe2/file_browser.lua"
AddCSLuaFile "advdupe2/sh_codec.lua"

function AdvDupe2.Notify(ply,msg,typ, showsvr, dur)
	umsg.Start("AdvDupe2Notify",ply)
		umsg.String(msg)
		umsg.Char(typ or NOTIFY_GENERIC)
		umsg.Char(dur or 5)
	umsg.End()
	if(showsvr==true)then
		print("[AdvDupe2Notify]\t"..ply:Nick()..": "..msg)
	end
end

AdvDupe2.SpawnRate = AdvDupe2.SpawnRate or 1
CreateConVar("AdvDupe2_SpawnRate", "1", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxFileSize", "200", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxEntities", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxConstraints", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowUploading", "true", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowDownloading", "true", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowPublicFolder", "true", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_MaxContraptionEntities", "10", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxContraptionConstraints", "15", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MinContraptionSpawnDelay", "0.2", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MinContraptionUndoDelay", "0.1", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxContraptionUndoDelay", "60", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_AreaAutoSaveTime", "10", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_MaxAreaCopySize", "2500", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_FileModificationDelay", "5", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_UpdateFilesDelay", "10", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_MaxDownloadBytes2", "10000", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxUploadBytes2", "10000", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_ServerSendRate", "1", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_ClientSendRate", "1", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_LoadMap", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MapFileName", "", {FCVAR_ARCHIVE})

cvars.AddChangeCallback("AdvDupe2_SpawnRate",
	function(cvar, preval, newval)
		newval = tonumber(newval)
		if(newval~=nil and newval<=1 and newval>0)then
			AdvDupe2.SpawnRate = newval
		else
			print("[AdvDupe2Notify]\tINVALID SPAWN RATE")
		end
	end)
	
local function PasteMap()
	local filename = GetConVarString("AdvDupe2_MapFileName")
	
	if(not filename or filename == "")then
		print("[AdvDupe2Notify]\tInvalid file name to loap map save.")
		return
	end
	
	if(not file.Exists("advdupe2_maps/"..filename..".txt", "DATA"))then
		print("[AdvDupe2Notify]\tFile does not exist for a map save.")
		return
	end
	
	local map = file.Read("advdupe2_maps/"..filename..".txt")
	AdvDupe2.Decode(map, function(success,dupe,info,moreinfo) 
														if not success then 
															print("[AdvDupe2Notify]\tCould not open map save "..dupe)
															return
														end	
														
														local Tab = {Entities=dupe["Entities"], Constraints=dupe["Constraints"], HeadEnt=dupe["HeadEnt"]}
														local Entities = AdvDupe2.duplicator.Paste(nil, table.Copy(Tab.Entities), Tab.Constraints, nil, nil, Tab.HeadEnt.Pos, true)
														local maptype = GetConVarString("AdvDupe2_LoadMap")
														
														if(maptype=="1")then
															local PhysObj
															local valid
															for k,v in pairs(Entities) do
																valid = Entities[k]
																if(IsValid(valid))then
																	for i=0, #Tab.Entities[k].PhysicsObjects do
																		if(Tab.Entities[k].PhysicsObjects[i].Frozen)then
																			PhysObj = valid:GetPhysicsObjectNum( i )
																			if IsValid(PhysObj) then
																				PhysObj:EnableMotion(true)
																			end
																		end
																	end
																end
															end
														elseif(maptype=="2")then
															local PhysObj
															local valid
															for k,v in pairs(Entities) do
																valid = Entities[k]
																if(IsValid(valid))then
																	for i=0, #Tab.Entities[k].PhysicsObjects do
																		PhysObj = valid:GetPhysicsObjectNum( i )
																		if IsValid(PhysObj) then
																			PhysObj:EnableMotion(true)
																		end
																	end
																end
															end
														end
														
														print("[AdvDupe2Notify]\tMap save pasted.")
													end)
	
	
end

util.AddNetworkString("AdvDupe2_AddFile")
util.AddNetworkString("AdvDupe2_AddFolder")
util.AddNetworkString("AdvDupe2_RenameFile")
util.AddNetworkString("AdvDupe2_MoveFile")
util.AddNetworkString("AdvDupe2_DeleteNode")
util.AddNetworkString("AdvDupe2_SendFiles")
util.AddNetworkString("AdvDupe2_SetDupeInfo")
util.AddNetworkString("AdvDupe2_RecieveFile")
util.AddNetworkString("AdvDupe2_InitRecieveFile")
util.AddNetworkString("AdvDupe2_RecieveFile")
util.AddNetworkString("AdvDupe2_DownloadFile")
util.AddNetworkString("AdvDupe2_ReceiveFile")
util.AddNetworkString("AdvDupe2_SendGhosts")
util.AddNetworkString("AdvDupe2_AddGhost")
util.AddNetworkString("AdvDupe2_CanAutoSave")
util.AddNetworkString("AdvDupe2_SendContraptionGhost")

	
hook.Add("Initialize", "AdvDupe2_CheckServerSettings",
	function()
		if(GetConVarString("AdvDupe2_LoadMap")~="0")then
			hook.Add("InitPostEntity", "AdvDupe2_PasteMap", PasteMap)
		end
	
		AdvDupe2.SpawnRate = tonumber(GetConVarString("AdvDupe2_SpawnRate"))
		if(not AdvDupe2.SpawnRate or AdvDupe2.SpawnRate<=0 or AdvDupe2.SpawnRate>1)then
			AdvDupe2.SpawnRate = 1
			print("[AdvDupe2Notify]\tINVALID SPAWN RATE DEFAULTING VALUE")
		end
	end)
