local function CheckFileNameCl(path)
	if file.Exists(path..".txt", "DATA") then
		for i = 1, AdvDupe2.FileRenameTryLimit do
			if not file.Exists(path.."_"..i..".txt", "DATA") then
				return path.."_"..i
			end
		end
	end
	return path
end

--[[
	Name: AdvDupe2_ReceiveFile
	Desc: Receive file data from the server when downloading to the client
	Params: 
	Returns:
]]
local function AdvDupe2_ReceiveFile(len, ply)
	local Autosave = net.ReadInt(8) == 1

	AdvDupe2.Stream = net.ReadStream(nil, function(data)
		AdvDupe2.Stream = nil
		AdvDupe2.RemoveProgressBar()
		if(!data)then
			AdvDupe2.Notify("File was not saved!",NOTIFY_ERROR,5)
			return
		end
		local path = ""
		if(AutoSave)then
			if(LocalPlayer():GetInfo("advdupe2_auto_save_overwrite")~="1")then
				path = CheckFileNameCl(AdvDupe2.AutoSavePath)
			end
		else
			path = CheckFileNameCl(AdvDupe2.SavePath)
		end

		local dupefile = file.Open(path..".txt", "wb", "DATA")
		if(!dupefile)then
			AdvDupe2.Notify("File was not saved!",NOTIFY_ERROR,5)
			return
		end
		dupefile:Write(data)
		dupefile:Close()
		
		local errored = false
		if(LocalPlayer():GetInfo("advdupe2_debug_openfile")=="1")then
			if(not file.Exists(path..".txt", "DATA"))then AdvDupe2.Notify("File does not exist", NOTIFY_ERROR) return end
			
			local readFile = file.Open(path..".txt", "rb", "DATA")
			if not readFile then AdvDupe2.Notify("File could not be read", NOTIFY_ERROR) return end
			local readData = readFile:Read(readFile:Size())
			readFile:Close()
			local success,dupe,info,moreinfo = AdvDupe2.Decode(readData)
			if(success)then
				AdvDupe2.Notify("DEBUG CHECK: File successfully opens. No EOF errors.")
			else
				AdvDupe2.Notify("DEBUG CHECK: " .. dupe, NOTIFY_ERROR)
				errored = true
			end
		end
		
		local filename = string.Explode("/", path)
		filename = filename[#filename]
		if(AutoSave)then
			if(IsValid(AdvDupe2.FileBrowser.AutoSaveNode))then
				local add = true
				for i=1, #AdvDupe2.FileBrowser.AutoSaveNode.Files do
					if(filename==AdvDupe2.FileBrowser.AutoSaveNode.Files[i].Label:GetText())then
						add=false
						break
					end
				end
				if(add)then
					AdvDupe2.FileBrowser.AutoSaveNode:AddFile(filename)
					AdvDupe2.FileBrowser.Browser.pnlCanvas:Sort(AdvDupe2.FileBrowser.AutoSaveNode)
				end
			end
		else
			AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode:AddFile(filename)
			AdvDupe2.FileBrowser.Browser.pnlCanvas:Sort(AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode)
		end
		if(!errored)then
			AdvDupe2.Notify("File successfully saved!",NOTIFY_GENERIC, 5)
		end
	end)
end
net.Receive("AdvDupe2_ReceiveFile", AdvDupe2_ReceiveFile)

function AdvDupe2.LoadGhosts(dupe, info, moreinfo, name, preview)

	AdvDupe2.RemoveGhosts()
	AdvDupe2.Ghosting = true
	
	AdvDupe2.GhostToSpawn = {}
	local count = 0
	
	local time
	local desc
	local date
	local creator
	
	if(info.ad1)then
		time = moreinfo["Time"] or ""
		desc = info["Description"] or ""
		date = info["Date"] or ""
		creator = info["Creator"] or ""

		AdvDupe2.HeadEnt = tonumber(moreinfo.Head)
		local spx,spy,spz = moreinfo.StartPos:match("^(.-),(.-),(.+)$")
		AdvDupe2.HeadPos = Vector(tonumber(spx) or 0, tonumber(spy) or 0, tonumber(spz) or 0)
		local z = (tonumber(moreinfo.HoldPos:match("^.-,.-,(.+)$")) or 0)*-1
		AdvDupe2.HeadZPos = z
		AdvDupe2.HeadPos.Z = AdvDupe2.HeadPos.Z + z

		local Pos
		local Ang
		for k,v in pairs(dupe["Entities"])do
			
			if(v.SavedParentIdx)then 
				if(not v.BuildDupeInfo)then v.BuildDupeInfo = {} end
				v.BuildDupeInfo.DupeParentID = v.SavedParentIdx
				Pos = v.LocalPos*1
				Ang = v.LocalAngle*1
			else
				Pos = nil
				Ang = nil
			end
			for i,p in pairs(v.PhysicsObjects)do
				p.Pos = Pos or (p.LocalPos*1)
				p.Pos.Z = p.Pos.Z - z
				p.Angle = Ang or (p.LocalAngle*1)
				p.LocalPos = nil
				p.LocalAngle = nil
			end
			v.LocalPos = nil
			v.LocalAngle = nil
			AdvDupe2.GhostToSpawn[count] = {Model=v.Model, PhysicsObjects=v.PhysicsObjects}
			if(AdvDupe2.HeadEnt == k)then
				AdvDupe2.HeadEnt = count
			end
			count = count + 1
		end
		
		AdvDupe2.HeadOffset = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Pos
		AdvDupe2.HeadAngle = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Angle
	
	else
		time = info["time"]
		desc = dupe["Description"]
		date = info["date"]
		creator = info["name"]

		AdvDupe2.HeadEnt = dupe["HeadEnt"].Index
		AdvDupe2.HeadZPos = dupe["HeadEnt"].Z
		AdvDupe2.HeadPos = dupe["HeadEnt"].Pos
		AdvDupe2.HeadOffset = dupe["Entities"][AdvDupe2.HeadEnt].PhysicsObjects[0].Pos
		AdvDupe2.HeadAngle = dupe["Entities"][AdvDupe2.HeadEnt].PhysicsObjects[0].Angle
		
		for k,v in pairs(dupe["Entities"])do
			AdvDupe2.GhostToSpawn[count] = {Model=v.Model, PhysicsObjects=v.PhysicsObjects}
			if(AdvDupe2.HeadEnt == k)then
				AdvDupe2.HeadEnt = count
			end
			count = count + 1
		end
	end
	
	if(not preview)then
		AdvDupe2.Info.File:SetText("File: "..name)
		AdvDupe2.Info.Creator:SetText("Creator: "..creator)
		AdvDupe2.Info.Date:SetText("Date: "..date)
		AdvDupe2.Info.Time:SetText("Time: "..time)
		AdvDupe2.Info.Size:SetText("Size: "..string.NiceSize(tonumber(info.size) or 0))
		AdvDupe2.Info.Desc:SetText("Desc: "..(desc or ""))
		AdvDupe2.Info.Entities:SetText("Entities: "..table.Count(dupe["Entities"]))
		AdvDupe2.Info.Constraints:SetText("Constraints: "..table.Count(dupe["Constraints"]))
	end
	
	AdvDupe2.StartGhosting()
	AdvDupe2.Preview = preview

end


local uploading = nil
function AdvDupe2.UploadFile(ReadPath, ReadArea)
	if uploading then AdvDupe2.Notify("Already opening file, please wait.", NOTIFY_ERROR) return end
	if(ReadArea==0)then
		ReadPath = AdvDupe2.DataFolder.."/"..ReadPath..".txt"
	elseif(ReadArea==1)then
		ReadPath = AdvDupe2.DataFolder.."/-Public-/"..ReadPath..".txt"
	else
		ReadPath = "adv_duplicator/"..ReadPath..".txt"
	end
	
	if(not file.Exists(ReadPath, "DATA"))then AdvDupe2.Notify("File does not exist", NOTIFY_ERROR) return end
	
	local read = file.Read(ReadPath)
	if not read then AdvDupe2.Notify("File could not be read", NOTIFY_ERROR) return end
	local name = string.Explode("/", ReadPath)
	name = name[#name]
	name = string.sub(name, 1, #name-4)
	
	local success, dupe, info, moreinfo = AdvDupe2.Decode(read)
	if(success)then
		net.Start("AdvDupe2_ReceiveFile")
		net.WriteString(name)
		uploading = net.WriteStream(read, function()
			uploading = nil
			AdvDupe2.File = nil
			AdvDupe2.RemoveProgressBar()
		end)
		net.SendToServer()
	else
		AdvDupe2.Notify("File could not be decoded. ("..dupe..") Upload Canceled.", NOTIFY_ERROR)
	end
end
