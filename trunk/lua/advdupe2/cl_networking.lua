--[[
	Title: Adv. Dupe 2 Networking (Clientside)
	
	Desc: Handles file transfers and all that jazz.
	
	Author: TB
	
	Version: 1.0
]]

include "nullesc.lua"

AdvDupe2.NetFile = ""
local AutoSave = false
local uploading = false

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
local function AdvDupe2_ReceiveFile(len, ply, len2)
	local status = net.ReadInt(8)
	
	if(status==1)then AdvDupe2.NetFile = "" end
	AdvDupe2.NetFile=AdvDupe2.NetFile..net.ReadString()

	if(status==2)then
		local path = AdvDupe2.AutoSavePath
		if(AutoSave)then
			if(LocalPlayer():GetInfo("advdupe2_auto_save_overwrite")~="1")then
				path = CheckFileNameCl(AdvDupe2.AutoSavePath)
			end
		else
			path = CheckFileNameCl(AdvDupe2.SavePath)
		end
		file.Write(path..".txt", AdvDupe2.Null.invesc(AdvDupe2.NetFile))
		
		if(!file.Exists(path..".txt", "DATA"))then
			AdvDupe2.NetFile = ""
			AdvDupe2.Notify("File was not saved! Unknown cause, alert TB that your size was "..#AdvDupe2.NetFile,NOTIFY_ERROR,5)
			return
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
		AdvDupe2.NetFile = ""
		AdvDupe2.Notify("File successfully saved!",NOTIFY_GENERIC,5)
		return
	end

end
net.Receive("AdvDupe2_ReceiveFile", AdvDupe2_ReceiveFile)

--[[
	Name: InitializeUpload
	Desc: When the client clicks upload, prepares to send data to the server
	Params: File Data, Path to save
	Returns:
]]			
function AdvDupe2.InitializeUpload(ReadPath, ReadArea)
	if(uploading)then AdvDupe2.Notify("Already opening file, please wait.", NOTIFY_ERROR) return end
	if(ReadArea==0)then
		ReadPath = AdvDupe2.DataFolder.."/"..ReadPath..".txt"
	elseif(ReadArea==1)then
		ReadPath = AdvDupe2.DataFolder.."/-Public-/"..ReadPath..".txt"
	else
		ReadPath = "adv_duplicator/"..ReadPath..".txt"
	end
	
	if(not file.Exists(ReadPath, "DATA"))then AdvDupe2.Notify("File does not exist", NOTIFY_ERROR) return end
	
	AdvDupe2.File = AdvDupe2.Null.esc(file.Read(ReadPath))
	AdvDupe2.LastPos = 0
	AdvDupe2.Length = string.len(AdvDupe2.File)
	AdvDupe2.InitProgressBar("Opening:")
	
	local name = string.Explode("/", ReadPath)
	name = name[#name]
	name = string.sub(name, 1, #name-4)

	uploading=true
	RunConsoleCommand("AdvDupe2_InitReceiveFile", name)
end

--[[
	Name: SendFileToServer
	Desc: Send chunks of the file data to the server
	Params: end of file
	Returns:
]]
local function SendFileToServer(eof)

	if(AdvDupe2.LastPos+eof>AdvDupe2.Length)then
		eof = AdvDupe2.Length
	end

	local data = string.sub(AdvDupe2.File, AdvDupe2.LastPos, AdvDupe2.LastPos+eof)

	AdvDupe2.LastPos = AdvDupe2.LastPos+eof+1
	AdvDupe2.ProgressBar.Percent = math.floor((AdvDupe2.LastPos/AdvDupe2.Length)*100)
	local status = false
	if(AdvDupe2.LastPos>=AdvDupe2.Length)then
		status=true
		uploading = false
		AdvDupe2.RemoveProgressBar()
	end

	net.Start("AdvDupe2_ReceiveFile")
		net.WriteBit(status)
		net.WriteString(data)
	net.SendToServer()
	
end

usermessage.Hook("AdvDupe2_ReceiveNextStep",function(um)
	SendFileToServer(um:ReadShort())
end)

usermessage.Hook("AdvDupe2_UploadRejected",function(um)
	if(uploading)then return end
	AdvDupe2.File = nil
	AdvDupe2.LastPos = nil
	AdvDupe2.Length = nil
	if(um:ReadBool())then AdvDupe2.RemoveProgressBar() end
end)

concommand.Add("AdvDupe2_SaveType", function(ply, cmd, args)
	AutoSave = args[1]=="1"
end)