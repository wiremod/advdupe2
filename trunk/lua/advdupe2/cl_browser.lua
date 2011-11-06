--[[
	Title: Adv. Dupe 2 File Browser
	
	Desc: Displays and interfaces with duplication files.
	
	Author: TB
	
	Version: 1.0
]]

local PANEL = {}
local ClientFolderCount = 1

function PANEL:PopulateUpload(Search, Folders, Files, parent)
	//Search = string.Left(Search,#Search-1)
	local NodeP
	if(parent==0)then
		NodeP = self.Upload
	else
		NodeP = self.CNodes[parent]
	end
	
	local Folder
	for k,v in pairs(Folders)do
		Folder = NodeP:AddNode(v)
		self.CNodes[ClientFolderCount] = Folder
		Folder.IsFile = false
		Folder.Name = v
		Folder.SortName = "A"..string.lower(v)
		Folder.ID = ClientFolderCount
		//table.insert(FolderSearch, {ID=Folder.ID, Name=v})
		ClientFolderCount = ClientFolderCount + 1
		for k,v in pairs(file.Find(Search..v.."/*.txt"))do
			name = string.sub(v, 1, -5)
			File = Folder:AddNode(name)
			File.IsFile = true
			File.Name = name
			File.SortName = "B"..string.lower(name)
			File.Icon:SetImage("vgui/spawnmenu/file")
		end
		self:PopulateUpload(Search..v.."/", file.FindDir(Search..v.."/*"), nil, Folder.ID)
		//file.TFind(Search..v.."/*", function(Search2, Folders2, Files2) self:PopulateUpload(Search2, Folders2, Files2, Folder.ID) end)
	end
	
	/*local name = ""
	local File
	for k,v in pairs(Files)do
		name = string.sub(v, 1, -5)
		File = NodeP:AddNode(name)
		File.IsFile = true
		File.Name = name
		File.SortName = "B"..string.lower(name)
		File.Icon:SetImage("vgui/spawnmenu/file")
	end

	for k,v in pairs(FolderSearch)do
		file.TFind(Search..v.Name.."/*", function(Search2, Folders2, Files2) self:PopulateUpload(Search2, Folders2, Files2, v.ID) end)
	end*/
	
end

function PANEL:UpdateClientFiles()
	ClientFolderCount = 2
	local Folder = self.Upload:AddNode("=Adv Duplicator=")
	self.CNodes[1] = Folder
	Folder.IsFile = false
	Folder.Name = "=Adv Duplicator="
	Folder.SortName = "A=adv duplicator="
	Folder.ID = 1

	self:PopulateUpload("adv_duplicator/", file.FindDir("adv_duplicator/*"), nil, 1)
	local name = ""
	local File
	for k,v in pairs(file.Find("adv_duplicator/*.txt"))do
		name = string.sub(v, 1, -5)
		File = Folder:AddNode(name)
		File.IsFile = true
		File.Name = name
		File.SortName = "B"..string.lower(name)
		File.Icon:SetImage("vgui/spawnmenu/file")
	end
	self:PopulateUpload(AdvDupe2.DataFolder.."/", file.FindDir(AdvDupe2.DataFolder.."/*"), nil, 0)
	for k,v in pairs(file.Find(AdvDupe2.DataFolder.."/*.txt"))do
		name = string.sub(v, 1, -5)
		File = self.Upload:AddNode(name)
		File.IsFile = true
		File.Name = name
		File.SortName = "B"..string.lower(name)
		File.Icon:SetImage("vgui/spawnmenu/file")
	end

	//file.TFind("Data/adv_duplicator/*", function(Search, Folders, Files) self:PopulateUpload(Search, Folders, Files, 1) end)
	//file.TFind("Data/"..AdvDupe2.DataFolder.."/*", function(Search, Folders, Files) self:PopulateUpload(Search, Folders, Files, 0) end)

	self.Upload.Populated = true
end

local function SortChildren(NodeP)
	if(NodeP.ChildNodes)then
		NodeP.ChildNodes:SortByMember("SortName")
		NodeP:SetExpanded(false, true)
		NodeP:SetExpanded(true, true)
	else
		NodeP:SortByMember("SortName")
		NodeP:InvalidateLayout()
	end
end

local function GetNodeRoot(Node)

	local ReturnNode = false
	local function PurgeNodes( PNode )
		if(PNode.Name == nil)then return end
		ReturnNode = PNode
		PurgeNodes(PNode:GetParentNode())
	end
	PurgeNodes(Node:GetParentNode())
	
	return ReturnNode
end

local function GetNodePath( Node )
	local path = Node.Name
	
	local function PurgeNodes( PNode )
		if(PNode.Name == nil)then return end
		path = PNode.Name.."/"..path
		PurgeNodes(PNode:GetParentNode())
	end
	
	PurgeNodes(Node:GetParentNode())
	
	return path
end

local function ParsePath(path)
	local area = 0
	local Alt = string.Explode("/", path)[1]
	if(Alt=="=Adv Duplicator=")then
		path = string.sub(path, 18)
		area = 2
	elseif(Alt=="=Public=")then
		path = string.sub(path, 10)
		area = 1
	end

	return path, area
end

local function CheckFileNameCl(path)

	if file.Exists(path..".txt") then
		for i = 1, AdvDupe2.FileRenameTryLimit do
			if not file.Exists(path.."_"..i..".txt") then
				return path.."_"..i..".txt"
			end
		end
		return false
	end

	return path..".txt"
end

function PANEL:FolderSelect(func, name, path, ArgNode)

	local txt = ""
	local todo
	local Frame
	local Fldbrw
	local Tree
	local AltTree = nil
	local path, area = ParsePath(GetNodePath(ArgNode))
	
	if(func==1)then
		txt = "Select the folder you want to save the Upload to."
		Tree = self.Tree
		todo = 	function() 
					local area2 = 0
					if(area==2)then area2=2 end
					if(!Fldbrw:GetSelectedItem())then 
						AdvDupe2.InitializeUpload(path, area, name, area2, 0) 
						Frame:Remove() 
						return 
					end  
					AdvDupe2.InitializeUpload(path, area, GetNodePath(Fldbrw:GetSelectedItem()).."/"..name, area2, Fldbrw:GetSelectedItem().ID) 
					Frame:Remove() 
				end
	elseif(func==2)then
		txt = "Select the folder you want to save the Download to."
		if(!self.Upload.Populated)then self:UpdateClientFiles() end
		Tree = self.Upload
		local Root = GetNodeRoot(ArgNode)
		todo = 	function() 
					if(!Fldbrw:GetSelectedItem())then
						
						if(area==0 || area==1)then
							AdvDupe2.SavePath = AdvDupe2.DataFolder.."/"..name..".txt" 
							AdvDupe2.SaveNode = 0
						elseif(area==2)then
							AdvDupe2.SavePath = "adv_duplicator/"..name..".txt" 
							AdvDupe2.SaveNode = Root.ID
						end
						RunConsoleCommand("AdvDupe2_DownloadFile", path, area)
						Frame:Remove() 
						return 
					end 
					local SavePath
					if(area==0 || area==1)then
						SavePath = AdvDupe2.DataFolder.."/"..GetNodePath(Fldbrw:GetSelectedItem())
					else
						SavePath = "adv_duplicator/"..GetNodePath(Fldbrw:GetSelectedItem())
					end
					AdvDupe2.SavePath = SavePath.."/"..name..".txt" 
					AdvDupe2.SaveNode = Fldbrw:GetSelectedItem().ID
					RunConsoleCommand("AdvDupe2_DownloadFile", path, area)
					Frame:Remove()
				end
	elseif(func==3)then	//Move File Client
		txt = "Select the folder you want to move the File to."
		if SinglePlayer() then
			Tree = self.Tree
		else
			if(!self.Upload.Populated)then self:UpdateClientFiles() end
			Tree = self.Upload
		end
		local Root = GetNodeRoot(ArgNode)
		if(Root && Root.Name=="=Adv Duplicator=")then AltTree=Root end
		todo =	function()
					local base = AdvDupe2.DataFolder
					local ParentNode
					local savepath = ""
					if(AltTree)then base = "adv_duplicator" end
					
					if(!Fldbrw:GetSelectedItem())then
						savepath = base.."/"
						ParentNode = 0
						if(AltTree)then ParentNode = 1 end
					else
						local NodePath = GetNodePath(Fldbrw:GetSelectedItem())
						savepath = base.."/"..NodePath.."/"
						ParentNode = Fldbrw:GetSelectedItem().ID
					end
					savepath = savepath..name
					savepath = CheckFileNameCl(savepath)
					if(AltTree)then path = string.sub(path, 18) end
					local OldFile = base.."/"..path..".txt"
					local ReFile = file.Read(OldFile)
					file.Write( savepath, ReFile)
					file.Delete(OldFile)
					local name2 = string.Explode("/", savepath)
					name2 = string.sub(name2[#name2], 1, -5)
					if(SinglePlayer())then
						self:AddFile(name2, ParentNode, true)
					else
						self:AddFileToClient(name2, ParentNode, true)
					end
					local NodeP = ArgNode:GetParentNode()
					for k,v in pairs(NodeP.Items or NodeP.ChildNodes.Items)do
						if(v==ArgNode.Panel)then 
							table.remove(NodeP.Items or NodeP.ChildNodes.Items, k) 
							v:Remove()
							NodeP:InvalidateLayout()
							break 
						end
					end
					if(NodeP.ChildNodes)then
						if(NodeP.m_bExpanded)then
							NodeP:SetExpanded(false)
							NodeP:SetExpanded(true)
						end
					end
					Tree.m_pSelectedItem = nil
					Frame:Remove()
				end
	elseif(func==4)then	//Move File Server
		txt = "Select the folder you want to move the File to."
		local Root = GetNodeRoot(ArgNode)
		if(Root && Root.Name=="=Adv Duplicator=")then AltTree=Root else Tree = self.Tree end
		todo = 	function()
					local path1, area1 = ParsePath(GetNodePath(ArgNode))
					local path2, area2

					if(Fldbrw:GetSelectedItem())then
						path2, area2 = ParsePath(GetNodePath(Fldbrw:GetSelectedItem()))
						self.MoveToNode = Fldbrw:GetSelectedItem().ID
						if(area1==2)then area2 = 2 end
					else
						if(area1==2)then
							self.MoveToNode = Root.ID
						else
							self.MoveToNode = 0
						end
						path2 = ""
						area2 = area1
					end

					if((area1==2 && area2!=2) || (area2==2 && area1!=2))then AdvDupe2.Notify("Cannot move files between these directories.", NOTIFY_ERROR) return end
					self.NodeToMove = ArgNode
					RunConsoleCommand("AdvDupe2_MoveFile", area1, area2, path1, path2)
					Frame:Remove()
				end
	end

	
	Frame = vgui.Create("DFrame")
	Frame:SetTitle( txt )
	Frame:SetSize(280, 475)
	Frame:Center()
	Frame:ShowCloseButton(true)
	Frame:MakePopup()
	
	Fldbrw = vgui.Create("DTree", Frame)
	Fldbrw:SetPadding(5)
	Fldbrw:SetPos(10,40)
	Fldbrw:SetSize(260,400)
	
	local function PurgeChildren(Node, Parent)
		if(!Node.ChildNodes)then return end
		local child
		for k,v in pairs(Node.ChildNodes:GetItems())do
			if(v.IsFile)then continue end
			child = Parent:AddNode(v.Name)
			child.Name = v.Name
			child.ID = v.ID
			PurgeChildren(v, child)
		end
		return
	end
	
	local child
	for k,v in pairs(AltTree && AltTree.ChildNodes.Items or Tree:GetItems())do
		if(v.IsFile || v.Name=="=Adv Duplicator=")then continue end
		child = Fldbrw:AddNode(v.Name)
		child.Name = v.Name
		child.ID = v.ID
		PurgeChildren(v, child)
	end
	
	local confirm = vgui.Create("DButton", Frame)
	confirm:SetSize(75,25)
	confirm:SetText("Ok")
	confirm:AlignBottom(5)
	confirm:AlignLeft(10)
	confirm.DoClick = todo
	
	local Cancel = vgui.Create("DButton", Frame)
	Cancel:SetSize(75,25)
	Cancel:SetText("Cancel")	
	Cancel:AlignBottom(5)
	Cancel:AlignRight(10)
	Cancel.DoClick = function() Frame:Remove() end

end

local function DeleteFilesInFolders(Search, Folders, Files)
	Search = string.sub(Search, 6, -2)
	
	for k,v in pairs(Files)do
		file.Delete(Search..v)
	end
	
	for k,v in pairs(Folders)do
		file.TFind("data/"..Search..v.."/*", DeleteFilesInFolders)
	end

end

local function RemoveFileNodes(Node)
	for k,v in pairs(Node.ChildNodes.Items)do
		if(v.IsFile)then
			table.remove(Node.ChildNodes.Items, k)
			v:Remove()
		elseif(v.ChildNodes)then
			RemoveFileNodes(v)
		end
	end
	Node:InvalidateLayout()
	Node:SetExpanded(false)
end

local function Delete(Tree, Folder, Server)

	local Node = Tree:GetSelectedItem()
	local msg 
	
	if(Server)then
		msg = '" from the SERVER?'
	else
		msg = '" from your CLIENT?'
	end
	
	if(!Folder)then
		msg = 'Are you sure you want to delete the FILE, "'..Node.Name..msg
	else
		msg = 'Are you sure you want to delete the ENTIRE FOLDER, "'..Node.Name..msg
	end
	
	local path, area = ParsePath(GetNodePath(Node))
	
	local Frame = vgui.Create("DFrame")
	Frame:SetTitle( "Are You Sure?" )
	Frame:SetSize(250, 100)
	Frame:Center()
	Frame:ShowCloseButton(false)
	
	local label = vgui.Create("DLabel", Frame)
	label:AlignLeft(5)
	label:AlignTop(30)
	label:SetText(msg)
	label:SetWide(240)
	label:SetTall(25)
	label:SetWrap(true)
	
	local confirm = vgui.Create("DButton", Frame)
	confirm:SetSize(75,25)
	confirm:SetText("Delete")
	confirm:AlignBottom(5)
	confirm:AlignLeft(10)
	confirm.DoClick = 	function() 
							if(!Folder)then
								if(Server)then
									Tree:GetParent().NodeToDelete = Node
									Tree:GetParent().ParentToDelete = Node:GetParentNode()
									RunConsoleCommand("AdvDupe2_DeleteFile", path, area, "false")
								else
									if(area==1)then path = "=Public=/"..path end
									path = AdvDupe2.DataFolder.."/"..path..".txt"
									local NodeP = Node:GetParentNode()
									
									for k,v in pairs(NodeP.Items or NodeP.ChildNodes.Items)do
										if(v==Node.Panel)then 
											table.remove(NodeP.Items or NodeP.ChildNodes.Items, k) 
											v:Remove()
											NodeP:InvalidateLayout()
											break 
										end
									end
									if(NodeP.ChildNodes)then
										if(NodeP.m_bExpanded)then
											NodeP:SetExpanded(false)
											NodeP:SetExpanded(true)
										end
									end
									Tree.m_pSelectedItem = nil
								end
								file.Delete(path)
							else
								if(Server)then
									Tree:GetParent().NodeToDelete = false
									Tree:GetParent().ParentToDelete = Node
									RunConsoleCommand("AdvDupe2_DeleteFile", path, area, "true")
								else
									if(area==1)then path = "=Public=/"..path end
									path = "data/"..AdvDupe2.DataFolder.."/"..path.."/*"
									if(Node.ChildNodes)then
										RemoveFileNodes(Node)
									end
									Node:SetExpanded(false)
									Tree.m_pSelectedItem = nil
								end
								file.TFind(path, DeleteFilesInFolders)
							end
							Frame:Remove() 
						end

	local Cancel = vgui.Create("DButton", Frame)
	Cancel:SetSize(75,25)
	Cancel:SetText("Cancel")	
	Cancel:AlignBottom(5)
	Cancel:AlignRight(10)
	Cancel.DoClick = function() Frame:Remove() end
	Frame:SetVisible(true)
	Frame:MakePopup()
	
end

function PANEL:AddNewFolder(Tree, base)

	local Node 
	if(base)then
		Node = Tree
	else
		Node = Tree:GetSelectedItem()
	end
	
	local name = self.Textbox:GetValue() 
	if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Name is blank!", NOTIFY_ERROR) return end 
	name = name:gsub("%W","") 
	
	local path, area
	if(base)then
		path = AdvDupe2.DataFolder.."/"..name
	else
		path, area = ParsePath(GetNodePath(Node))
		if(area==0)then
			path = AdvDupe2.DataFolder.."/"..path.."/"..name
		elseif(area==1)then
			path = AdvDupe2.DataFolder.."/=Public=/"..path.."/"..name
		else
			path = "adv_duplicator/"..path.."/"..name
		end
	end
	
	if(file.IsDir(path))then AdvDupe2.Notify("Folder name alreayd exists.", NOTIFY_ERROR) return end
	
	file.CreateDir(path)
	
	local Folder = Node:AddNode(name)
		self.CNodes[ClientFolderCount] = Folder
		Folder.IsFile = false
		Folder.Name = name
		Folder.SortName = "A"..string.lower(name)
		Folder.ID = ClientFolderCount
		ClientFolderCount = ClientFolderCount + 1
		
	SortChildren(Node)
	
	if(!Node.m_bExpanded)then
		Node:SetExpanded(true)
	end
	
	Tree:SetSelectedItem(Folder)
end

local function Incomplete()
	AdvDupe2.Notify("This feature is not yet complete!",NOTIFY_GENERIC,10)
end

function PANEL:DoClick(Node)
	if(!Node || !Node.IsFile)then return end
	if(CurTime()-self.LastClick<=0.25 && self.LastNode==Node)then
		local path, area = ParsePath(GetNodePath(Node))
		RunConsoleCommand("AdvDupe2_OpenFile", path, area)
	end
	self.LastNode = Node
	self.LastClick = CurTime()
end

local function RenameFileCl(Node, name)
	if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Enter a file name to rename file.", NOTIFY_ERROR) return end
	local path, area = ParsePath(GetNodePath(Node))
	local File, FilePath, tempFilePath = "", "", ""
	if(area==0)then
		tempFilePath = AdvDupe2.DataFolder.."/"..path
	elseif(area==1)then
		tempFilePath = AdvDupe2.DataFolder.."/=Public=/"..path
	elseif(area==2)then
		tempFilePath = "adv_duplicator/"..path
	end

	File = file.Read(tempFilePath..".txt")
	FilePath = CheckFileNameCl(string.sub(tempFilePath, 1, #tempFilePath-#Node.Name)..name)

	if(!FilePath)then AdvDupe2.Notify("Rename limit exceeded, could not rename.", NOTIFY_ERROR) return end
	file.Write(FilePath, File)
	if(file.Exists(FilePath))then
		file.Delete(tempFilePath..".txt")
		local NewName = string.Explode("/", FilePath)
		NewName = string.sub(NewName[#NewName], 1, -5)
		Node:SetText(NewName)
		Node.Name = NewName
		Node.SortName = "B"..string.lower(NewName)
		AdvDupe2.Notify("File renamed to "..NewName)
	else
		AdvDupe2.Notify("File was not renamed.", NOTIFY_ERROR)
	end
	
	local NodeP = Node:GetParentNode()
	SortChildren(NodeP)
end

function PANEL:DoRightClick(Node)
	if(Node==nil)then return end
	self:SetSelectedItem(Node)
	local parent = self:GetParent()
	local Menu = DermaMenu()
		
	if(SinglePlayer())then
		if(Node.IsFile)then
			Menu:AddOption("Open", 	function() 
										local path, area = ParsePath(GetNodePath(Node))
										RunConsoleCommand("AdvDupe2_OpenFile", path, area) 
									end)
			Menu:AddOption("Rename", 	function()
											RenameFileCl(Node, parent.Textbox:GetValue())
											parent.Textbox:SetValue("File_Name...")
											parent.DescBox:SetValue("Description...")
										end)
			Menu:AddOption("Move File", function() parent:FolderSelect( 3, Node.Name, GetNodePath(Node), Node) end)
			Menu:AddOption("Delete", function() Delete(self, false, false) end)
		else
			Menu:AddOption("Save", 	function()
										local name = parent.Textbox:GetValue() 
										if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Name field is blank.", NOTIFY_ERROR) return end 
										local path, area = ParsePath(GetNodePath(Node) )
										local desc = parent.DescBox:GetValue()
										if(desc=="Description...")then desc="" end
										RunConsoleCommand("AdvDupe2_SaveFile", parent.Textbox:GetValue(), path, area, desc, Node.ID) 
										parent.Textbox:SetValue("File_Name...")
										parent.DescBox:SetValue("Description...")
									end)
			Menu:AddOption("New Folder", 	function()
												parent:AddNewFolder(self, false) 
												parent.Textbox:SetValue("File_Name...")
												parent.DescBox:SetValue("Description...")
											end)
			Menu:AddOption("Delete", function() Delete(self, true, false) end)
		end
	
	elseif(parent.Change.Server)then

		if(Node.IsFile)then
			Menu:AddOption("Open", 	function() 
										local path, area = ParsePath(GetNodePath(Node)) 
										RunConsoleCommand("AdvDupe2_OpenFile", path, area) 
									end) 
			Menu:AddOption("Download", 	function() 
											parent:FolderSelect(2, Node.Name, nil, Node) 
										end) 
			Menu:AddOption("Rename", 	function()
											local name = parent.Textbox:GetValue() 
											if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Name field is blank!", NOTIFY_ERROR) return end 
											local path, area = ParsePath(GetNodePath(Node))
											parent.NodeToRename = Node
											RunConsoleCommand("AdvDupe2_RenameFile", area, name, path )
											parent.Textbox:SetValue("File_Name...")
											parent.DescBox:SetValue("Description...")
										end)
			Menu:AddOption("Move File", function()
											parent:FolderSelect(4, nil, nil, Node) 
										end)
			Menu:AddOption("Delete", function() Delete(self, false, true) end )
		else
			Menu:AddOption("Save", 	function()
										local name = parent.Textbox:GetValue() 
										if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Name field is blank!", NOTIFY_ERROR) return end 
										local path, area = ParsePath(GetNodePath(Node))
										local desc = parent.DescBox:GetValue()
										if(desc=="Description...")then desc="" end
										RunConsoleCommand("AdvDupe2_SaveFile", parent.Textbox:GetValue(), path, area, desc, Node.ID) 
										parent.Textbox:SetValue("File_Name...")
										parent.DescBox:SetValue("Description...")
									end)
			Menu:AddOption("New Folder", 	function() 
												local name = parent.Textbox:GetValue() 
												if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Name field is blank!", NOTIFY_ERROR) return end 
												name = name:gsub("%W","") 
												local path, area = ParsePath(GetNodePath(Node))
												RunConsoleCommand("AdvDupe2_NewFolder", name, path, area, Node.ID) 
												parent.Textbox:SetValue("File_Name...")
												parent.DescBox:SetValue("Description...")
											end)
			Menu:AddOption("Delete", function() Delete(self, true, true) end )
		end
	else
		if(Node.IsFile)then 
			Menu:AddOption("Upload", function() parent:FolderSelect(1, Node.Name, GetNodePath(Node), Node) end)//function() AdvDupe2.InitializeUpload(GetNodePath(Tree:GetSelectedItem())) end ) 
			Menu:AddOption("Rename", 	function()
											RenameFileCl(Node, parent.Textbox:GetValue())
											parent.Textbox:SetValue("File_Name...")
											parent.DescBox:SetValue("Description...")
										end)
			Menu:AddOption("Move File", function() parent:FolderSelect( 3, Node.Name, GetNodePath(Node), Node) end)
			Menu:AddOption("Delete", function() Delete(self, false, false) end)
		else
			Menu:AddOption("New Folder", 	function() 
												parent:AddNewFolder(self)
												parent.Textbox:SetValue("File_Name...")
												parent.DescBox:SetValue("Description...")
											end)
			Menu:AddOption("Delete", function() Delete(self, true, false) end)
		end
	end
	Menu:Open()
end



function PANEL:Init()

	PANEL.Panel = self
	self.Nodes = {}
	self.CNodes = {}
	local Wide, Tall = self:GetSize()
	local TreeOff = 60
	local UpOff = 40
	
	self.FileParent = 0
	
	self.Textbox = vgui.Create("DTextEntry", self)
	self.Textbox:SetMultiline(false)
	self.Textbox:SetKeyboardInputEnabled( true )
	self.Textbox:SetEnabled( true )
	self.Textbox:SetAllowNonAsciiCharacters( true )
	self.Textbox:SetValue("File_Name...")
	self.Textbox.OnMousePressed = 	function() 
										self.Textbox:OnGetFocus() 
										if(self.Textbox:GetValue()=="File_Name...")then 
											self.Textbox:SelectAllOnFocus(true) 
										end 
									end
	self.Textbox:SetUpdateOnType(true)
	self.Textbox.OnTextChanged = 	function() 
										local new, changed = self.Textbox:GetValue():gsub("[?.:\"*<>|]","")
										if changed > 0 then
											self.Textbox:SetValue(new)
										end
									end
	self.Textbox.OnValueChange = 	function()
										if(self.Textbox:GetValue()!="File_Name...")then
											local new,changed = self.Textbox:GetValue():gsub("[?.:\"*<>|]","")
											if changed > 0 then
												self.Textbox:SetValue(new)
											end
										end
									end
	/*function()
										//if(self.Textbox:GetValue()!="File_Name...")then
											local new,changed = self.Textbox:GetValue():gsub("[?.:\"*<>|]","")
											if changed > 0 then
												self.Textbox:SetValue(new)
											end
										//end
									end*/
	
	self.Save = vgui.Create("DButton", self)
	self.Save:SetText("Save")
	self.Save:SetToolTip("Save to base folder")
	self.Save.DoClick = 	function()
								if(self.Textbox:GetValue()=="" || self.Textbox:GetValue()=="File_Name...")then AdvDupe2.Notify("Name field is blank!", NOTIFY_ERROR) return end
								--[[local _,changed = self.Textbox:GetValue():gsub("[?.:\"*<>|]","")
								if changed > 0 then
									AdvDupe2.Notify("Filenames cannot contain ?.:\"*<>|",NOTIFY_ERROR)
									return
								end]]
								local desc = self.DescBox:GetValue()
								if(desc=="Description...")then desc="" end
								RunConsoleCommand("AdvDupe2_SaveFile", self.Textbox:GetValue(), "", 0, desc, 0)
								self.Textbox:SetValue("File_Name...")
								self.DescBox:SetValue("Description...")
							end
	self.Textbox.OnEnter = self.Save.DoClick
	
	self.DescBox = vgui.Create("DTextEntry", self)
	self.DescBox:SetMultiline(false)
	self.DescBox:SetKeyboardInputEnabled( true )
	self.DescBox:SetEnabled( true )
	self.DescBox:SetValue("Description...")
	self.DescBox.OnEnter = self.Save.DoClick
	self.DescBox.OnMousePressed = 	function() 
										self.DescBox:OnGetFocus() 
										if(self.DescBox:GetValue()=="Description...")then 
											self.DescBox:SelectAllOnFocus(true) 
										end 
									end
	
	if(!SinglePlayer())then
		self.Upload = vgui.Create("DTree", self)
		self.Upload:SetPadding(5)
		self.Upload.Populated = false
		self.Upload.DoRightClick = self.DoRightClick
		self.Upload:SetVisible(false)
		self.Upload.LastClick = 0
	end
	
	self.Tree = vgui.Create("DTree", self)
	self.Tree:SetPadding(5)
	self.Tree.LastClick = 0
	self.Tree.DoClick = self.DoClick
	self.Tree.DoRightClick = self.DoRightClick
	self.CurrentParent = self.Tree

	self.Help = vgui.Create("DButton", self)
	//self.Help:SetText("?")
	self.Help:SetImage("gui/silkicons/help")
	self.Help.DoClick = function(btn)
							local Menu = DermaMenu()
							Menu:AddOption("Forum", function() gui.OpenURL("http://www.facepunch.com/threads/1136597") end)
							Menu:AddOption("Bug Reporting", function() gui.OpenURL("http://code.google.com/p/advdupe2/issues/list") end)
							Menu:AddOption("About", AdvDupe2.ShowSplash)
							Menu:Open()
						end
	
	self.Update = vgui.Create("DButton", self)
	self.Update:SetText("Update")
	self.Update:SetToolTip("Update files")
	self.Update.DoClick = function(button)
		local Wide, Tall = self:GetSize()
		if(self.Change.Server) then
			RunConsoleCommand("AdvDupe2_SendFiles", 0)
		else
			for k,v in pairs(self.Upload.Items)do
				v:Remove()
			end
			self.Upload.Items = {}
			self.Upload:InvalidateLayout()
			self.CNodes = {}
			self.Upload.m_pSelectedItem = nil
			self:UpdateClientFiles()
		end
	end
	
	self.NewFolder = vgui.Create("DButton", self)
	self.NewFolder:SetText("New Folder")
	self.NewFolder:SetToolTip("Create a new folder in the base folder")
	self.NewFolder.DoClick = 	function() 
									if(self.Change.Server)then
										local name = self.Textbox:GetValue()
										if(name=="" || name=="File_Name...")then AdvDupe2.Notify("Name field is blank!", NOTIFY_ERROR) return end
										name = name:gsub("%W","")
										RunConsoleCommand("AdvDupe2_NewFolder", name, "", 0) 
										self.Textbox:SetValue("File_Name...")
									else
										self:AddNewFolder(self.Upload, true)
									end
								end
	
	self.Change = vgui.Create("DButton", self)
	self.Change.Server = true
	if(SinglePlayer())then
		self.Change:SetText("Local Files")
	else
		self.Change:SetText("Server Files")
		self.Change:SetToolTip("Change between server and client files")
		self.Change.DoClick = 	function(button)
									if(self.Change.Server)then
										if(SinglePlayer())then return end
										self.Change:SetText("Client Files")
										self.Change.Server = false
										self.Tree:SetVisible(false)
										if(!self.Upload.Populated)then self:UpdateClientFiles() end
										self.Upload:SetVisible(true)
									else
										self.Change:SetText("Server Files")
										self.Change.Server = true
										self.Upload:SetVisible(false)
										self.Tree:SetVisible(true)
									end
								end
	end
	
	self:SetPaintBackground(false)

end

function PANEL:AdjustFiller(Menu)
	local Tab = self.Panel:GetTable()
	if(Menu)then
		if(g_ContextMenu:GetTall()<ScrH()*0.5)then
			local Tall = g_ActiveControlPanel:GetTall() + 10
			local MaxTall = ScrH() * 0.8
			if ( Tall > MaxTall ) then Tall = MaxTall end
			Tab.Filler:SetTall(Tall-49)
		else
			Tab.Filler:SetTall(g_ContextMenu:GetTall()-49)
		end
	else
		Tab.Filler:SetTall(Tab.Panel:GetParent():GetParent():GetParent():GetParent():GetParent():GetTall()-45)
	end
end

local CMenu = false
hook.Add("OnContextMenuOpen", "AD2MenuFormat",
	function()
		if(!GetControlPanel("advdupe2"):IsVisible() || !PANEL || !PANEL.Panel)then return end
		CMenu = true
		PANEL:AdjustFiller(true)
	end)

hook.Add("SpawnMenuOpen", "AD2MenuFormat", 
	function()
		if(CMenu)then CMenu = false return end
		if(!GetControlPanel("advdupe2"):IsVisible() || !PANEL || !PANEL.Panel)then return end
		PANEL:AdjustFiller(false)
	end)

function PANEL:PerformLayout()
	
	local w = self:GetWide()
	self.Change:SetPos(0, 0)
	self.Change:SetSize(w, 20)
	if(self.Upload)then
		self.Upload:SetPos(0, 20)
		self.Upload:SetSize(w,360)
	end
	self.Tree:SetPos(0, 20)
	self.Tree:SetSize(w,360)
	self.Textbox:SetPos(0,380)
	self.Textbox:SetSize(w*.75, 20)
	self.Save:SetPos(w*.75,380)
	self.Save:SetSize(w*.25, 20)
	self.DescBox:SetPos(0,400)
	self.DescBox:SetSize(w, 20)
	self.Help:SetPos(0, 420)
	self.Help:SetSize(22, 20)
	self.Update:SetPos(22, 420)
	self.Update:SetSize(w/2-22, 20)
	self.NewFolder:SetPos(w/2, 420)
	self.NewFolder:SetSize(w/2, 20)
end

function PANEL:AddFolder(Name, ID, Parent, New)

	local NodeP 
	if(Parent!=0)then
		NodeP = self.Nodes[Parent]
	else
		NodeP = self.Tree
	end
	if(!ValidPanel(NodeP))then return end
	local Folder = NodeP:AddNode(Name)

	self.Nodes[ID]=Folder
	Folder.IsFile = false
	Folder.Name = Name
	Folder.SortName = "A"..string.lower(Name)
	Folder.ID = ID

	if(NodeP.ChildNodes)then 
		NodeP.ChildNodes.Items[#NodeP.ChildNodes.Items].Name = Folder.Name 
	end
	if(New)then
		SortChildren(NodeP)
	end

end

function PANEL:AddFile(Name, Parent, New)

	local NodeP 
	if(Parent!=0)then
		NodeP = self.Nodes[Parent]
	else
		NodeP = self.Tree
	end
	if(!ValidPanel(NodeP))then return end
	
	local File = NodeP:AddNode(Name)
	File.IsFile = true
	File.Name = Name
	File.SortName = "B"..string.lower(Name)
	File.Icon:SetImage("vgui/spawnmenu/file")

	if(NodeP.ChildNodes)then  
		NodeP.ChildNodes.Items[#NodeP.ChildNodes.Items].IsFile = true  
	end

	if(New)then
		SortChildren(NodeP)
	end

end

function PANEL:AddFileToClient(Name, Parent, New)
	local NodeP 
	if(Parent!=0)then
		NodeP = self.CNodes[Parent]
	else
		NodeP = self.Upload
	end
	if(!ValidPanel(NodeP))then return end
	
	local File = NodeP:AddNode(Name)
	File.IsFile = true
	File.Name = Name
	File.SortName = "B"..string.lower(Name)
	File.Icon:SetImage("vgui/spawnmenu/file")

	if(NodeP.ChildNodes)then  
		NodeP.ChildNodes.Items[#NodeP.ChildNodes.Items].IsFile = true 
	end
	if(New)then
		SortChildren(NodeP)
	end
end

function PANEL:ClearBrowser()
	for k,v in pairs(self.Tree:GetItems())do
		v:Remove()
	end
	self.Tree.Items = {}
	self.Tree:InvalidateLayout()
	self.Nodes = {}
	self.Tree.m_pSelectedItem = nil
	RunConsoleCommand("AdvDupe2_SendFiles", 1)
end

function PANEL:RenameNode(Name)
	local Node = self.NodeToRename
	Node:SetText(Name)
	Node.Name = Name
	Node.SortName = "B"..string.lower(Name)
	local NodeP = Node:GetParentNode()
	SortChildren(NodeP)
	AdvDupe2.Notify("File was renamed to "..Name)
	self.NodeToRename = nil
end

function PANEL:MoveNode(Name)
	local Node = self.NodeToMove
	local NodeP = Node:GetParentNode()
	Node:GetRoot().m_pSelectedItem = nil
	for k,v in pairs(NodeP.Items or NodeP.ChildNodes.Items)do
		if(v==Node.Panel)then
			table.remove(NodeP.Items or NodeP.ChildNodes.Items, k)
			v:Remove()
			NodeP:InvalidateLayout()
			break
		end
	end
	if(NodeP.m_bExpanded)then
		NodeP:SetExpanded(false)
		NodeP:SetExpanded(true)
	end
	if(self.MoveToNode==0)then
		NodeP = self.Tree
	else
		NodeP = self.Nodes[self.MoveToNode]
	end

	local NewNode = NodeP:AddNode(Name)
	NewNode.Name = Name
	NewNode.SortName = "B"..string.lower(Name)
	NewNode.Icon:SetImage("vgui/spawnmenu/file")
	NewNode.IsFile = true
	if(NodeP.ChildNodes)then  
		NodeP.ChildNodes.Items[#NodeP.ChildNodes.Items].IsFile = true 
	end
	SortChildren(NodeP)
	
end

function PANEL:DeleteNode()
	if(self.NodeToDelete==false)then
		RemoveFileNodes(self.ParentToDelete)
	else
		for k,v in pairs(self.ParentToDelete.Items or self.ParentToDelete.ChildNodes.Items)do
			if(v==self.NodeToDelete)then 
				table.remove(self.ParentToDelete.Items or self.ParentToDelete.ChildNodes.Items, k) 
				v:Remove()
				self.ParentToDelete:InvalidateLayout()
				break 
			end
		end
		if(self.ParentToDelete.ChildNodes)then
			if(self.ParentToDelete.m_bExpanded)then
				self.ParentToDelete:SetExpanded(false)
				self.ParentToDelete:SetExpanded(true)
			end
		end
		self.Tree.m_pSelectedItem = nil
	end
	self.ParentToDelete=nil
	self.NodeToDelete=nil
end

vgui.Register("advdupe2_browser", PANEL, "DPanel")