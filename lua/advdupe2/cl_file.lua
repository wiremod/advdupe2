local function AdvDupe2_ReceiveFile(len, ply)
	local AutoSave = net.ReadUInt(8) == 1

	net.ReadStream(nil, function(data)
		AdvDupe2.RemoveProgressBar()
		if(!data)then
			AdvDupe2.Notify("File was not saved!",NOTIFY_ERROR,5)
			return
		end
		local path
		if AutoSave then
			if(LocalPlayer():GetInfo("advdupe2_auto_save_overwrite")~="0")then
				path = AdvDupe2.GetFilename(AdvDupe2.AutoSavePath, true)
			else
				path = AdvDupe2.GetFilename(AdvDupe2.AutoSavePath)
			end
		else
			path = AdvDupe2.GetFilename(AdvDupe2.SavePath)
		end

		local dupefile = file.Open(path, "wb", "DATA")
		if(!dupefile)then
			AdvDupe2.Notify("File was not saved!",NOTIFY_ERROR,5)
			return
		end
		dupefile:Write(data)
		dupefile:Close()
		
		local errored = false
		if(LocalPlayer():GetInfo("advdupe2_debug_openfile")=="1")then
			if(not file.Exists(path, "DATA"))then AdvDupe2.Notify("File does not exist", NOTIFY_ERROR) return end
			
			local readFile = file.Open(path, "rb", "DATA")
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
		
		local filename = string.StripExtension(string.GetFileFromFilename( path ))
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
		
		AdvDupe2.LoadGhosts(dupe, info, moreinfo, name)
	else
		AdvDupe2.Notify("File could not be decoded. ("..dupe..") Upload Canceled.", NOTIFY_ERROR)
	end
end
