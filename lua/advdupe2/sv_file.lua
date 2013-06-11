--[[
	Title: Adv. Dupe 2 Filing Clerk (Serverside)
	
	Desc: Reads/writes AdvDupe2 files.
	
	Author: AD2 Team
	
	Version: 1.0
]]

file.CreateDir("advdupe2")
local PlayerMeta = FindMetaTable("Player")

function PlayerMeta:SteamIDSafe()
	return self:SteamID():gsub(":","_")
end

--[[
	Name:	WriteAdvDupe2File
	Desc:	Writes a dupe file to the dupe folder.
	Params:	<string> dupe, <string> name
	Return:	<boolean> success/<string> path
]]
function AdvDupe2.WriteFile(ply, name, dupe)

	name = name:lower()
	
	if name:find("[<>:\\\"|%?%*%.]") then return false end
	
	name = name:gsub("//","/")
	
	local path
	if game.SinglePlayer() then
		path = string.format("%s/%s", AdvDupe2.DataFolder, name)
	else
		path = string.format("%s/%s/%s", AdvDupe2.DataFolder, ply and ply:SteamIDSafe() or "=Public=", name)
	end
	
	--if a file with this name already exists, we have to come up with a different name
	if file.Exists(path..".txt", "DATA") then
		for i = 1, AdvDupe2.FileRenameTryLimit do
			--check if theres already a file with the name we came up with, and retry if there is
			--otherwise, we can exit the loop and write the file
			if not file.Exists(path.."_"..i..".txt", "DATA") then
				path = path.."_"..i
				break
			end
		end
		--if we still can't find a unique name we give up
		if file.Exists(path..".txt", "DATA") then return false end
	end
	
	--write the file
	file.Write(path..".txt", dupe)
	
	--returns if the write was successful and the name the path ended up being saved under
	return path..".txt", path:match("[^/]-$")
	
end

--[[
	Name:	ReadAdvDupe2File
	Desc:	Reads a dupe file from the dupe folder.
	Params:	<string> name
	Return:	<string> contents
]]
function AdvDupe2.ReadFile(ply, name, dirOverride)
	if game.SinglePlayer() then
		local path = string.format("%s/%s.txt", dirOverride or AdvDupe2.DataFolder, name)
		if(!file.Exists(path, "DATA"))then
			if(ply)then AdvDupe2.Notify(ply, "File does not exist!", NOTIFY_ERROR) end
			return nil
		else
			return file.Read(path)
		end
	else
		local path = string.format("%s/%s/%s.txt", dirOverride or AdvDupe2.DataFolder, ply and ply:SteamIDSafe() or "=Public=", name)
		if(!file.Exists(path, "DATA"))then
			if(ply)then AdvDupe2.Notify(ply, "File does not exist!", NOTIFY_ERROR) end
			return nil
		elseif(file.Size(path, "DATA")/1024>tonumber(GetConVarString("AdvDupe2_MaxFileSize")))then
			if(ply)then AdvDupe2.Notify(ply,"File size is greater than "..GetConVarString("AdvDupe2_MaxFileSize"), NOTIFY_ERROR) end
			return false
		else
			return file.Read(path)
		end
	end
	
end

function PlayerMeta:WriteAdvDupe2File(name, dupe)
	return AdvDupe2.WriteFile(self, name, dupe)
end

function PlayerMeta:ReadAdvDupe2File(name)
	return AdvDupe2.ReadFile(self, name)
end

function PlayerMeta:GetAdvDupe2Folder()
	if game.SinglePlayer() then
		return AdvDupe2.DataFolder
	else
		return string.format("%s/%s", AdvDupe2.DataFolder, self:SteamIDSafe())
	end
end
