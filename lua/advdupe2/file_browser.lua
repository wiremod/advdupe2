--[[
	Title: Adv. Dupe 2 File Browser

	Desc: Displays and interfaces with duplication files.

	Author: TB

	Version: 1.0
]]

local History = {}
local Narrow = {}

local switch = true
local count = 0

local function AddHistory(txt)
	txt = string.lower(txt)
	local char1 = txt[1]
	local char2
	for i = 1, #History do
		char2 = History[i][1]
		if (char1 == char2) then
			if (History[i] == txt) then
				return
			end
		elseif (char1 < char2) then
			break
		end
	end

	table.insert(History, txt)
	table.sort(History, function(a, b) return a < b end)
end

local function NarrowHistory(txt, last)
	txt = string.lower(txt)
	local temp = {}
	if (last <= #txt and last ~= 0 and #txt ~= 1) then
		for i = 1, #Narrow do
			if (Narrow[i][last + 1] == txt[last + 1]) then
				table.insert(temp, Narrow[i])
			elseif (Narrow[i][last + 1] ~= '') then
				break
			end
		end
	else
		local char1 = txt[1]
		local char2
		for i = 1, #History do
			char2 = History[i][1]
			if (char1 == char2) then
				if (#txt > 1) then
					for k = 2, #txt do
						if (txt[k] ~= History[i][k]) then
							break
						end
						if (k == #txt) then
							table.insert(temp, History[i])
						end
					end
				else
					table.insert(temp, History[i])
				end
			elseif (char1 < char2) then
				break
			end
		end
	end

	Narrow = temp
end

local function tableSortNodes(tbl)
    for k, v in ipairs(tbl) do tbl[k] = {string.lower(v.Label:GetText()), v} end
    table.sort(tbl, function(a,b) return a[1]<b[1] end)
    for k, v in ipairs(tbl) do tbl[k] = v[2] end
end

local BROWSERPNL = {}
AccessorFunc(BROWSERPNL, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(BROWSERPNL, "m_bgColor", "BackgroundColor")
Derma_Hook(BROWSERPNL, "Paint", "Paint", "Panel")
Derma_Hook(BROWSERPNL, "PerformLayout", "Layout", "Panel")

local setbrowserpnlsize
local function SetBrowserPnlSize(self, x, y)
	setbrowserpnlsize(self, x, y)
	self.pnlCanvas:SetWide(x)
	self.pnlCanvas.VBar:SetUp(y, self.pnlCanvas:GetTall())
end

function BROWSERPNL:Init()
	setbrowserpnlsize = self.SetSize
	self.SetSize = SetBrowserPnlSize
	self.pnlCanvas = vgui.Create("advdupe2_browser_tree", self)

	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetBackgroundColor(self:GetSkin().text_bright)
end

function BROWSERPNL:OnVScroll(iOffset)
	self.pnlCanvas:SetPos(0, iOffset)
end

derma.DefineControl("advdupe2_browser_panel", "AD2 File Browser", BROWSERPNL, "Panel")

local BROWSER = {}
AccessorFunc(BROWSER, "m_pSelectedItem", "SelectedItem")
Derma_Hook(BROWSER, "Paint", "Paint", "Panel")

local origSetTall
local function SetTall(self, val)
	origSetTall(self, val)
	self.VBar:SetUp(self:GetParent():GetTall(), self:GetTall())
end

function BROWSER:Init()
	self:SetTall(0)
	origSetTall = self.SetTall
	self.SetTall = SetTall

	self.VBar = vgui.Create("DVScrollBar", self:GetParent())
	self.VBar:Dock(RIGHT)
	self.Nodes = 0
	self.ChildrenExpanded = {}
	self.ChildList = self
	self.m_bExpanded = true
	self.Folders = {}
	self.Files = {}
	self.LastClick = CurTime()
end

local function GetNodePath(node)
	local path = node.Label:GetText()
	local area = 0
	local name = ""
	node = node.ParentNode
	if (not node.ParentNode) then
		if (path == "-Public-") then
			area = 1
		elseif (path == "-Advanced Duplicator 1-") then
			area = 2
		end
		return "", area
	end

	while (true) do

		name = node.Label:GetText()
		if (name == "-Advanced Duplicator 2-") then
			break
		elseif (name == "-Public-") then
			area = 1
			break
		elseif (name == "-Advanced Duplicator 1-") then
			area = 2
			break
		end
		path = name .. "/" .. path
		node = node.ParentNode
	end

	return path, area
end

function BROWSER:DoNodeLeftClick(node)
	if (self.m_pSelectedItem == node and CurTime() - self.LastClick <= 0.25) then -- Check for double click
		if (node.Derma.ClassName == "advdupe2_browser_folder") then
			if (node.Expander) then
				node:SetExpanded() -- It's a folder, expand/collapse it
			end
		else
			AdvDupe2.UploadFile(GetNodePath(node))
		end
	else
		self:SetSelected(node) -- A node was clicked, select it
	end
	self.LastClick = CurTime()
end

local function AddNewFolder(node)
	local Controller = node.Control:GetParent():GetParent()
	local name = Controller.FileName:GetValue()
	local char = string.match(name, "[^%w_ ]")
	if char then
		AdvDupe2.Notify("Name contains invalid character ("..char..")!", NOTIFY_ERROR)
		Controller.FileName:SelectAllOnFocus(true)
		Controller.FileName:OnGetFocus()
		Controller.FileName:RequestFocus()
		return
	end
	if (name == "" or name == "Folder_Name...") then
		AdvDupe2.Notify("Name is blank!", NOTIFY_ERROR)
		Controller.FileName:SelectAllOnFocus(true)
		Controller.FileName:OnGetFocus()
		Controller.FileName:RequestFocus()
		return
	end
	local path, area = GetNodePath(node)
	if (area == 0) then
		path = AdvDupe2.DataFolder .. "/" .. path .. "/" .. name
	elseif (area == 1) then
		path = AdvDupe2.DataFolder .. "/=Public=/" .. path .. "/" .. name
	else
		path = "adv_duplicator/" .. path .. "/" .. name
	end

	if (file.IsDir(path, "DATA")) then
		AdvDupe2.Notify("Folder name already exists.", NOTIFY_ERROR)
		Controller.FileName:SelectAllOnFocus(true)
		Controller.FileName:OnGetFocus()
		Controller.FileName:RequestFocus()
		return
	end
	file.CreateDir(path)

	local Folder = node:AddFolder(name)
	node.Control:Sort(node)

	if (not node.m_bExpanded) then
		node:SetExpanded()
	end

	node.Control:SetSelected(Folder)
	if (Controller.Expanded) then
		AdvDupe2.FileBrowser:Slide(false)
	end
end

local function CollapseChildren(node)
	node.m_bExpanded = false
	if (node.Expander) then
		node.Expander:SetExpanded(false)
		node.ChildList:SetTall(0)
		for i = 1, #node.ChildrenExpanded do
			CollapseChildren(node.ChildrenExpanded[i])
		end
		node.ChildrenExpanded = {}
	end
end

local function CollapseParentsComplete(node)
	if (not node.ParentNode.ParentNode) then
		node:SetExpanded(false)
		return
	end
	CollapseParentsComplete(node.ParentNode)
end

function AdvDupe2.GetFilename(path, overwrite)
	if not overwrite and file.Exists(path .. ".txt", "DATA") then
		for i = 1, AdvDupe2.FileRenameTryLimit do
			local p = string.format("%s_%03d.txt", path, i)
			if not file.Exists(p, "DATA") then
				return p
			end
		end
		return false
	end
	return path .. ".txt"
end

local function GetFullPath(node)
	local path, area = GetNodePath(node)
	if (area == 0) then
		path = AdvDupe2.DataFolder .. "/" .. path .. "/"
	elseif (area == 1) then

	else
		path = "adv_duplicator/" .. path .. "/"
	end
	return path
end

local function GetNodeRoot(node)
	local Root
	while (true) do
		if (not node.ParentNode.ParentNode) then
			Root = node
			break
		end
		node = node.ParentNode
	end
	return Root
end

local function RenameFileCl(node, name)
	local path, area = GetNodePath(node)
	local File, FilePath, tempFilePath = "", "", ""
	if (area == 0) then
		tempFilePath = AdvDupe2.DataFolder .. "/" .. path
	elseif (area == 1) then
		tempFilePath = AdvDupe2.DataFolder .. "/=Public=/" .. path
	elseif (area == 2) then
		tempFilePath = "adv_duplicator/" .. path
	end

	File = file.Read(tempFilePath .. ".txt")
	FilePath = AdvDupe2.GetFilename(
		string.sub(tempFilePath, 1, #tempFilePath - #node.Label:GetText()) .. name)

	if (not FilePath) then
		AdvDupe2.Notify("Rename limit exceeded, could not rename.", NOTIFY_ERROR)
		return
	end
	file.Write(FilePath, File)
	if (file.Exists(FilePath, "DATA")) then
		file.Delete(tempFilePath .. ".txt")
		local NewName = string.Explode("/", FilePath)
		NewName = string.sub(NewName[#NewName], 1, -5)
		node.Label:SetText(NewName)
		node.Label:SizeToContents()
		AdvDupe2.Notify("File renamed to " .. NewName)
	else
		AdvDupe2.Notify("File was not renamed.", NOTIFY_ERROR)
	end

	node.Control:Sort(node.ParentNode)
end

local function MoveFileClient(node)
	if (not node) then
		AdvDupe2.Notify("Select a folder to move the file to.", NOTIFY_ERROR)
		return
	end
	if (node.Derma.ClassName == "advdupe2_browser_file") then
		AdvDupe2.Notify("You muse select a folder as a destination.", NOTIFY_ERROR)
		return
	end
	local base = AdvDupe2.DataFolder
	local ParentNode

	local node2 = node.Control.ActionNode
	local path, area = GetNodePath(node2)
	local path2, area2 = GetNodePath(node)

	if (area ~= area2 or path == path2) then
		AdvDupe2.Notify("Cannot move files between these directories.", NOTIFY_ERROR)
		return
	end
	if (area == 2) then base = "adv_duplicator" end

	local savepath = AdvDupe2.GetFilename(
						 base .. "/" .. path2 .. "/" .. node2.Label:GetText())
	local OldFile = base .. "/" .. path .. ".txt"

	local ReFile = file.Read(OldFile)
	file.Write(savepath, ReFile)
	file.Delete(OldFile)
	local name2 = string.Explode("/", savepath)
	name2 = string.sub(name2[#name2], 1, -5)
	node2.Control:RemoveNode(node2)
	node2 = node:AddFile(name2)
	node2.Control:Sort(node)
	AdvDupe2.FileBrowser:Slide(false)
	AdvDupe2.FileBrowser.Info:SetVisible(false)
end

local function DeleteFilesInFolders(path)
	local files, folders = file.Find(path .. "*", "DATA")

	for k, v in pairs(files) do file.Delete(path .. v) end

	for k, v in pairs(folders) do DeleteFilesInFolders(path .. v .. "/") end

	file.Delete(path)
end

local function SearchNodes(node, name)
	local tab = {}
	for k, v in pairs(node.Files) do
		if (string.find(string.lower(v.Label:GetText()), name)) then
			table.insert(tab, v)
		end
	end

	for k, v in pairs(node.Folders) do
		for i, j in pairs(SearchNodes(v, name)) do
			table.insert(tab, j)
		end
	end

	return tab
end

local function Search(node, name)
	local pnFileBr = AdvDupe2.FileBrowser
	pnFileBr.Search = vgui.Create("advdupe2_browser_panel", pnFileBr)
	pnFileBr.Search:SetPos(pnFileBr.Browser:GetPos())
	pnFileBr.Search:SetSize(pnFileBr.Browser:GetSize())
	pnFileBr.Search.pnlCanvas.Search = true
	pnFileBr.Browser:SetVisible(false)
	local Files = SearchNodes(node, name)
	tableSortNodes(Files)
	for k, v in pairs(Files) do
		pnFileBr.Search.pnlCanvas:AddFile(v.Label:GetText()).Ref = v
	end
end

function BROWSER:DoNodeRightClick(node)
	self:SetSelected(node)

	local parent = self:GetParent():GetParent()
	parent.FileName:KillFocus()
	parent.Desc:KillFocus()
	local Menu = DermaMenu()
	local root = GetNodeRoot(node).Label:GetText()
	if (node.Derma.ClassName == "advdupe2_browser_file") then
		if (node.Control.Search) then
			Menu:AddOption("Open", function()
				AdvDupe2.UploadFile(GetNodePath(node.Ref))
			end)
			Menu:AddOption("Preview", function()
				local ReadPath, ReadArea = GetNodePath(node.Ref)
				if (ReadArea == 0) then
					ReadPath = AdvDupe2.DataFolder .. "/" .. ReadPath .. ".txt"
				elseif (ReadArea == 1) then
					ReadPath = AdvDupe2.DataFolder .. "/-Public-/" .. ReadPath .. ".txt"
				else
					ReadPath = "adv_duplicator/" .. ReadPath .. ".txt"
				end
				if (not file.Exists(ReadPath, "DATA")) then
					AdvDupe2.Notify("File does not exist", NOTIFY_ERROR)
					return
				end

				local read = file.Read(ReadPath)
				local name = string.Explode("/", ReadPath)
				name = name[#name]
				name = string.sub(name, 1, #name - 4)
				local success, dupe, info, moreinfo = AdvDupe2.Decode(read)
				if (success) then
					AdvDupe2.LoadGhosts(dupe, info, moreinfo, name, true)
				end
			end)
		else
			Menu:AddOption("Open", function()
				AdvDupe2.UploadFile(GetNodePath(node))
			end)
			Menu:AddOption("Preview", function()
				local ReadPath, ReadArea = GetNodePath(node)
				if (ReadArea == 0) then
					ReadPath = AdvDupe2.DataFolder .. "/" .. ReadPath .. ".txt"
				elseif (ReadArea == 1) then
					ReadPath = AdvDupe2.DataFolder .. "/-Public-/" .. ReadPath .. ".txt"
				else
					ReadPath = "adv_duplicator/" .. ReadPath .. ".txt"
				end
				if (not file.Exists(ReadPath, "DATA")) then
					AdvDupe2.Notify("File does not exist", NOTIFY_ERROR)
					return
				end

				local read = file.Read(ReadPath)
				local name = string.Explode("/", ReadPath)
				name = name[#name]
				name = string.sub(name, 1, #name - 4)
				local success, dupe, info, moreinfo = AdvDupe2.Decode(read)
				if (success) then
					AdvDupe2.LoadGhosts(dupe, info, moreinfo, name, true)
				end
			end)
			Menu:AddSpacer()
			Menu:AddOption("Rename", function()
				if (parent.Expanding) then return end
				parent.Submit:SetMaterial("icon16/page_edit.png")
				parent.Submit:SetTooltip("Rename File")
				parent.Desc:SetVisible(false)
				parent.Info:SetVisible(false)
				parent.FileName.FirstChar = true
				parent.FileName.PrevText = parent.FileName:GetValue()
				parent.FileName:SetVisible(true)
				parent.FileName:SetText(node.Label:GetText())
				parent.FileName:SelectAllOnFocus(true)
				parent.FileName:OnMousePressed()
				parent.FileName:RequestFocus()
				parent.Expanding = true
				AdvDupe2.FileBrowser:Slide(true)
				parent.Submit.DoClick = function()
					local name = parent.FileName:GetValue()
					if (name == "") then
						AdvDupe2.Notify("Name field is blank.", NOTIFY_ERROR)
						parent.FileName:SelectAllOnFocus(true)
						parent.FileName:OnGetFocus()
						parent.FileName:RequestFocus()
						return
					end
					AddHistory(name)
					RenameFileCl(node, name)
					AdvDupe2.FileBrowser:Slide(false)
				end
				parent.FileName.OnEnter = parent.Submit.DoClick
			end)
			Menu:AddOption("Move File", function()
				parent.Submit:SetMaterial("icon16/page_paste.png")
				parent.Submit:SetTooltip("Move File")
				parent.FileName:SetVisible(false)
				parent.Desc:SetVisible(false)
				parent.Info:SetText(
					"Select the folder you want to move \nthe File to.")
				parent.Info:SizeToContents()
				parent.Info:SetVisible(true)
				AdvDupe2.FileBrowser:Slide(true)
				node.Control.ActionNode = node
				parent.Submit.DoClick = function()
					MoveFileClient(node.Control.m_pSelectedItem)
				end
			end)
			Menu:AddOption("Delete", function()
				parent.Submit:SetMaterial("icon16/bin_empty.png")
				parent.Submit:SetTooltip("Delete File")
				parent.FileName:SetVisible(false)
				parent.Desc:SetVisible(false)
				if (#node.Label:GetText() > 22) then
					parent.Info:SetText(
						'Are you sure that you want to delete \nthe FILE, "' ..
							node.Label:GetText() .. '" \nfrom your CLIENT?')
				else
					parent.Info:SetText(
						'Are you sure that you want to delete \nthe FILE, "' ..
							node.Label:GetText() .. '" from your CLIENT?')
				end
				parent.Info:SizeToContents()
				parent.Info:SetVisible(true)
				AdvDupe2.FileBrowser:Slide(true)
				parent.Submit.DoClick = function()
					local path, area = GetNodePath(node)
					if (area == 1) then
						path = "-Public-/" .. path
					end
					if (area == 2) then
						path = "adv_duplicator/" .. path .. ".txt"
					else
						path = AdvDupe2.DataFolder .. "/" .. path .. ".txt"
					end
					node.Control:RemoveNode(node)
					file.Delete(path)
					AdvDupe2.FileBrowser:Slide(false)
				end
			end)
		end
	else
		if (root ~= "-Advanced Duplicator 1-") then
			Menu:AddOption("Save", function()
				if (parent.Expanding) then return end
				parent.Submit:SetMaterial("icon16/page_save.png")
				parent.Submit:SetTooltip("Save Duplication")
				if (parent.FileName:GetValue() == "Folder_Name...") then
					parent.FileName:SetText("File_Name...")
				end
				parent.Desc:SetVisible(true)
				parent.Info:SetVisible(false)
				parent.FileName.FirstChar = true
				parent.FileName.PrevText = parent.FileName:GetValue()
				parent.FileName:SetVisible(true)
				parent.FileName:SelectAllOnFocus(true)
				parent.FileName:OnMousePressed()
				parent.FileName:RequestFocus()
				node.Control.ActionNode = node
				parent.Expanding = true
				AdvDupe2.FileBrowser:Slide(true)
				parent.Submit.DoClick = function()
					local name = parent.FileName:GetValue()
					if (name == "" or name == "File_Name...") then
						AdvDupe2.Notify("Name field is blank.", NOTIFY_ERROR)
						parent.FileName:SelectAllOnFocus(true)
						parent.FileName:OnGetFocus()
						parent.FileName:RequestFocus()
						return
					end
					local desc = parent.Desc:GetValue()
					if (desc == "Description...") then
						desc = ""
					end
					AdvDupe2.SavePath = GetFullPath(node) .. name
					AddHistory(name)
					if (game.SinglePlayer()) then
						RunConsoleCommand("AdvDupe2_SaveFile", name, desc, GetNodePath(node))
					else
						RunConsoleCommand("AdvDupe2_SaveFile", name)
					end
					AdvDupe2.FileBrowser:Slide(false)
				end
				parent.FileName.OnEnter =
					function()
						parent.FileName:KillFocus()
						parent.Desc:SelectAllOnFocus(true)
						parent.Desc.OnMousePressed()
						parent.Desc:RequestFocus()
					end
				parent.Desc.OnEnter = parent.Submit.DoClick
			end)
		end
		Menu:AddOption("New Folder", function()
			if (parent.Expanding) then return end
			parent.Submit:SetMaterial("icon16/folder_add.png")
			parent.Submit:SetTooltip("Add new folder")
			if (parent.FileName:GetValue() == "File_Name...") then
				parent.FileName:SetText("Folder_Name...")
			end
			parent.Desc:SetVisible(false)
			parent.Info:SetVisible(false)
			parent.FileName.FirstChar = true
			parent.FileName.PrevText = parent.FileName:GetValue()
			parent.FileName:SetVisible(true)
			parent.FileName:SelectAllOnFocus(true)
			parent.FileName:OnMousePressed()
			parent.FileName:RequestFocus()
			parent.Expanding = true
			AdvDupe2.FileBrowser:Slide(true)
			parent.Submit.DoClick = function() AddNewFolder(node) end
			parent.FileName.OnEnter = parent.Submit.DoClick
		end)
		Menu:AddOption("Search", function()
			parent.Submit:SetMaterial("icon16/find.png")
			parent.Submit:SetTooltip("Search Files")
			if (parent.FileName:GetValue() == "Folder_Name...") then
				parent.FileName:SetText("File_Name...")
			end
			parent.Desc:SetVisible(false)
			parent.Info:SetVisible(false)
			parent.FileName.FirstChar = true
			parent.FileName.PrevText = parent.FileName:GetValue()
			parent.FileName:SetVisible(true)
			parent.FileName:SelectAllOnFocus(true)
			parent.FileName:OnMousePressed()
			parent.FileName:RequestFocus()
			parent.Expanding = true
			AdvDupe2.FileBrowser:Slide(true)
			parent.Submit.DoClick = function()
				Search(node, string.lower(parent.FileName:GetValue()))
				AddHistory(parent.FileName:GetValue())
				parent.FileName:SetVisible(false)
				parent.Submit:SetMaterial("icon16/arrow_undo.png")
				parent.Submit:SetTooltip("Return to Browser")
				parent.Info:SetVisible(true)
				parent.Info:SetText(#parent.Search.pnlCanvas.Files ..
										' files found searching for, "' ..
										parent.FileName:GetValue() .. '"')
				parent.Info:SizeToContents()
				parent.Submit.DoClick = function()
					parent.Search:Remove()
					parent.Search = nil
					parent.Browser:SetVisible(true)
					AdvDupe2.FileBrowser:Slide(false)
					parent.Cancel:SetVisible(true)
				end
				parent.Cancel:SetVisible(false)
			end
			parent.FileName.OnEnter = parent.Submit.DoClick
		end)
		if (node.Label:GetText()[1] ~= "-") then
			Menu:AddOption("Delete", function()
				parent.Submit:SetMaterial("icon16/bin_empty.png")
				parent.Submit:SetTooltip("Delete Folder")
				parent.FileName:SetVisible(false)
				parent.Desc:SetVisible(false)
				if (#node.Label:GetText() > 22) then
					parent.Info:SetText(
						'Are you sure that you want to delete \nthe FOLDER, "' ..
							node.Label:GetText() .. '" \nfrom your CLIENT?')
				else
					parent.Info:SetText(
						'Are you sure that you want to delete \nthe FOLDER, "' ..
							node.Label:GetText() .. '" from your CLIENT?')
				end
				parent.Info:SizeToContents()
				parent.Info:SetVisible(true)
				AdvDupe2.FileBrowser:Slide(true)
				parent.Submit.DoClick = function()
					local path, area = GetNodePath(node)
					if (area == 1) then
						path = "-Public-/" .. path
					end
					if (area == 2) then
						path = "adv_duplicator/" .. path .. "/"
					else
						path = AdvDupe2.DataFolder .. "/" .. path .. "/"
					end
					node.Control:RemoveNode(node)
					DeleteFilesInFolders(path)
					AdvDupe2.FileBrowser:Slide(false)
				end
			end)
		end
	end
	if (not node.Control.Search) then
		Menu:AddSpacer()
		Menu:AddOption("Collapse Folder", function()
			if (node.ParentNode.ParentNode) then
				node.ParentNode:SetExpanded(false)
			end
		end)
		Menu:AddOption("Collapse Root", function() CollapseParentsComplete(node) end)
		if (parent.Expanded) then
			Menu:AddOption("Cancel Action", function() parent.Cancel:DoClick() end)
		end
	end

	Menu:Open()
end

local function CollapseParents(node, val)
	if (not node) then return end
	node.ChildList:SetTall(node.ChildList:GetTall() - val)
	CollapseParents(node.ParentNode, val)
end

function BROWSER:RemoveNode(node)
	local parent = node.ParentNode
	parent.Nodes = parent.Nodes - 1
	if (node.IsFolder) then
		if (node.m_bExpanded) then
			CollapseParents(parent, node.ChildList:GetTall() + 20)
			for i = 1, #parent.ChildrenExpanded do
				if (node == parent.ChildrenExpanded[i]) then
					table.remove(parent.ChildrenExpanded, i)
					break
				end
			end
		elseif (parent.m_bExpanded) then
			CollapseParents(parent, 20)
		end
		for i = 1, #parent.Folders do
			if (node == parent.Folders[i]) then
				table.remove(parent.Folders, i)
			end
		end
		node.ChildList:Remove()
		node:Remove()
	else
		for i = 1, #parent.Files do
			if (node == parent.Files[i]) then
				table.remove(parent.Files, i)
			end
		end
		CollapseParents(parent, 20)
		node:Remove()
		if (#parent.Files == 0 and #parent.Folders == 0) then
			parent.Expander:Remove()
			parent.Expander = nil
			parent.m_bExpanded = false
		end
	end
	if (self.VBar.Scroll > self.VBar.CanvasSize) then
		self.VBar:SetScroll(self.VBar.Scroll)
	end
	if (self.m_pSelectedItem) then
		self.m_pSelectedItem = nil
	end
end

function BROWSER:OnMouseWheeled(dlta)
	return self.VBar:OnMouseWheeled(dlta)
end

function BROWSER:AddFolder(text)
	local node = vgui.Create("advdupe2_browser_folder", self)
	node.Control = self

	node.Offset = 0
	node.ChildrenExpanded = {}
	node.Icon:SetPos(18, 1)
	node.Label:SetPos(44, 0)
	node.Label:SetText(text)
	node.Label:SizeToContents()
	node.ParentNode = self
	node.IsFolder = true
	self.Nodes = self.Nodes + 1
	node.Folders = {}
	node.Files = {}
	table.insert(self.Folders, node)
	self:SetTall(self:GetTall() + 20)

	return node
end

function BROWSER:AddFile(text)
	local node = vgui.Create("advdupe2_browser_file", self)
	node.Control = self
	node.Offset = 0
	node.Icon:SetPos(18, 1)
	node.Label:SetPos(44, 0)
	node.Label:SetText(text)
	node.Label:SizeToContents()
	node.ParentNode = self
	self.Nodes = self.Nodes + 1
	table.insert(self.Files, node)
	self:SetTall(self:GetTall() + 20)

	return node
end

function BROWSER:Sort(node)
	tableSortNodes(node.Folders)
	tableSortNodes(node.Files)

	for i = 1, #node.Folders do
		node.Folders[i]:SetParent(nil)
		node.Folders[i]:SetParent(node.ChildList)
		node.Folders[i].ChildList:SetParent(nil)
		node.Folders[i].ChildList:SetParent(node.ChildList)
	end
	for i = 1, #node.Files do
		node.Files[i]:SetParent(nil)
		node.Files[i]:SetParent(node.ChildList)
	end
end

function BROWSER:SetSelected(node)
	if (IsValid(self.m_pSelectedItem)) then
		self.m_pSelectedItem:SetSelected(false)
	end
	self.m_pSelectedItem = node
	if (node) then node:SetSelected(true) end
end

local function ExpandParents(node, val)
	if (not node) then return end
	node.ChildList:SetTall(node.ChildList:GetTall() + val)
	ExpandParents(node.ParentNode, val)
end

function BROWSER:Expand(node)
	node.ChildList:SetTall(node.Nodes * 20)
	table.insert(node.ParentNode.ChildrenExpanded, node)
	ExpandParents(node.ParentNode, node.Nodes * 20)
end

local function ExtendParents(node)
	if (not node) then return end
	node.ChildList:SetTall(node.ChildList:GetTall() + 20)
	ExtendParents(node.ParentNode)
end

function BROWSER:Extend(node)
	node.ChildList:SetTall(node.ChildList:GetTall() + 20)
	ExtendParents(node.ParentNode)
end

function BROWSER:Collapse(node)
	CollapseParents(node.ParentNode, node.ChildList:GetTall())

	for i = 1, #node.ParentNode.ChildrenExpanded do
		if (node.ParentNode.ChildrenExpanded[i] == node) then
			table.remove(node.ParentNode.ChildrenExpanded, i)
			break
		end
	end
	CollapseChildren(node)
end

function BROWSER:RenameNode(name)
	self.ActionNode.Label:SetText(name)
	self.ActionNode.Label:SizeToContents()
	self:Sort(self.ActionNode.ParentNode)
end

function BROWSER:MoveNode(name)
	self:RemoveNode(self.ActionNode)
	self.ActionNode2:AddFile(name)
	self:Sort(self.ActionNode2)
end

function BROWSER:DeleteNode()
	self:RemoveNode(self.ActionNode)
end

derma.DefineControl("advdupe2_browser_tree", "AD2 File Browser", BROWSER, "Panel")

local FOLDER = {}

AccessorFunc(FOLDER, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(FOLDER, "m_bgColor", "BackgroundColor")

Derma_Hook(FOLDER, "Paint", "Paint", "Panel")

function FOLDER:Init()
	self:SetMouseInputEnabled(true)

	self:SetTall(20)
	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetBackgroundColor(Color(0, 0, 0, 0))

	self.Icon = vgui.Create("DImage", self)
	self.Icon:SetImage("icon16/folder.png")

	self.Icon:SizeToContents()

	self.Label = vgui.Create("DLabel", self)
	self.Label:SetDark(true)

	self.m_bExpanded = false
	self.Nodes = 0
	self.ChildrenExpanded = {}

	self:Dock(TOP)

	self.ChildList = vgui.Create("Panel", self:GetParent())
	self.ChildList:Dock(TOP)
	self.ChildList:SetTall(0)
end

local function ExpandNode(self)
	self:GetParent():SetExpanded()
end

function FOLDER:AddFolder(text)
	if (self.Nodes == 0) then
		self.Expander = vgui.Create("DExpandButton", self)
		self.Expander.DoClick = ExpandNode
		self.Expander:SetPos(self.Offset, 2)
	end

	local node = vgui.Create("advdupe2_browser_folder", self.ChildList)
	node.Control = self.Control

	node.Offset = self.Offset + 20

	node.Icon:SetPos(18 + node.Offset, 1)
	node.Label:SetPos(44 + node.Offset, 0)
	node.Label:SetText(text)
	node.Label:SizeToContents()
	node.Label:SetDark(true)
	node.ParentNode = self
	node.IsFolder = true
	node.Folders = {}
	node.Files = {}

	self.Nodes = self.Nodes + 1
	table.insert(self.Folders, node)

	if (self.m_bExpanded) then
		self.Control:Extend(self)
	end

	return node
end

function FOLDER:AddFile(text)
	if (self.Nodes == 0) then
		self.Expander = vgui.Create("DExpandButton", self)
		self.Expander.DoClick = ExpandNode
		self.Expander:SetPos(self.Offset, 2)
	end

	local node = vgui.Create("advdupe2_browser_file", self.ChildList)
	node.Control = self.Control
	node.Offset = self.Offset + 20
	node.Icon:SetPos(18 + node.Offset, 1)
	node.Label:SetPos(44 + node.Offset, 0)
	node.Label:SetText(text)
	node.Label:SizeToContents()
	node.Label:SetDark(true)
	node.ParentNode = self

	self.Nodes = self.Nodes + 1
	table.insert(self.Files, node)

	if (self.m_bExpanded) then
		self.Control:Extend(self)
	end

	return node
end

function FOLDER:SetExpanded(bool)
	if (not self.Expander) then return end
	if (bool == nil) then
		self.m_bExpanded = not self.m_bExpanded
	else
		self.m_bExpanded = bool
	end
	self.Expander:SetExpanded(self.m_bExpanded)
	if (self.m_bExpanded) then
		self.Control:Expand(self)
	else
		self.Control:Collapse(self)
	end
end

function FOLDER:SetSelected(bool)
	if (bool) then
		self:SetBackgroundColor(self:GetSkin().bg_color_bright)
	else
		self:SetBackgroundColor(Color(0, 0, 0, 0))
	end
end

function FOLDER:OnMousePressed(code)
	if (code == 107) then
		self.Control:DoNodeLeftClick(self)
	elseif (code == 108) then
		self.Control:DoNodeRightClick(self)
	end
end

derma.DefineControl("advdupe2_browser_folder", "AD2 Browser Folder node", FOLDER, "Panel")

local FILE = {}

AccessorFunc(FILE, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(FILE, "m_bgColor", "BackgroundColor")
Derma_Hook(FILE, "Paint", "Paint", "Panel")

function FILE:Init()
	self:SetMouseInputEnabled(true)

	self:SetTall(20)
	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetBackgroundColor(Color(0, 0, 0, 0))

	self.Icon = vgui.Create("DImage", self)
	self.Icon:SetImage("icon16/page.png")

	self.Icon:SizeToContents()

	self.Label = vgui.Create("DLabel", self)
	self.Label:SetDark(true)

	self:Dock(TOP)
end

function FILE:SetSelected(bool)
	if (bool) then
		self:SetBackgroundColor(self:GetSkin().bg_color_bright)
	else
		self:SetBackgroundColor(Color(0, 0, 0, 0))
	end
end

function FILE:OnMousePressed(code)
	if (code == 107) then
		self.Control:DoNodeLeftClick(self)
	elseif (code == 108) then
		self.Control:DoNodeRightClick(self)
	end
end

derma.DefineControl("advdupe2_browser_file", "AD2 Browser File node", FILE, "Panel")

local PANEL = {}
AccessorFunc(PANEL, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(PANEL, "m_bgColor", "BackgroundColor")
Derma_Hook(PANEL, "Paint", "Paint", "Panel")
Derma_Hook(PANEL, "PerformLayout", "Layout", "Panel")

function PANEL:PerformLayout()
	if (self:GetWide() == self.LastX) then return end
	local x = self:GetWide()

	if (self.Search) then
		self.Search:SetWide(x)
	end

	self.Browser:SetWide(x)
	local x2, y2 = self.Browser:GetPos()
	local BtnX = x - self.Help:GetWide() - 5
	self.Help:SetPos(BtnX, 3)
	BtnX = BtnX - self.Refresh:GetWide() - 5
	self.Refresh:SetPos(BtnX, 3)

	BtnX = x - self.Submit:GetWide() - 15
	self.Cancel:SetPos(BtnX, self.Browser:GetTall() + 20)
	BtnX = BtnX - self.Submit:GetWide() - 5
	self.Submit:SetPos(BtnX, self.Browser:GetTall() + 20)

	self.FileName:SetWide(BtnX - 10)
	self.FileName:SetPos(5, self.Browser:GetTall() + 20)
	self.Desc:SetWide(x - 10)
	self.Desc:SetPos(5, self.Browser:GetTall() + 39)
	self.Info:SetPos(5, self.Browser:GetTall() + 20)

	self.LastX = x
end

local pnlorigsetsize
local function PanelSetSize(self, x, y)
	if (not self.LaidOut) then
		pnlorigsetsize(self, x, y)

		self.Browser:SetSize(x, y - 20)
		self.Browser:SetPos(0, 20)

		if (self.Search) then
			self.Search:SetSize(x, y - 20)
			self.Search:SetPos(0, 20)
		end

		self.LaidOut = true
	else
		pnlorigsetsize(self, x, y)
	end

end

local function PurgeFiles(path, curParent)
	local files, directories = file.Find(path .. "*", "DATA")
	if (directories) then
		for k, v in pairs(directories) do
			curParent = curParent:AddFolder(v)
			PurgeFiles(path .. v .. "/", curParent)
			curParent = curParent.ParentNode
		end
	end

	if (files) then
		for k, v in pairs(files) do
			curParent:AddFile(string.sub(v, 1, #v - 4))
		end
	end
end

local function UpdateClientFiles()

	local pnlCanvas = AdvDupe2.FileBrowser.Browser.pnlCanvas

	for i = 1, 2 do
		if (pnlCanvas.Folders[1]) then
			pnlCanvas:RemoveNode(pnlCanvas.Folders[1])
		end
	end

	PurgeFiles("advdupe2/", pnlCanvas:AddFolder("-Advanced Duplicator 2-"))

	PurgeFiles("adv_duplicator/", pnlCanvas:AddFolder("-Advanced Duplicator 1-"))

	if (pnlCanvas.Folders[2]) then
		if (#pnlCanvas.Folders[2].Folders == 0 and #pnlCanvas.Folders[2].Files == 0) then
			pnlCanvas:RemoveNode(pnlCanvas.Folders[2])
		end

		pnlCanvas.Folders[1]:SetParent(nil)
		pnlCanvas.Folders[1]:SetParent(pnlCanvas.ChildList)
		pnlCanvas.Folders[1].ChildList:SetParent(nil)
		pnlCanvas.Folders[1].ChildList:SetParent(pnlCanvas.ChildList)
	end

end

function PANEL:Init()

	AdvDupe2.FileBrowser = self
	self.Expanded = false
	self.Expanding = false
	self.LastX = 0
	self.LastY = 0
	pnlorigsetsize = self.SetSize
	self.SetSize = PanelSetSize

	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetBackgroundColor(self:GetSkin().bg_color_bright)

	self.Browser = vgui.Create("advdupe2_browser_panel", self)
	UpdateClientFiles()
	self.Refresh = vgui.Create("DImageButton", self)
	self.Refresh:SetMaterial("icon16/arrow_refresh.png")
	self.Refresh:SizeToContents()
	self.Refresh:SetTooltip("Refresh Files")
	self.Refresh.DoClick = function(button) UpdateClientFiles() end

	self.Help = vgui.Create("DImageButton", self)
	self.Help:SetMaterial("icon16/help.png")
	self.Help:SizeToContents()
	self.Help:SetTooltip("Help Section")
	self.Help.DoClick = function(btn)
		local Menu = DermaMenu()
		Menu:AddOption("Bug Reporting", function()
			gui.OpenURL("https://github.com/wiremod/advdupe2/issues")
		end)
		Menu:AddOption("Controls", function()
			gui.OpenURL("https://github.com/wiremod/advdupe2/wiki/Controls")
		end)
		Menu:AddOption("Commands", function()
			gui.OpenURL(
				"https://github.com/wiremod/advdupe2/wiki/Server-settings")
		end)
		Menu:Open()
	end

	self.Submit = vgui.Create("DImageButton", self)
	self.Submit:SetMaterial("icon16/page_save.png")
	self.Submit:SizeToContents()
	self.Submit:SetTooltip("Confirm Action")
	self.Submit.DoClick = function()
		self.Expanding = true
		AdvDupe2.FileBrowser:Slide(false)
	end

	self.Cancel = vgui.Create("DImageButton", self)
	self.Cancel:SetMaterial("icon16/cross.png")
	self.Cancel:SizeToContents()
	self.Cancel:SetTooltip("Cancel Action")
	self.Cancel.DoClick = function()
		self.Expanding = true
		AdvDupe2.FileBrowser:Slide(false)
	end

	self.FileName = vgui.Create("DTextEntry", self)
	self.FileName:SetAllowNonAsciiCharacters(true)
	self.FileName:SetText("File_Name...")
	self.FileName.Last = 0

	self.FileName.OnEnter = function()
		self.FileName:KillFocus()
		self.Desc:SelectAllOnFocus(true)
		self.Desc.OnMousePressed()
		self.Desc:RequestFocus()
	end
	self.FileName.OnMousePressed = function()
		self.FileName:OnGetFocus()
		if (self.FileName:GetValue() == "File_Name..." or
			self.FileName:GetValue() == "Folder_Name...") then
			self.FileName:SelectAllOnFocus(true)
		end
	end
	self.FileName:SetUpdateOnType(true)
	self.FileName.OnTextChanged = function()

		if (self.FileName.FirstChar) then
			if (string.lower(self.FileName:GetValue()[1] or "") ==
				string.lower(input.LookupBinding("menu"))) then
				self.FileName:SetText(self.FileName.PrevText)
				self.FileName:SelectAll()
				self.FileName.FirstChar = false
			else
				self.FileName.FirstChar = false
			end
		end

		local new, changed = self.FileName:GetValue():gsub("[^%w_ ]", "")
		if changed > 0 then
			self.FileName:SetText(new)
			self.FileName:SetCaretPos(#new)
		end
		if (#self.FileName:GetValue() > 0) then
			NarrowHistory(self.FileName:GetValue(), self.FileName.Last)
			local options = {}
			if (#Narrow > 4) then
				for i = 1, 4 do table.insert(options, Narrow[i]) end
			else
				options = Narrow
			end
			if (#options ~= 0 and #self.FileName:GetValue() ~= 0) then
				self.FileName.HistoryPos = 0
				self.FileName:OpenAutoComplete(options)
				self.FileName.Menu.Attempts = 1
				if (#Narrow > 4) then
					self.FileName.Menu:AddOption("...", function() end)
				end
			elseif (IsValid(self.FileName.Menu)) then
				self.FileName.Menu:Remove()
			end
		end
		self.FileName.Last = #self.FileName:GetValue()
	end
	self.FileName.OnKeyCodeTyped = function(txtbox, code)
		txtbox:OnKeyCode(code)

		if (code == KEY_ENTER and not txtbox:IsMultiline() and txtbox:GetEnterAllowed()) then
			if (txtbox.HistoryPos == 5 and txtbox.Menu:ChildCount() == 5) then
				if ((txtbox.Menu.Attempts + 1) * 4 < #Narrow) then
					for i = 1, 4 do
						txtbox.Menu:GetChild(i):SetText(Narrow[i + txtbox.Menu.Attempts * 4])
					end
				else
					txtbox.Menu:GetChild(5):Remove()
					for i = 4, (txtbox.Menu.Attempts * 4 - #Narrow) * -1 + 1, -1 do
						txtbox.Menu:GetChild(i):Remove()
					end

					for i = 1, #Narrow - txtbox.Menu.Attempts * 4 do
						txtbox.Menu:GetChild(i):SetText(Narrow[i + txtbox.Menu.Attempts * 4])
					end
				end
				txtbox.Menu:ClearHighlights()
				txtbox.Menu:HighlightItem(txtbox.Menu:GetChild(1))
				txtbox.HistoryPos = 1
				txtbox.Menu.Attempts = txtbox.Menu.Attempts + 1
				return true
			end

			if (IsValid(txtbox.Menu)) then
				txtbox.Menu:Remove()
			end
			txtbox:FocusNext()
			txtbox:OnEnter()
			txtbox.HistoryPos = 0
		end

		if (txtbox.m_bHistory or IsValid(txtbox.Menu)) then
			if (code == KEY_UP) then
				txtbox.HistoryPos = txtbox.HistoryPos - 1;
				if (txtbox.HistoryPos ~= -1 or txtbox.Menu:ChildCount() ~= 5) then
					txtbox:UpdateFromHistory()
				else
					txtbox.Menu:ClearHighlights()
					txtbox.Menu:HighlightItem(txtbox.Menu:GetChild(5))
					txtbox.HistoryPos = 5
				end
			end
			if (code == KEY_DOWN or code == KEY_TAB) then
				txtbox.HistoryPos = txtbox.HistoryPos + 1;
				if (txtbox.HistoryPos ~= 5 or txtbox.Menu:ChildCount() ~= 5) then
					txtbox:UpdateFromHistory()
				else
					txtbox.Menu:ClearHighlights()
					txtbox.Menu:HighlightItem(txtbox.Menu:GetChild(5))
				end
			end

		end
	end
	self.FileName.OnValueChange = function()
		if (self.FileName:GetValue() ~= "File_Name..." and
			self.FileName:GetValue() ~= "Folder_Name...") then
			local new, changed = self.FileName:GetValue():gsub("[^%w_ ]", "")
			if changed > 0 then
				self.FileName:SetText(new)
				self.FileName:SetCaretPos(#new)
			end
		end
	end

	self.Desc = vgui.Create("DTextEntry", self)
	self.Desc.OnEnter = self.Submit.DoClick
	self.Desc:SetText("Description...")
	self.Desc.OnMousePressed = function()
		self.Desc:OnGetFocus()
		if (self.Desc:GetValue() == "Description...") then
			self.Desc:SelectAllOnFocus(true)
		end
	end

	self.Info = vgui.Create("DLabel", self)
	self.Info:SetVisible(false)

end

function PANEL:Slide(expand)
	if (expand) then
		if (self.Expanded) then
			self:SetTall(self:GetTall() - 40)
			self.Expanded = false
		else
			self:SetTall(self:GetTall() + 5)
		end
	else
		if (not self.Expanded) then
			self:SetTall(self:GetTall() + 40)
			self.Expanded = true
		else
			self:SetTall(self:GetTall() - 5)
		end
	end
	count = count + 1
	if (count < 9) then
		timer.Simple(0.01, function() self:Slide(expand) end)
	else
		if (expand) then
			self.Expanded = true
		else
			self.Expanded = false
		end
		self.Expanding = false
		count = 0
	end
end

function PANEL:GetFullPath(node)
	return GetFullPath(node)
end

function PANEL:GetNodePath(node)
	return GetNodePath(node)
end

if (game.SinglePlayer()) then
	net.Receive("AdvDupe2_AddFile", function()
		local asvNode = AdvDupe2.FileBrowser.AutoSaveNode
		local actNode = AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode
		if (net.ReadBool()) then
			if (IsValid(asvNode)) then
				local name = net.ReadString()
				for iD = 1, #asvNode.Files do
					if (name == asvNode.Files[i]) then return end
				end
				asvNode:AddFile(name)
				asvNode.Control:Sort(asvNode)
			end
		else
			actNode:AddFile(net.ReadString())
			actNode.Control:Sort(actNode)
		end
	end)
end

vgui.Register("advdupe2_browser", PANEL, "Panel")
