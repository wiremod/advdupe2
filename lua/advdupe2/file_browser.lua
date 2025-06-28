--[[
	Title: Adv. Dupe 2 File Browser

	Desc: Displays and interfaces with duplication files.

	Authors: March (v2.0), TB (v1.0)

	Version: 2.0
]]

-- Enums
local ADVDUPE2_AREA_ADVDUPE2   = AdvDupe2.AREA_ADVDUPE2
local ADVDUPE2_AREA_PUBLIC     = AdvDupe2.AREA_PUBLIC
local ADVDUPE2_AREA_ADVDUPE1   = AdvDupe2.AREA_ADVDUPE1
local ADVDUPE2_NODETYPE_FOLDER = AdvDupe2.NODETYPE_FOLDER
local ADVDUPE2_NODETYPE_FILE   = AdvDupe2.NODETYPE_FILE

local History = {}
local Narrow = {}

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
	-- self.pnlCanvas:SetPos(0, iOffset)
end

derma.DefineControl("advdupe2_browser_panel", "AD2 File Browser", BROWSERPNL, "Panel")























































local NODE_MT = {}
local NODE    = setmetatable({}, NODE_MT)

function NODE:Init(Type, Browser)
	self.Type      = Type
	self.Browser   = Browser
	self.Files     = {}
	self.Folders   = {}
	self.Sorted    = {}
	self.Expanded  = false
	self.Selected  = false

	self:MarkSortDirty()
end

function NODE_MT:__call(Type, Browser)
	if Type == nil then return error("Cannot create typeless node") end
	if not IsValid(Browser) then return error ("Cannot create a headless node (we need a browser)") end

	local Node   = setmetatable({}, {__index = NODE})
	Node:Init(Type, Browser)

	return Node
end

function NODE:IsRoot()   return (self.Root or error("No root?")) == self end
function NODE:IsFolder() return self.Type == ADVDUPE2_NODETYPE_FOLDER    end
function NODE:IsFile()   return self.Type == ADVDUPE2_NODETYPE_FILE      end

function NODE:AddFolder(Text)
	local Node = NODE(ADVDUPE2_NODETYPE_FOLDER, self.Browser)
	Node.Text = Text
	Node.ParentNode = self
	Node.Root = self.Root
	if self.Expanded then self:MarkSortDirty() end
	self.Folders[#self.Folders + 1] = Node

	return Node
end

function NODE:AddFile(Text)
	local Node = NODE(ADVDUPE2_NODETYPE_FILE, self.Browser)
	Node.Text = Text
	Node.ParentNode = self
	Node.Root = self.Root
	if self.Expanded then self:MarkSortDirty() end
	self.Files[#self.Files + 1] = Node

	return Node
end

function NODE:Count() return #self.Files + #self.Folders end

function NODE:MarkSortDirty()
	self.SortDirty         = true
	self.Browser.SortDirty = true
end

function NODE:Clear()
	table.Empty(self.Files)
	table.Empty(self.Folders)
	table.Empty(self.Sorted)
	self:MarkSortDirty()
end

function NODE:RemoveNode(Node)
	if Node:IsFolder() then
		table.RemoveByValue(self.Folders, Node)
	else
		table.RemoveByValue(self.Files, Node)
	end

	self:MarkSortDirty()
end

function NODE:Remove()
	local ParentNode = self.ParentNode

	if ParentNode then
		ParentNode:RemoveNode(self)
	else
		self:MarkSortDirty()
	end
end

function NODE:SetExpanded(Expanded)
	if Expanded == self.Expanded then return end

	self.Expanded = Expanded
	self:MarkSortDirty()
end

function NODE:Expand()         self:SetExpanded(true)              end
function NODE:Collapse()       self:SetExpanded(false)             end
function NODE:ToggleExpanded() self:SetExpanded(not self.Expanded) end

local function SetupDataFile(Node, Path, Name)
	Node.Text = Name
	Node.Path = Path
end

local function SetupDataSubfolder(Node, Path, Name)
	Node.Text = Name
	Node.Path = Path
end

-- Expects a directory path ending in a forward slash.
local LoadDataFolderInternal
function LoadDataFolderInternal(Node, Path)
	local Files, Directories = file.Find(Path .. "*", "DATA", "nameasc")
	if not Files or not Directories then return end

	for _, File in ipairs(Files) do
		local FilePath = Path .. File
		local FileNode = Node:AddFile(FilePath)
		SetupDataFile(FileNode, FilePath, File)
	end

	for _, Directory in ipairs(Directories) do
		local DirectoryPath = Path .. Directory
		local DirectoryNode = Node:AddFolder(DirectoryPath)
		SetupDataSubfolder(DirectoryNode, DirectoryPath, Directory)
		DirectoryNode.FirstObserved = function(DirNode) -- note FirstObserved will be destroyed after first call
			LoadDataFolderInternal(DirNode, DirectoryPath .. "/")
		end
	end
end


function NODE:LoadDataFolder(Path)
	self:Clear()
	LoadDataFolderInternal(self, Path)
end

-- Defines GetNumericalFilename
-- May need optimization and refactoring later - especially for non-ASCII strings...
-- This handles things very similarly to how Windows does in terms of sorting, but also adds sorting by month
-- May also be a good idea in the future to add a setting for the above functionality.
local GetNumericalFilename
do
	local isDigit = {
		['0'] = 0,
		['1'] = 1,
		['2'] = 2,
		['3'] = 3,
		['4'] = 4,
		['5'] = 5,
		['6'] = 6,
		['7'] = 7,
		['8'] = 8,
		['9'] = 9
	}

	-- faster than string.byte calls
	local char2byte = {}
	for i = 1, 255 do char2byte[string.char(i)] = string.byte(string.lower(string.char(i))) end
	char2byte['_'] = 2000

	local buildMonth = {}
	for k, v in ipairs{"january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"} do
		local tbl = buildMonth
		for i = 1, #v do
			local c = v[i]
			if i == #v then
				tbl[c] = k
			else
				if not tbl[c] then
					tbl[c] = {}
				end

				tbl = tbl[c]
			end
		end
	end

	local numericalStore = {}
	function GetNumericalFilename(name)
		if numericalStore[name] then return numericalStore[name] end

		local ret = {}
		local digit = nil
		local monthTester = buildMonth
		local monthStoreJustInCase = {}

		for i = 1, #name do
			local c = name[i]
			local cIsDigit = isDigit[c]
			if cIsDigit then
				if digit == nil then
					digit = 0
				end
				digit = (digit * 10) + cIsDigit
			else
				if monthTester[c] then
					monthTester = monthTester[c]
					monthStoreJustInCase[#monthStoreJustInCase + 1] = char2byte[c]
					if type(monthTester) == "number" then
						local nextC = name[i + 1]
						local nextIfine = nextC == ' ' or nextC == '_' or nextC == '-'
						if i == #name or nextIfine then
							ret[#ret + 1] = monthTester
							monthStoreJustInCase = {}
							monthTester = buildMonth
							if nextIfine then
								i = i + 1
							end
						else
							for i = 1, #monthStoreJustInCase do
								ret[#ret + 1] = monthStoreJustInCase[i]
							end
							monthStoreJustInCase = {}
							monthTester = buildMonth
						end
					end
				elseif digit ~= nil then
					ret[#ret + 1] = digit - (#ret == 0 and 100000000 or 0)
					digit = nil
				else
					if monthTester ~= buildMonth then
						for i = 1, #monthStoreJustInCase do
							ret[#ret + 1] = monthStoreJustInCase[i]
						end
						monthStoreJustInCase = {}
						monthTester = buildMonth
					end
					ret[#ret + 1] = char2byte[c]
				end
			end
		end

		if digit ~= nil then
			ret[#ret + 1] = digit - (#ret == 0 and 100000000 or 0)
		end
		if monthTester ~= buildMonth then
			for i = 1, #monthStoreJustInCase do
				ret[#ret + 1] = monthStoreJustInCase[i]
			end
		end

		numericalStore[name] = ret -- store so this doesnt have to be calculated multiple times for no reason
		return ret
	end
end

function NODE.SortFunction(A, B)
	local IsFileA, IsFileB = A:IsFile(), B:IsFile()

	if not IsFileA and IsFileB then return true end
	if IsFileA and not IsFileB then return false end

	local NameA, NameB = GetNumericalFilename(string.StripExtension(A.Text)), GetNumericalFilename(string.StripExtension(B.Text))

	for I = 1, math.max(#NameA, #NameB) do
		local AC, BC = NameA[I], NameB[I]

		if AC == nil then return true end
		if BC == nil then return false end

		if AC ~= BC then
			return AC < BC
		end
	end
end

function NODE:PerformResort()
	if not self.SortDirty then return end

	local Sorted   = self.Sorted
	local Files    = self.Files
	local Folders  = self.Folders
	table.Empty(Sorted)

	for I = 1, #Files   do Sorted[#Sorted + 1] = Files[I]   end
	for I = 1, #Folders do Sorted[#Sorted + 1] = Folders[I] end

	-- For each node, check FirstObserved and call if it exists
	for _, Node in ipairs(Sorted) do
		if Node.FirstObserved then
			Node:FirstObserved()
			Node.FirstObserved = nil
		end
	end

	-- Perform actual resort
	table.sort(Sorted, self.SortFunction)
end

-- Returns an enumerator<Node>
function NODE:GetSortedChildNodes()
	self:PerformResort()
	return ipairs(self.Sorted)
end

function NODE.InjectIntoBrowser(Browser)
	for FuncName, Func in pairs(NODE) do
		Browser[FuncName] = Func
	end

	NODE.Init(Browser, ADVDUPE2_NODETYPE_FOLDER, Browser)
end




-- This interface describes the logic behind a root folder (like AdvDupe1 or AdvDupe2).

local IRootFolder_MT = {}
local IRootFolder    = setmetatable({}, IRootFolder_MT)
AdvDupe2.IRootFolder = IRootFolder -- If other addons want to post-verify their IRootFolder implementations like we do

-- todo; debug.getinfo and determine argument counts to further sanity check?
IRootFolder.Init             = function(Impl, Browser, Node) end
IRootFolder.GetFolderName    = function(Impl) end
-- These define node operations
-- These are RAW operations, as in the underlying Browser might do some prompts first
-- But for example, calling IRootFolder:UserDelete() is expected to actually delete the node
-- (and the browser will create the prompt)
IRootFolder.UserUpload       = function(Impl, Browser, Node) end
IRootFolder.UserPreview      = function(Impl, Browser, Node) end
IRootFolder.UserSave         = function(Impl, Browser, Node, Filename, Description) end
IRootFolder.UserRename       = function(Impl, Browser, Node, RenameTo) end
IRootFolder.UserMenu         = function(Impl, Browser, Node, Menu) end
IRootFolder.UserDelete       = function(Impl, Browser, Node) end

-- Ensures the implementor implemented the interface correctly
-- if they didn't throw non-halting errors since it might be an optional method
function IRootFolder_MT:__call(RootFolderType)
	for FuncName, _ in pairs(IRootFolder) do
		if not RootFolderType[FuncName] then
			ErrorNoHaltWithStack("AdvDupe2: IRootFolder implementation failed to implement " .. FuncName .. ", this may not work as intended...")
		end
	end

	return RootFolderType
end












-- This turns a data-folder path name into something AdvDupe2.UploadFile can tolerate
local function GetNodeDataPath(Node)
	local Path                = Node.Path
	local FirstSlash          = string.find(Path, "/")
	local RemovedFirstDirPath = string.sub(Path, FirstSlash + 1)
	return string.StripExtension(RemovedFirstDirPath)
end

-- wraps File.Exists and throws a notification
local function FileExists(Path)
	if not Path then
		AdvDupe2.Notify("Expected path, got nil!")
		return false
	end

	if not file.Exists(Path, "DATA") then
		AdvDupe2.Notify("File '" .. Path .. "' does not exist.")
		return false
	end

	return true
end

local function OpenPreview(Node, Area)
	local Path     = GetNodeDataPath(Node)
	local ReadPath

	if Area == ADVDUPE2_AREA_ADVDUPE2 then
		ReadPath = AdvDupe2.DataFolder .. "/" .. Path .. ".txt"
	elseif Area == ADVDUPE2_AREA_PUBLIC then
		ReadPath = AdvDupe2.DataFolder .. "/-Public-/" .. ReadPath .. ".txt"
	else
		ReadPath = "adv_duplicator/" .. Path .. ".txt"
	end

	if not FileExists(ReadPath) then return end

	local Read = file.Read(ReadPath)
	local Name = string.StripExtension(string.GetFileFromFilename(Path))

	local Success, Dupe, Info, MoreInfo = AdvDupe2.Decode(Read)

	if Success then
		AdvDupe2.LoadGhosts(Dupe, Info, MoreInfo, Name, true)
	end
end



local AdvDupe1Folder, AdvDupe2Folder

do
	AdvDupe1Folder = {}
	function AdvDupe1Folder:GetFolderName() return "Advanced Duplicator 1" end
	function AdvDupe1Folder:Init(Browser, Node)
		Node:LoadDataFolder("adv_duplicator/")

		if Node:Count() < 0 then
			Node:Remove()
		end
	end

	function AdvDupe1Folder:UserUpload(Browser, Node)
		AdvDupe2.UploadFile(GetNodeDataPath(Node), ADVDUPE2_AREA_ADVDUPE1)
	end

	function AdvDupe1Folder:UserPreview(Browser, Node)
		OpenPreview(Node, ADVDUPE2_AREA_ADVDUPE1)
	end


	function AdvDupe1Folder:UserSave(Browser, Node, Filename, Description)

	end

	function AdvDupe1Folder:UserRename(Browser, Node, RenameTo)

	end

	function AdvDupe1Folder:UserMenu(Browser, Node, Menu)

	end

	function AdvDupe1Folder:UserDelete(Browser, Node)

	end

	IRootFolder(AdvDupe1Folder) -- validation
end

do
	AdvDupe2Folder = {}
	function AdvDupe2Folder:GetFolderName() return "Advanced Duplicator 2" end
	function AdvDupe2Folder:Init(Browser, Node)
		Node:LoadDataFolder("advdupe2/")
	end

	function AdvDupe2Folder:UserUpload(Browser, Node)
		AdvDupe2.UploadFile(GetNodeDataPath(Node), ADVDUPE2_AREA_ADVDUPE2)
	end

	function AdvDupe2Folder:UserPreview(Browser, Node)
		OpenPreview(Node, ADVDUPE2_AREA_ADVDUPE2)
	end

	function AdvDupe2Folder:UserSave(Browser, Node, Filename, Description)

	end

	function AdvDupe2Folder:UserRename(Browser, Node, RenameTo)

	end

	function AdvDupe2Folder:UserMenu(Browser, Node, Menu)
		if Node:IsFile() then
			Menu:AddOption("Open", function() self:UserUpload(Browser, Node) end, "icon16/page_go.png")
			Menu:AddOption("Preview", function() self:UserPreview(Browser, Node) end, "icon16/information.png")
			Menu:AddSpacer()
			Menu:AddOption("Rename...", nil, "icon16/textfield_rename.png")
			Menu:AddOption("Move...", nil, "icon16/arrow_right.png")
			Menu:AddOption("Delete", nil, "icon16/bin_closed.png")
		else
			Menu:AddOption("Save", nil, "icon16/disk.png")
			Menu:AddOption("New Folder", nil, "icon16/folder_add.png")
			Menu:AddSpacer()
			Menu:AddOption("Search", nil, "icon16/magnifier.png")
		end
	end

	function AdvDupe2Folder:UserDelete(Browser, Node)
		
	end

	IRootFolder(AdvDupe2Folder) -- validation
end
















local BROWSER = {}
AccessorFunc(BROWSER, "m_pSelectedItem", "SelectedItem")

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

	-- Implement NODE
	NODE.InjectIntoBrowser(self)
	self.SortDirty         = true
	self.ExpandedNodeArray = {}

	self.LastClick = CurTime()
end

function BROWSER:DoNodeLeftClick(Node)
	if self.m_pSelectedItem == Node and CurTime() - self.LastClick <= 0.25 then -- Check for double click
		if Node:IsFolder() then
			Node:ToggleExpanded()
		else
			local RootImpl = Node.Root.RootImpl
			RootImpl:UserUpload(self, Node)
		end
	else
		self:SetSelected(Node) -- A node was clicked, select it
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

	FilePath = AdvDupe2.SanitizeFilename(FilePath)
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

function BROWSER:DoNodeRightClick(Node)
	self:SetSelected(Node)

	local BrowserPanel = self:GetParent():GetParent()
	BrowserPanel.FileName:KillFocus()
	BrowserPanel.Desc:KillFocus()

	local Menu     = DermaMenu()
	local RootImpl = Node.Root.RootImpl

	function Menu:AddOption(Text, Func, Icon)
		local Option = DMenu.AddOption(self, Text, Func)
		if Icon then
			local IconPanel = Option:Add("DImage")
			IconPanel:SetImage(Icon)
			IconPanel:SetKeepAspect(true)
			IconPanel:SetSize(16, 16)
			local OldLayout = Option.PerformLayout
			function Option:PerformLayout(W, H)
				OldLayout(self, W, H)
				IconPanel:SetPos(6, (H / 2) - 8)
			end
		end
	end

	RootImpl:UserMenu(self, Node, Menu)

	Menu:SetAlpha(0)
	Menu:AlphaTo(255, 0.1, 0)
	Menu:Open()
end

local function CollapseParents(node, val)
	if (not node) then return end
	node.ChildList:SetTall(node.ChildList:GetTall() - val)
	CollapseParents(node.ParentNode, val)
end

function BROWSER:OnMouseWheeled(dlta)
	return self.VBar:OnMouseWheeled(dlta)
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
	if self.m_pSelectedItem then
		self.m_pSelectedItem.Selected = false
	end
	self.m_pSelectedItem = node
	if node then
		node.Selected = true
	end
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

local DoRecursiveVistesting function DoRecursiveVistesting(Parent, ExpandedNodeArray, Depth)
	Depth = Depth or 0
	for _, Child in Parent:GetSortedChildNodes() do
		Child.Depth = Depth
		ExpandedNodeArray[#ExpandedNodeArray + 1] = Child
		if Child.Expanded then
			DoRecursiveVistesting(Child, ExpandedNodeArray, Depth + 1)
		end
	end
end

-- Just in case this needs to be changed later
-- can't remember if this should be curtime or not...
local MaxTimeToDoubleClick   =   0.1
local NodeTall               =   24
local NodePadding            =   0
local TallOfOneNode          =   NodeTall + NodePadding
local NodeDepthWidth         =   12
local NodeFont               =   "DermaDefault"

local ICON_FOLDER_EMPTY     = Material("icon16/folder.png", "smooth")
local ICON_FOLDER_CONTAINS  = Material("icon16/folder_page.png", "smooth")
local ICON_FILE             = Material("icon16/page.png", "smooth")

-- This function collapses the current node state into a single sequential array
function BROWSER:SortRecheck()
	if not self.SortDirty then return end

	table.Empty(self.ExpandedNodeArray)
	DoRecursiveVistesting(self, self.ExpandedNodeArray)

	-- This is how tall we are
	local Tall = #self.ExpandedNodeArray * TallOfOneNode
	self:SetTall(Tall)

	self.SortDirty = false
end

-- Gets or creates the immediate state table.
function BROWSER:GetImmediateState()
	local ImmediateState = self.ImmediateState
	if not ImmediateState then
		ImmediateState = {}
		self.ImmediateState = ImmediateState
		ImmediateState.Mouse = {}

		-- functions

		function ImmediateState:IsMouseInRect(X, Y, W, H)
			local MX, MY         = self.MouseX or 0, self.MouseY or 0
			return (MX >= X and MX <= (X + W)) and (MY >= Y and MY <= (Y + H))
		end
	end

	return ImmediateState
end

local function GetNodeBounds(ScrollOffset, AbsIndex, Width, Depth)
	return
			Depth * NodeDepthWidth,
			(TallOfOneNode * (AbsIndex - 1)) - ScrollOffset,
			Width - (Depth * NodeDepthWidth),
			NodeTall
end

local ExpanderSize              = 16
local IconSize                  = 16
local LeftmostToExpanderPadding = 4
local ExpanderToIconPadding     = 4
local IconToTextPadding         = 6

local ExpanderXOffset = LeftmostToExpanderPadding
local IconXOffset     = ExpanderXOffset + ExpanderSize + ExpanderToIconPadding
local TextXOffset     = IconXOffset + IconSize + IconToTextPadding

local function GetExpanderBounds(X, Y, W, H, Padding, Depth)
	Padding = Padding or 0
	local Size = ExpanderSize + Padding

	return (Depth * NodeDepthWidth) + (X + ExpanderXOffset) - (Padding / 2), ((Y + (H / 2)) - (Size / 2)) + 1, Size, Size
end

local function GetIconBounds(X, Y, W, H, Padding, Depth)
	local Size = IconSize + (Padding or 0)

	return (Depth * NodeDepthWidth) + X + IconXOffset, (Y + (H / 2)) - (Size / 2), Size, Size
end

local function GetTextPosition(X, Y, W, H, Depth)
	return (Depth * NodeDepthWidth) + X + TextXOffset, Y + (H / 2)
end

-- This function flushes in the immediate-mode state from C-funcs into Lua-land
-- and performs calculations that may be needed later on in a cached state
-- The immediate state object is unique to the browser
function BROWSER:FlushImmediateState()
	local ImmediateState = self:GetImmediateState()

	local Scroll         = IsValid(self.VBar) and (self.VBar:GetScroll()) or 0

	local MouseX, MouseY = self:CursorPos()

	ImmediateState.Mouse.Cursor = "arrow"
	ImmediateState.LastScroll   = ImmediateState.Scroll or Scroll
	ImmediateState.Scroll       = Scroll
	ImmediateState.DeltaScroll  = Scroll - ImmediateState.LastScroll

	ImmediateState.Width        = self:GetWide()
	ImmediateState.Height       = self:GetTall()

	for I = MOUSE_LEFT, MOUSE_LAST do
		local Mouse = ImmediateState.Mouse[I]
		if not Mouse then
			Mouse = {}
			ImmediateState.Mouse[I] = Mouse
		end

		Mouse.LastDown = Mouse.Down or false
		Mouse.Down     = input.IsMouseDown(I)
		Mouse.Clicked  = Mouse.Down and not Mouse.LastDown
		Mouse.Released = not Mouse.Down and Mouse.LastDown

	end

	ImmediateState.Mouse.Down  = false
	ImmediateState.Mouse.Double = false
	ImmediateState.Mouse.Clicked = false
	ImmediateState.Mouse.Released = false
	-- Reverse priority. Left should have the highest precedence
	for I = MOUSE_LAST, MOUSE_LEFT, -1 do
		local Mouse = ImmediateState.Mouse[I]

		if Mouse.Down     then ImmediateState.Mouse.Down     = true end
		if Mouse.Double   then ImmediateState.Mouse.Double   = true end
		if Mouse.Clicked  then ImmediateState.Mouse.Clicked  = I end
		if Mouse.Released then ImmediateState.Mouse.Released = I end
	end

	-- Mouse positions
	ImmediateState.LastMouseX = ImmediateState.MouseX or MouseX
	ImmediateState.MouseX = MouseX
	ImmediateState.DeltaX = MouseX - ImmediateState.LastMouseX

	ImmediateState.LastMouseY = ImmediateState.MouseY or MouseY
	ImmediateState.MouseY = MouseY
	ImmediateState.DeltaY = MouseY - ImmediateState.LastMouseY

	ImmediateState.ReleasedNode      = nil
	ImmediateState.PanelHovered = self:IsHovered()

	-- The starting and end indices into self.ExpandedNodeArray
	ImmediateState.StartIndex        = math.max(math.floor( Scroll                               / TallOfOneNode) + 1, 1)
	ImmediateState.EndIndex          = math.min(math.floor((Scroll + self:GetParent():GetTall()) / TallOfOneNode) + 1, #self.ExpandedNodeArray)

	-- Vis testing parameters
	ImmediateState.TotalVisibleNodes = (ImmediateState.EndIndex - ImmediateState.StartIndex)
	-- We test against this array subspan for mouse events
	local BreakInputTesting = false
	for AbsIndex = ImmediateState.StartIndex, ImmediateState.EndIndex do
		local Node = self.ExpandedNodeArray[AbsIndex]

		if not BreakInputTesting then
			local X, Y, W, H  = GetNodeBounds(ImmediateState.Scroll, AbsIndex, ImmediateState.Width, Node.Depth)
			local MouseInRect = ImmediateState:IsMouseInRect(X, Y, W, H) and ImmediateState.PanelHovered
			if MouseInRect then
				ImmediateState.Hovered           = Node
				ImmediateState.IsExpanderHovered = Node:IsFolder() and ImmediateState:IsMouseInRect(GetExpanderBounds(X, Y, W, H, nil, Node.Depth))

				if ImmediateState.Mouse.Clicked then
					ImmediateState.Depressed           = Node
					ImmediateState.IsExpanderDepressed = ImmediateState.IsExpanderHovered
				end

				if ImmediateState.Mouse.Released then
					ImmediateState.ReleasedNode = ImmediateState.Depressed
					ImmediateState.IsExpanderReleased = ImmediateState.IsExpanderHovered
				end

				BreakInputTesting = true
			else
				ImmediateState.Hovered           = false
				ImmediateState.IsExpanderHovered = false
			end
		end
	end

	if ImmediateState.Mouse.Released or not ImmediateState.Mouse.Down then
		ImmediateState.Depressed     = nil
		ImmediateState.IsExpanderDepressed = nil
	end

	if ImmediateState.IsExpanderHovered then
		ImmediateState.Mouse.Cursor = "hand"
	end
end

-- This function considers the current immediate state and triggers events/sets cursor
function BROWSER:ConsiderCurrentState()
	local ImmediateState = self.ImmediateState

	-- Clicked for node logic, released for expander logic
	local Clicked  = ImmediateState.Mouse.Clicked
	local Released = ImmediateState.Mouse.Released

	if Clicked then
		local Node               = ImmediateState.Depressed
		local ExpanderDepressed  = ImmediateState.IsExpanderDepressed

		if Node and not ExpanderDepressed then
			if Clicked == MOUSE_LEFT then
				self:DoNodeLeftClick(Node)
			elseif Clicked == MOUSE_RIGHT then
				self:DoNodeRightClick(Node)
			end
		end
	end

	if Released then
		local Node               = ImmediateState.ReleasedNode
		local ExpanderReleased   = ImmediateState.IsExpanderReleased

		if Node and ExpanderReleased then
			Node:ToggleExpanded()
		end
	end

	self:SetCursor(ImmediateState.Mouse.Cursor)
end

-- This function paints the current immediate state to the DPanel.
function BROWSER:PaintCurrentState()
	local Skin           = self:GetSkin()
	local SkinTex        = Skin.tex

	local ImmediateState = self.ImmediateState
	local ScrollOffset   = ImmediateState.Scroll
	local Width          = ImmediateState.Width

	for AbsIndex = ImmediateState.StartIndex, ImmediateState.EndIndex do
		local Node = self.ExpandedNodeArray[AbsIndex]

		local IsHovered           = ImmediateState.Hovered   == Node
		local IsDepressed         = ImmediateState.Depressed == Node
		local IsExpanderHovered   = IsHovered and ImmediateState.IsExpanderHovered
		local IsExpanderDepressed = IsDepressed and ImmediateState.IsExpanderDepressed

		local NX, NY, NW, NH      = GetNodeBounds(ScrollOffset, AbsIndex, Width, Node.Depth)
		local IX, IY, IW, IH      = GetIconBounds(NX, NY, NW, NH, nil, Node.Depth)
		local EX, EY, EW, EH      = GetExpanderBounds(NX, NY, NW, NH, IsExpanderDepressed and -2 or IsExpanderHovered and 2 or 0, Node.Depth)
		local TextX, TextY        = GetTextPosition(NX, NY, NW, NH, Node.Depth)

		-- Paint background
		if IsDepressed then
			SkinTex.Panels.Dark(NX, NY, NW, NH, color_white)
		elseif IsHovered then
			SkinTex.Panels.Bright(NX, NY, NW, NH, color_white)
		else
			SkinTex.Panels.Normal(NX, NY, NW, NH, color_white)
		end

		-- Paint expander
		if Node:IsFolder() and Node:Count() > 0 then
			if not Node.Expanded then
				SkinTex.TreePlus(EX, EY, EW, EH)
			else
				SkinTex.TreeMinus(EX, EY, EW, EH)
			end
		end

		-- Paint icon
		local Icon
		if Node:IsFolder() then
			Icon = Node:Count() > 0 and ICON_FOLDER_CONTAINS or ICON_FOLDER_EMPTY
		else
			Icon = ICON_FILE
		end

		surface.SetMaterial(Icon)
		surface.DrawTexturedRect(IX, IY, IW, IH)

		-- Paint text
		draw.SimpleText(Node.Text or "<nil value>", NodeFont, TextX, TextY, Skin.colTextEntryText or color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function BROWSER:Think()
	-- Perform a sort recheck ...
	self:SortRecheck()
	-- ... then flush the current state ...
	self:FlushImmediateState()
	-- ... then consider the current state.
	self:ConsiderCurrentState()
	-- FlushImmediateState fetches information from the VGUI panel and tests against that information.
	-- ConsiderCurrentState, given the work that FlushImmediateState did, will trigger events and set some 
	-- VGUI panel data (cursor for example).
end

function BROWSER:Paint(w, h)
	DPanel.Paint(self, w, h)
	-- Renders the immediate state to the screen
	self:PaintCurrentState()
end

function BROWSER:AddRootFolder(RootFolderType)
	RootFolderType = IRootFolder(RootFolderType or error("RootFolderType must contain a IRootFolder implementation")) -- This checks if the type implemented the interface
	local RealNode = self:AddFolder(RootFolderType:GetFolderName())

	RealNode.Root     = RealNode
	RealNode.RootImpl = RootFolderType

	RootFolderType:Init(self, RealNode)

	return RealNode
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
	self.Folders[#self.Folders + 1] = node

	if (self.m_bExpanded) then
		self.Control:Extend(self)
	end

	return node
end

function FOLDER:Clear()
	for _, node in ipairs(self.Folders) do
		node:Remove() end
	for _, node in ipairs(self.Files) do
		node:Remove() end
	self.Nodes = 0
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


function FOLDER:LoadDataFolder(folderPath)
	self:Clear()
	self.LoadingPath = folderPath
	self.LoadingFiles, self.LoadingDirectories = file.Find(folderPath .. "*", "DATA", "nameasc")
	if self.LoadingFiles == nil then self.LoadingFiles = {} end
	if self.LoadingDirectories == nil then self.LoadingDirectories = {} end
	self.FileI, self.DirI = 1, 1
	self.LoadingFirst = true
end

function FOLDER:Think()
	if self.LoadingPath then
		local path, files, dirs, fileI, dirI = self.LoadingPath, self.LoadingFiles, self.LoadingDirectories, self.FileI, self.DirI
		if dirI > #dirs then
			if fileI > #files then
				self.LoadingPath = nil
				return
			else
				local fileName = files[fileI]
				local fileNode = self:AddFile(string.StripExtension(fileName))
				fileI = fileI + 1
			end
		else
			local dirName = dirs[dirI]
			local dirNode = self:AddFolder(dirName)
			dirNode:LoadDataFolder(path .. dirName .. "/")
			dirI = dirI + 1
		end

		self.FileI = fileI
		self.DirI = dirI

		if self.LoadingFirst then
			if self.LoadingPath == "advdupe2/" then self:SetExpanded(true) end
			self.LoadingFirst = false
		end
	end
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

derma.DefineControl("advdupe2_browser_folder", "AD2 Browser Folder node", {}, "Panel")




































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

local function UpdateClientFiles()
	local pnlCanvas = AdvDupe2.FileBrowser.Browser.pnlCanvas

	for i = 1, 2 do
		if (pnlCanvas.Folders[1]) then
			pnlCanvas:RemoveNode(pnlCanvas.Folders[1])
		end
	end

	pnlCanvas.Expanded = true

	pnlCanvas:AddRootFolder(AdvDupe1Folder)
	pnlCanvas:AddRootFolder(AdvDupe2Folder)

	hook.Run("AdvDupe2_PostMenuFolders", pnlCanvas)
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
			if (string.lower(self.FileName:GetValue()[1] or "") == string.lower(input.LookupBinding("menu") or "q")) then
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
