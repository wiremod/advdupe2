--[[
	Title: Adv. Dupe 2 Networking (Clientside)
	
	Desc: Handles file transfers and all that jazz.
	
	Author: TB
	
	Version: 1.0
]]

include "nullesc.lua"

AdvDupe2.NetFile = ""

local function CheckFileNameCl(path)
	if file.Exists(path) then
		path = string.sub(path, 1, #path-4)
		for i = 1, AdvDupe2.FileRenameTryLimit do
			if not file.Exists(path.."_"..i..".txt") then
				return path.."_"..i..".txt"
			end
		end
	end

	return path
end

--[[
	Name: AdvDupe2_RecieveFile
	Desc: Recieve file data from the server when downloading to the client
	Params: usermessage
	Returns:
]]
local function AdvDupe2_RecieveFile(um)
	local status = um:ReadShort()

	if(status==1)then AdvDupe2.NetFile = "" end
	AdvDupe2.NetFile=AdvDupe2.NetFile..um:ReadString()

	if(status==2)then
		local path = CheckFileNameCl(AdvDupe2.SavePath)

		file.Write(path, AdvDupe2.Null.invesc(AdvDupe2.NetFile))
		
		local filename = string.Explode("/", path)
		filename = string.sub(filename[#filename], 1, -5)

		AdvDupe2.FileBrowser:AddFileToClient(filename, AdvDupe2.SaveNode, true)
		AdvDupe2.NetFile = ""
		AdvDupe2.Notify("File successfully downloaded!",NOTIFY_GENERIC,5)
		return
	end

end
usermessage.Hook("AdvDupe2_RecieveFile", AdvDupe2_RecieveFile)

function AdvDupe2.RemoveProgressBar()
	if !AdvDupe2 then AdvDupe2={} end
	AdvDupe2.ProgressBar = {}
end

local escseqnl = { "nwl", "newl", "nwli", "nline" }
local escseqquo = { "quo", "qte", "qwo", "quote" }
--[[
	Name: InitializeUpload
	Desc: When the client clicks upload, prepares to send data to the server
	Params: File Data, Path to save
	Returns:
]]			
function AdvDupe2.InitializeUpload(ReadPath, ReadArea, SavePath, SaveArea, ParentID)
	if(ReadArea==0)then
		ReadPath = AdvDupe2.DataFolder.."/"..ReadPath..".txt"
	elseif(ReadArea==1)then
		ReadPath = AdvDupe2.DataFolder.."/=Public=/"..ReadPath..".txt"
	else
		ReadPath = "adv_duplicator/"..ReadPath..".txt"
	end
	
	if(!file.Exists(ReadPath))then return end
	local nwl 
	local quo 
	local data = AdvDupe2.Null.esc(file.Read(ReadPath))
					
	for k = 1, #escseqnl do		
		if(string.find(data, escseqnl[k]))then continue end
		nwl = escseqnl[k]
		data = string.gsub(data, "\10", escseqnl[k])
		break
	end
		
	for k = 1, #escseqquo do
		if(string.find(data, escseqquo[k]))then continue end
		quo = escseqquo[k]
		data = string.gsub(data, [["]], escseqquo[k])
		break
	end
		
	AdvDupe2.File = data
	AdvDupe2.LastPos = 0
	AdvDupe2.Length = string.len(data)
	AdvDupe2.InitProgressBar("Uploading:")

	RunConsoleCommand("AdvDupe2_InitRecieveFile", SavePath, SaveArea, nwl, quo, ParentID)
end

function AdvDupe2.UpdateProgressBar(percent)
	AdvDupe2.ProgressBar.Percent = percent
end

--[[
	Name: SendFileToServer
	Desc: Send chunks of the file data to the server
	Params: end of file
	Returns:
]]
local function SendFileToServer(eof, chunks)
	
	for i=1,chunks do
		if(AdvDupe2.LastPos+eof>AdvDupe2.Length)then
			eof = AdvDupe2.Length
		end
		
		local data = string.sub(AdvDupe2.File, AdvDupe2.LastPos, AdvDupe2.LastPos+eof)
		AdvDupe2.LastPos = AdvDupe2.LastPos+eof+1
		AdvDupe2.UpdateProgressBar(math.floor((AdvDupe2.LastPos/AdvDupe2.Length)*100))
		local status = 0
		if(AdvDupe2.LastPos>=AdvDupe2.Length)then
			status=1
			AdvDupe2.RemoveProgressBar()
			RunConsoleCommand("AdvDupe2_RecieveFile", status, data)
			break
		end
		RunConsoleCommand("AdvDupe2_RecieveFile", status, data)
	end
end

usermessage.Hook("AdvDupe2_RecieveNextStep",function(um)
	SendFileToServer(um:ReadShort(), um:ReadShort())
end)

usermessage.Hook("AdvDupe2_UploadRejected",function(um)
	AdvDupe2.File = nil
	AdvDupe2.LastPos = nil
	AdvDupe2.Length = nil
	if(um:ReadBool())then AdvDupe2.RemoveProgressBar() end
end)