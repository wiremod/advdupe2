AdvDupe2 = {
	Version = "1.0.4",
	Revision = 28
}

AdvDupe2.DataFolder = "advdupe2" --name of the folder in data where dupes will be saved

AdvDupe2.FileRenameTryLimit = 256

include "advdupe2/sv_clipboard.lua"
include "advdupe2/sv_codec.lua"
include "advdupe2/sv_file.lua"
include "advdupe2/sv_networking.lua"
include "advdupe2/sv_misc.lua"

AddCSLuaFile "autorun/client/advdupe2_cl_init.lua"
AddCSLuaFile "advdupe2/cl_browser.lua"
AddCSLuaFile "advdupe2/cl_networking.lua"
AddCSLuaFile "advdupe2/cl_file.lua"

resource.AddFile("materials/gui/ad2logo.tga")
resource.AddFile("materials/gui/silkicons/help.vtf")
resource.AddFile("materials/gui/silkicons/help.vmt")

function AdvDupe2.Notify(ply,msg,typ,dur)
	umsg.Start("AdvDupe2Notify",ply)
		umsg.String(msg)
		umsg.Char(typ or NOTIFY_GENERIC)
		umsg.Char(dur or 5)
	umsg.End()
	print("[AdvDupe2Notify]",msg)
end

local function RemovePlayersFiles(ply)

	if(SinglePlayer() || !tobool(GetConVarString("AdvDupe2_RemoveFilesOnDisconnect")))then return end

	local function TFind(Search, Folders, Files)
		Search = string.sub(Search, 6, -2)
		for k,v in pairs(Files)do
			file.Delete(Search..v)
		end
		
		for k,v in pairs(Folders)do
			file.TFind("Data/"..Search..v.."/*", TFind)
		end
	end
	file.TFind("Data/"..ply:GetAdvDupe2Folder().."/*", TFind)
end

CreateConVar("AdvDupe2_MaxFileSize", "200", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxEntities", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxConstraints", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowUploading", "true", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowDownloading", "true", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowPublicFolder", "true", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_MaxContraptionEntities", "10", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxContraptionConstraints", "15", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_MaxAreaCopySize", "2500", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_RemoveFilesOnDisconnect", "false", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_FileModificationDelay", "5", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_UpdateFilesDelay", "10", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_AllowNPCPasting", "false", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_MaxDownloadBytes", "200", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxUploadBytes", "180", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_ServerSendRate", "0.15", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_ClientSendRate", "0.15", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_ServerDataChunks", "4", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_ClientDataChunks", "4", {FCVAR_ARCHIVE})

cvars.AddChangeCallback("AdvDupe2_RemoveFilesOnDisconnect",
	function(cvar, preval, newval)
		if(tobool(newval))then
			hook.Add("PlayerDisconnected", "AdvDupe2_RemovePlayersFiles", RemovePlayersFiles)
		else
			hook.Remove("PlayerDisconnected", "AdvDupe2_RemovePlayersFiles")
		end
	end)
hook.Add("Initialize", "AdvDupe2_CheckServerSettings",
	function()
		if(tobool(GetConVarString("AdvDupe2_RemoveFilesOnDisconnect")))then
			hook.Add("PlayerDisconnected", "AdvDupe2_RemovePlayersFiles", RemovePlayersFiles)
		end
	end)
