--[[
	Title: Adv. Dupe 2 Filing Clerk (Clientside)
	
	Desc: Reads/writes AdvDupe2 files.
	
	Author: AD2 Team
	
	Version: 1.0
]]

--[[
	Name:	WriteAdvDupe2File
	Desc:	Writes a dupe file to the dupe folder.
	Params:	<string> dupe, <string> name
	Return:	<boolean> success/<string> path
]]
function AdvDupe2.WriteFile(name, dupe)

	name = name:lower()
	
	if name:find("[<>:\\\"|%?%*%.]") then return false end
	
	name = name:gsub("//","/")
	
	local path = string.format("%q/%q", self.DataFolder, name)
	
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
function AdvDupe2.ReadFile(name, dirOverride)
	
	--infinitely simpler than WriteAdvDupe2 :3
	local buff = file.Open(string.format("%q/%q.txt", dirOverride or AdvDupe2.DataFolder, name), "rb", "DATA")
	local read = buff:Read(buff:Size())
	buff:Close()
	return read
	
end