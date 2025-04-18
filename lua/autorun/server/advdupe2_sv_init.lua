AdvDupe2 = {
	Version = "1.1.0",
	Revision = 51
}

AdvDupe2.DataFolder = "advdupe2" --name of the folder in data where dupes will be saved

function AdvDupe2.Notify(ply,msg,typ, showsvr, dur)
	net.Start("AdvDupe2Notify")
		net.WriteString(msg)
		net.WriteUInt(typ or 0, 8)
		net.WriteFloat(dur or 5)
	net.Send(ply)

	if(showsvr==true)then
		print("[AdvDupe2Notify]\t"..ply:Nick()..": "..msg)
	end
end

AddCSLuaFile( "autorun/client/advdupe2_cl_init.lua" )
AddCSLuaFile( "advdupe2/file_browser.lua" )
AddCSLuaFile( "advdupe2/sh_codec.lua" )
AddCSLuaFile( "advdupe2/cl_file.lua" )
AddCSLuaFile( "advdupe2/cl_ghost.lua" )

util.AddNetworkString("AdvDupe2_ReportClass")
util.AddNetworkString("AdvDupe2_ReportModel")
util.AddNetworkString("AdvDupe2Notify")
util.AddNetworkString("AdvDupe2_RemoveGhosts")
util.AddNetworkString("AdvDupe2_ResetDupeInfo")
util.AddNetworkString("AdvDupe2_StartGhosting")
util.AddNetworkString("AdvDupe2_InitProgressBar")
util.AddNetworkString("AdvDupe2_DrawSelectBox")
util.AddNetworkString("AdvDupe2_RemoveSelectBox")
util.AddNetworkString("AdvDupe2_UpdateProgressBar")
util.AddNetworkString("AdvDupe2_RemoveProgressBar")
util.AddNetworkString("AdvDupe2_ResetOffsets")
util.AddNetworkString("AdvDupe2_SetDupeInfo")
util.AddNetworkString("AdvDupe2_ReceiveFile")
util.AddNetworkString("AdvDupe2_CanAutoSave")

CreateConVar("AdvDupe2_DebugInfo", "0", {FCVAR_ARCHIVE}, "Should extra info be printed to console?", 0, 1)
CreateConVar("AdvDupe2_SpawnRate", "1", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxFileSize", "200", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxEntities", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxConstraints", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_Strict", "1", {FCVAR_ARCHIVE}, "Prevents entities from being duped with unauthorized data. Can fix certain exploits at the cost of some entities potentially duping incorrectly")

CreateConVar("AdvDupe2_MaxContraptionEntities", "10", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxContraptionConstraints", "15", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MinContraptionSpawnDelay", "0.2", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MinContraptionUndoDelay", "0.1", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MaxContraptionUndoDelay", "60", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_FileModificationDelay", "5", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_UpdateFilesDelay", "10", {FCVAR_ARCHIVE})

CreateConVar("AdvDupe2_LoadMap", "0", {FCVAR_ARCHIVE})
CreateConVar("AdvDupe2_MapFileName", "", {FCVAR_ARCHIVE})

local function PasteMap()
	if(GetConVarString("AdvDupe2_LoadMap")=="0")then return end
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
	local success,dupe,info,moreinfo = AdvDupe2.Decode(map)
	if not success then
		print("[AdvDupe2Notify]\tCould not open map save "..dupe)
		return
	end

	local Tab = {Entities=dupe["Entities"], Constraints=dupe["Constraints"], HeadEnt=dupe["HeadEnt"]}
	local Entities = AdvDupe2.duplicator.Paste(nil, table.Copy(Tab.Entities), Tab.Constraints, nil, nil, Tab.HeadEnt.Pos, true)
	local maptype = GetConVarString("AdvDupe2_LoadMap")

	if(maptype=="1")then
		local PhysObj
		for k,v in pairs(Entities) do
			if(IsValid(v))then
				for i=0, #Tab.Entities[k].PhysicsObjects do
					if(Tab.Entities[k].PhysicsObjects[i].Frozen)then
						PhysObj = v:GetPhysicsObjectNum( i )
						if IsValid(PhysObj) then
							PhysObj:EnableMotion(true)
						end
					end
				end
				if v.CPPISetOwner then v:CPPISetOwner(game.GetWorld()) end
			end
		end
	elseif(maptype=="2")then
		local PhysObj
		for k,v in pairs(Entities) do
			if(IsValid(v))then
				for i=0, #Tab.Entities[k].PhysicsObjects do
					PhysObj = v:GetPhysicsObjectNum( i )
					if IsValid(PhysObj) then
						PhysObj:EnableMotion(true)
					end
				end
				if v.CPPISetOwner then v:CPPISetOwner(game.GetWorld()) end
			end
		end
	end

	print("[AdvDupe2Notify]\tMap save pasted.")
end
hook.Add("InitPostEntity", "AdvDupe2_PasteMap", PasteMap)
hook.Add("PostCleanupMap", "AdvDupe2_PasteMap", PasteMap)
hook.Add("PlayerInitialSpawn","AdvDupe2_AddPlayerTable",function(ply)
	ply.AdvDupe2 = {}
end)

include( "advdupe2/sv_clipboard.lua" )
include( "advdupe2/sh_codec.lua" )
include( "advdupe2/sv_misc.lua" )
include( "advdupe2/sv_file.lua" )
include( "advdupe2/sv_ghost.lua" )
