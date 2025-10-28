-- Enums
local ADVDUPE2_AREA_ADVDUPE2   = AdvDupe2.AREA_ADVDUPE2
local ADVDUPE2_AREA_PUBLIC     = AdvDupe2.AREA_PUBLIC
local ADVDUPE2_AREA_ADVDUPE1   = AdvDupe2.AREA_ADVDUPE1
-- These are internal really, so i don't think these need to be exposed?
local NODETYPE_FOLDER          = 1
local NODETYPE_FILE            = 2
-- I may implement more of these later, just defining them now
local VIEWTYPE_TREE  = 0
local VIEWTYPE_LIST  = 1
local VIEWTYPE_TILES = 2

-- This lets us rip this stuff out if we need to.
local FileBrowserPrefix          = "AdvDupe2"
local LowercaseFileBrowserPrefix = string.lower(FileBrowserPrefix)

-- Just in case this needs to be changed later

local MaxTimeToDoubleClick, NodeTall, NodePadding, TallOfOneNode, NodeDepthWidth, NodeFont
local ExpanderSize,  IconSize, LeftmostToExpanderPadding, ExpanderToIconPadding, IconToTextPadding

local ExpanderXOffset, IconXOffset, TextXOffset
local TimeToOpenPrompts_cv, TimeToClosePrompts_cv

local ICON_FOLDER_EMPTY
local ICON_FOLDER_CONTAINS
local ICON_FILE

local FlushConvars
local UserInterfaceTimeFunc  =   RealTime

-- Convars and flushing convars into local registers.
-- FlushConvars gets called in BROWSER:Think() before anything else
do
	TimeToOpenPrompts_cv   =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_promptopentime", "0.2", true, false,
														"The time it takes for a user-prompt to fully open, in seconds.", 0, 1000000)
	TimeToClosePrompts_cv  =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_promptclosetime", "0.3", true, false,
														"The time it takes for a user-prompt to fully close, in seconds.", 0, 1000000)


	local MaxTimeToDoubleClick_cv   =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_maxtimetodoubleclick", "0.25", true, false,
														"Max time delta between clicks to count as a double click, in seconds.", 0, 1000000)
	local NodeTall_cv               =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodetall", "24", true, false,
														"How tall a single file/directory node is in the file browser, in pixels.", 0, 1000000)
	local NodePadding_cv            =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodepadding", "0", true, false,
														"The height padding inbetween two nodes, in pixels.", 0, 1000000)

	-- The total height of one node, including padding. Use this everywhere
	local TallOfOneNode_cv          =   function() return NodeTall + NodePadding end
	-- The width
	local NodeDepthWidth_cv         =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodedepthwidth", "12", true, false,
														"The width of a single node layet, in pixels. For example a file in folder1/folder2 has a depth of 2, so the pixel width, given the default value, will be (12 * 2) == 24.", 0, 1000000)
	local NodeFont_cv               =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodefont", "DermaDefault", true, false,
														"The surface.CreateFont-registered font the file browser uses.")



	local NodeIconFolderEmpty_cv    =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_folderempty", "icon16/folder.png", true, false,
														"The materials/ localized path for an empty folder.")
	local NodeIconFolderContains_cv =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_folder", "icon16/folder_page.png", true, false,
														"The materials/ localized path for a folder with contents.")
	local NodeIconFile_cv           =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_file", "icon16/page.png", true, false,
														"The materials/ localized path for a file.")

	local function CreateNodeTextRepresentation(Label, Offset)
		return table.concat{
			Label, "\n\n",
			"   [+]  [i]  New folder/file", "\n",
			string.rep(" ", Offset), "^\n",
			string.rep(" ", Offset), "^--- You are here"
		}
	end

	local ExpanderSize_cv              = CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeexpander_size", "16", true, false,
															CreateNodeTextRepresentation("The size, in pixels, for a node expander button.", 4), 0, 1000000)
	local IconSize_cv                  = CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_size", "16", true, false,
															CreateNodeTextRepresentation("The size, in pixels, for a folder or file icon.", 9), 0, 1000000)
	local LeftmostToExpanderPadding_cv = CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodepadding_toexpander", "4", true, false,
										                    CreateNodeTextRepresentation("Distance, in pixels, between the leftmost side of the node and where the node expander is placed.", 1), 0, 1000000)
	local ExpanderToIconPadding_cv     = CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodepadding_expandertoicon", "4", true, false,
															CreateNodeTextRepresentation("Distance, in pixels, between the node expander and the node icon.", 7), 0, 1000000)
	local IconToTextPadding_cv         = CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodepadding_icontotext", "6", true, false,
															CreateNodeTextRepresentation("Distance, in pixels, between the node icon and the node text.", 12), 0, 1000000)


	local IconFolderEmpty, IconFolderContains, IconFile

	local function UpdateMaterial(Mat, Old, CV)
		local New = CV:GetString()
		if Old ~= New then
			Mat = Material(New, "smooth")
		end

		return Mat
	end

	function FlushConvars()
		MaxTimeToDoubleClick = MaxTimeToDoubleClick_cv:GetFloat()
		NodeTall             = NodeTall_cv:GetFloat()
		NodePadding          = NodePadding_cv:GetFloat()
		TallOfOneNode        = TallOfOneNode_cv()
		NodeDepthWidth       = NodeDepthWidth_cv:GetFloat()
		NodeFont			 = NodeFont_cv:GetString()

		ExpanderSize              = ExpanderSize_cv:GetFloat()
		IconSize                  = IconSize_cv:GetFloat()
		LeftmostToExpanderPadding = LeftmostToExpanderPadding_cv:GetFloat()
		ExpanderToIconPadding     = ExpanderToIconPadding_cv:GetFloat()
		IconToTextPadding         = IconToTextPadding_cv:GetFloat()

		ExpanderXOffset = LeftmostToExpanderPadding
		IconXOffset     = ExpanderXOffset + ExpanderSize + ExpanderToIconPadding
		TextXOffset     = IconXOffset + IconSize + IconToTextPadding

		ICON_FOLDER_EMPTY    = UpdateMaterial(ICON_FOLDER_EMPTY,    IconFolderEmpty,    NodeIconFolderEmpty_cv)
		ICON_FOLDER_CONTAINS = UpdateMaterial(ICON_FOLDER_CONTAINS, IconFolderContains, NodeIconFolderContains_cv)
		ICON_FILE            = UpdateMaterial(ICON_FILE,            IconFile,           NodeIconFile_cv)
	end
end

local function GetNodeBounds(ScrollOffset, AbsIndex, Width, Depth)
	return
			Depth * NodeDepthWidth,
			(TallOfOneNode * (AbsIndex - 1)) - ScrollOffset,
			Width - (Depth * NodeDepthWidth),
			NodeTall
end

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

		local function testMonth(i, c)
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
					for i2 = 1, #monthStoreJustInCase do
						ret[#ret + 1] = monthStoreJustInCase[i2]
					end
					monthStoreJustInCase = {}
					monthTester = buildMonth
				end
			end
		end

		local function finalTest(i, c)
			if monthTester ~= buildMonth then
				for i2 = 1, #monthStoreJustInCase do
					ret[#ret + 1] = monthStoreJustInCase[i2]
				end
				monthStoreJustInCase = {}
				monthTester = buildMonth
			end
			ret[#ret + 1] = char2byte[c]
		end

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
					testMonth(i, c)
				elseif digit ~= nil then
					ret[#ret + 1] = digit - (#ret == 0 and 100000000 or 0)
					digit = nil
				else
					finalTest(i, c)
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

local SetupDataFile, SetupDataSubfolder
local NODE_MT = {}
local NODE    = setmetatable({}, NODE_MT)
do
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
	function NODE:IsFolder() return self.Type == NODETYPE_FOLDER    end
	function NODE:IsFile()   return self.Type == NODETYPE_FILE      end

	function NODE:AddFolder(Text)
		local Node = NODE(NODETYPE_FOLDER, self.Browser)
		Node.Text = Text
		Node.ParentNode = self
		Node.Root = self.Root
		if self.Expanded then self:MarkSortDirty() end
		self.Folders[#self.Folders + 1] = Node

		return Node
	end

	function NODE:AddFile(Text)
		local Node = NODE(NODETYPE_FILE, self.Browser)
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
		self.Browser:MarkSortDirty()
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

	function SetupDataFile(Node, Path, Name)
		Node.Text = Name
		Node.Path = Path
	end

	function SetupDataSubfolder(Node, Path, Name)
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

	function NODE.InjectIntoBrowser(TreeView, Browser)
		for FuncName, Func in pairs(NODE) do
			TreeView[FuncName] = Func
		end

		NODE.Init(TreeView, NODETYPE_FOLDER, Browser)
	end
end

-- This interface describes the logic behind a root folder (like AdvDupe1 or AdvDupe2).

local IRootFolder_MT = {}
local IRootFolder    = setmetatable({}, IRootFolder_MT)

do
	AdvDupe2.IRootFolder = IRootFolder -- If other addons want to post-verify their IRootFolder implementations like we do

	-- todo; debug.getinfo and determine argument counts to further sanity check?
	IRootFolder.Init             = function(Impl, Browser, Node) end
	IRootFolder.GetFolderName    = function(Impl) end
	-- These define node operations
	-- These are RAW operations, as in the underlying Browser might do some prompts first
	-- But for example, calling IRootFolder:UserDelete() is expected to actually delete the node
	-- (and the browser will create the prompt)
	IRootFolder.UserLoad         = function(Impl, Browser, Node) end
	IRootFolder.UserPreview      = function(Impl, Browser, Node) end
	IRootFolder.UserSave         = function(Impl, Browser, Node, Filename, Description) end
	IRootFolder.UserRename       = function(Impl, Browser, Node, RenameTo) end
	IRootFolder.UserMenu         = function(Impl, Browser, Node, Menu) end
	IRootFolder.UserDelete       = function(Impl, Browser, Node) end
	IRootFolder.UserMakeFolder   = function(Impl, Browser, Node, Foldername) end
	IRootFolder.UserGetModTime   = function(Impl, Browser, Node) return 0 end
	IRootFolder.UserGetSize      = function(Impl, Browser, Node) return 0 end

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
end

-- This is a user prompt class, see Browser's UserPrompt stack methods

local USERPROMPT_MT = {}
local USERPROMPT    = setmetatable({}, USERPROMPT_MT)

do
	function USERPROMPT:Init(Browser)
		self.Browser  = Browser
		self.Blocking = false

		self.StartOpen  = UserInterfaceTimeFunc()
		self.WillOpenAt = self.StartOpen + TimeToOpenPrompts_cv:GetFloat()

		self.Panel = Browser:Add("DScrollPanel")
		local PanelColor = Color(255, 255, 255, 213)
		self.Panel.Paint = function(panel, w, h)
			local Skin = panel:GetSkin()
			local SkinTex = Skin.tex

			SkinTex.Panels.Normal(0, 0, w, h, PanelColor)
		end
	end

	function USERPROMPT:GetPanel() return self.Panel end

	function USERPROMPT:Add(Type)
		return self.Panel:Add(Type)
	end

	function USERPROMPT_MT:__call(Browser)
		if not IsValid(Browser) then return error ("Cannot create a headless node (we need a browser)") end

		local Node   = setmetatable({}, {__index = USERPROMPT})
		Node:Init(Browser)

		return Node
	end

	function USERPROMPT:GetBlocking() return self.Blocking or false end
	function USERPROMPT:SetBlocking(Blocking) self.Blocking = Blocking and true or false end

	function USERPROMPT:Destroy()
		if IsValid(self.Panel) then
			self.Panel:Remove()
		end
	end

	function USERPROMPT:SetDock(Dock)
		self.Dock = Dock
	end

	local function Normalize(X, Min, Max)
		return math.Clamp((X - Min) / (Max - Min), 0, 1)
	end

	function USERPROMPT:GetAnimationRatio(Now)
		local Closing = self.Closing

		local OpenRatio  = Normalize(Now, self.StartOpen, self.WillOpenAt)
		local CloseRatio = Closing and (1 - Normalize(Now, self.StartClose, self.WillCloseAt)) or 1

		local OpenX,  OpenY,  OpenA  = math.ease.OutQuad(OpenRatio),  math.ease.OutBack(OpenRatio), math.ease.OutQuad(OpenRatio)
		local CloseX, CloseY, CloseA = math.ease.OutQuad(CloseRatio), math.ease.OutBack(CloseRatio), math.ease.InQuart(CloseRatio)

		-- We return opening animation * closing animation to get smooth effects
		-- This works because CloseRatio will be a downward value while OpenRatio will be an upward value 
		return OpenX * CloseX, OpenY * CloseY, OpenA * CloseA
	end

	local DockPadding = 4

	function USERPROMPT:DoThink()
		local Now       = UserInterfaceTimeFunc()
		local Closing   = self.Closing

		if Closing and Now >= self.WillCloseAt then
			return false
		end

		local RatioX, RatioY, RatioA    = self:GetAnimationRatio(Now)
		local Browser                   = self.Browser
		local ParentWidth, ParentHeight = Browser:GetWide(), Browser:GetTall()

		local PosX,  PosY
		local SizeW, SizeH

		local ContentWide, ContentTall = self.Panel:ChildrenSize()
		ContentTall = math.Min(ContentTall, self.Browser:GetTall() - 32)
		local Dock = self.Dock
		if not Dock then error("No dock??") end

		if Dock == TOP then
			SizeW = math.ceil((RatioX * ParentWidth) - (DockPadding * 2))
			SizeH = math.ceil(ContentTall * RatioY)
			PosX  = ((ParentWidth / 2) - (SizeW / 2))
			PosY  = DockPadding
		elseif Dock == BOTTOM then
			SizeW = math.ceil((RatioX * ParentWidth) - (DockPadding * 2))
			SizeH = math.ceil(ContentTall * RatioY)
			PosX  = ((ParentWidth / 2) - (SizeW / 2))
			PosY  = ParentHeight - SizeH - DockPadding
		elseif Dock == FILL then
			SizeW = math.ceil((RatioX * ContentWide) - (DockPadding * 2))
			SizeH = math.ceil(ContentTall * RatioY)
			PosX  = ((ParentWidth / 2) - (SizeW / 2))
			PosY  = (ParentHeight / 2) - (SizeH / 2) - (DockPadding / 2)
		end

		self.Panel:SetPos(PosX, PosY)
		self.Panel:SetSize(SizeW, SizeH)
		self.Panel:SetAlpha(RatioA * 255)

		return true
	end

	-- Call this to close and pop later.
	-- This also forces Blocking back to false for main UI panel.
	function USERPROMPT:Close()
		self.Blocking    = false
		self.Closing     = true
		self.StartClose  = UserInterfaceTimeFunc()
		self.WillCloseAt = self.StartClose + TimeToClosePrompts_cv:GetFloat()
	end
end

-- This turns a data-folder path name into something AdvDupe2.UploadFile can tolerate
local function GetNodeDataPath(Node)
	local Path                = Node.Path
	if not Path then return "" end

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


-- These are the builtin IRootFolder implementations.
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

	function AdvDupe1Folder:UserLoad(Browser, Node)
		AdvDupe2.UploadFile(GetNodeDataPath(Node), ADVDUPE2_AREA_ADVDUPE1)
	end

	function AdvDupe1Folder:UserPreview(Browser, Node)
		OpenPreview(Node, ADVDUPE2_AREA_ADVDUPE1)
	end


	function AdvDupe1Folder:UserSave(Browser, Node, Filename, Description)

	end

	function AdvDupe1Folder:UserRename(Browser, Node, RenameTo)
		return false
	end

	function AdvDupe1Folder:UserMenu(Browser, Node, Menu)
		if Node:IsFile() then
			Menu:AddOption("Open",    function() self:UserLoad(Browser, Node)  end, "icon16/page_go.png")
		end
	end

	function AdvDupe1Folder:UserDelete(Browser, Node)
		return false
	end

	function AdvDupe1Folder:UserMakeFolder(Browser, Node, Foldername)

	end

	function AdvDupe1Folder:UserGetModTime(Browser, Node)
		return 0
	end

	function AdvDupe1Folder:UserGetSize(Browser, Node)
		return 0
	end

	IRootFolder(AdvDupe1Folder) -- validation
end

do
	AdvDupe2Folder = {
		-- Key-weak LUT's for size/modtimes.
		-- They're key-weak so if a node gets deleted it isn't hung up by GC thinking
		-- we care about the reference still
		SizeCache = setmetatable({}, {__mode = 'k'}),
		TimeCache = setmetatable({}, {__mode = 'k'})
	}
	function AdvDupe2Folder:GetFolderName() return "Advanced Duplicator 2" end
	function AdvDupe2Folder:Init(Browser, Node)
		Node:LoadDataFolder("advdupe2/")
	end

	function AdvDupe2Folder:UserLoad(Browser, Node)
		AdvDupe2.UploadFile(GetNodeDataPath(Node), ADVDUPE2_AREA_ADVDUPE2)
	end

	function AdvDupe2Folder:UserPreview(Browser, Node)
		OpenPreview(Node, ADVDUPE2_AREA_ADVDUPE2)
	end

	function AdvDupe2Folder:UserSave(Browser, Node, Filename, Description)
		local DataPath = (Node.Path or "advdupe2") .. "/" .. Filename
		AdvDupe2.SavePath = DataPath

		-- This is kinda weird but it's the only way I've been able to reliably avoid deadlocks here
		hook.Add("AdvDupe2_InitProgressBar", "AdvDupe2_BrowserDownloadPrompt", function(Txt)
			hook.Remove("AdvDupe2_InitProgressBar", "AdvDupe2_BrowserDownloadPrompt")
			if Txt ~= "Saving:" then return end

			Browser:ShowSavePrompt()
			hook.Add("AdvDupe2_RemoveProgressBar", "AdvDupe2_BrowserDownloadPrompt", function()
				hook.Remove("AdvDupe2_RemoveProgressBar", "AdvDupe2_BrowserDownloadPrompt")
				Browser:HideSavePrompt()
			end)
		end)
		-- Enqueue handler
		Browser:AwaitingFile(AdvDupe2.GetFilename(DataPath), function(NewFilepath)
			if not NewFilepath then
				Browser:HideSavePrompt()
				return
			end
			Node:Expand()
			local NewFilename = string.GetFileFromFilename(NewFilepath)
			local NewNode = Node:AddFile(NewFilename)
			SetupDataFile(NewNode, NewFilepath, NewFilename)
			Browser:HideSavePrompt()
		end)

		if game.SinglePlayer() then
			RunConsoleCommand("AdvDupe2_SaveFile", Filename, Description, GetNodePath(Node))
		else
			RunConsoleCommand("AdvDupe2_SaveFile", Filename)
		end
	end

	function AdvDupe2Folder:UserRename(Browser, Node, RenameTo)
		local NodePath = "advdupe2/" .. GetNodeDataPath(Node) .. ".txt"
		local NewNodePath = string.GetPathFromFilename(NodePath) .. RenameTo .. ".txt"
		if file.Rename(NodePath, NewNodePath) then
			SetupDataFile(Node, NewNodePath, RenameTo .. ".txt")
			Node.ParentNode:MarkSortDirty()
			Browser:ScrollTo(Node)
			return true
		end

		return false
	end

	function AdvDupe2Folder:UserMenu(Browser, Node, Menu)
		if Node:IsFile() then
			Menu:AddOption("Open",    function() self:UserLoad(Browser, Node)  end, "icon16/page_go.png")
			Menu:AddOption("Preview", function() self:UserPreview(Browser, Node) end, "icon16/information.png")
			Menu:AddSpacer()
			Menu:AddOption("Rename...", function() Browser:StartRename(Node) end, "icon16/textfield_rename.png")
			Menu:AddOption("Move...",   function() Browser:StartMove(Node)   end, "icon16/arrow_right.png")
			Menu:AddOption("Delete",    function() Browser:StartDelete(Node) end, "icon16/bin_closed.png")
		else
			Menu:AddOption("Save",       function() Browser:StartSave(Node)   end, "icon16/disk.png")
			Menu:AddOption("New Folder", function() Browser:StartFolder(Node) end, "icon16/folder_add.png")
			Menu:AddSpacer()
			Menu:AddOption("Search",     function() Browser:StartSearch(Node) end, "icon16/magnifier.png")
		end
	end

	function AdvDupe2Folder:UserDelete(Browser, Node)
		local NodePath = "advdupe2/" .. GetNodeDataPath(Node) .. ".txt"
		local Success = file.Delete(NodePath)
		if Success then
			Node:Remove(Node)
		end
		return Success
	end

	function AdvDupe2Folder:UserMakeFolder(Browser, Node, Foldername)
		local DataPath = (Node.Path or "advdupe2") .. "/" .. Foldername

		file.CreateDir(DataPath)

		local NewNode = Node:AddFolder(Foldername)
		SetupDataSubfolder(NewNode, DataPath, Foldername)
		Node:Expand()
		NewNode:Expand()
		Browser:ScrollTo(NewNode)
	end

	function AdvDupe2Folder:UserGetModTime(Browser, Node)
		if not Node.Path then return end

		local Time = self.TimeCache[Node]
		if Time then return Time end

		Time = file.Time(Node.Path, "DATA")
		self.TimeCache[Node] = Time
	end

	function AdvDupe2Folder:UserGetSize(Browser, Node)
		if Node:IsFolder() then return -1 end

		local Size = self.SizeCache[Node]
		if Size then return Size end

		Size = file.Size(Node.Path, "DATA")
		self.SizeCache[Node] = Size
	end

	IRootFolder(AdvDupe2Folder) -- validation
end

-- This is the base browser panel. Most VGUI interactions happen here

local BROWSERTREE = {}
AccessorFunc(BROWSERTREE, "m_pSelectedItem", "SelectedItem")

local origSetTall
local function SetTall(self, val)
	origSetTall(self, val)
	self.VBar:SetUp(self:GetParent():GetTall(), self:GetTall())
end

function BROWSERTREE:Init()
	self:SetTall(0)
	origSetTall = self.SetTall
	self.SetTall = SetTall

	self.VBar = self:GetParent():Add "DVScrollBar"
	self.VBar:Dock(RIGHT)

	-- Implement NODE
	NODE.InjectIntoBrowser(self, self:GetParent())
	self.SortDirty         = true
	self.ExpandedNodeArray = {}

	self.LastClick = UserInterfaceTimeFunc()
	self.VBar.OldPaint = self.VBar.Paint
	function self.VBar:Paint(w, h)
		self:OldPaint(w, h)
		-- todo
	end
end

function BROWSERTREE:DoNodeLeftClick(Node)
	if self.m_pSelectedItem == Node and UserInterfaceTimeFunc() - self.LastClick <= MaxTimeToDoubleClick then -- Check for double click
		if Node:IsFolder() then
			Node:ToggleExpanded()
		else
			local RootImpl = Node.Root.RootImpl
			RootImpl:UserLoad(self.Browser, Node)
		end
	else
		self:SetSelected(Node) -- A node was clicked, select it
	end

	self.LastClick = UserInterfaceTimeFunc()
end

function BROWSERTREE:DoNodeRightClick(Node)
	self:SetSelected(Node)

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

	RootImpl:UserMenu(self.Browser, Node, Menu)

	Menu:SetAlpha(0)
	Menu:AlphaTo(255, 0.1, 0)
	Menu:Open()
end

function BROWSERTREE:OnMouseWheeled(dlta)
	return self.VBar:OnMouseWheeled(dlta)
end

function BROWSERTREE:SetSelected(node)
	if self.m_pSelectedItem then
		self.m_pSelectedItem.Selected = false
	end
	self.m_pSelectedItem = node
	if node then
		node.Selected = true
	end
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

-- This function collapses the current node state into a single sequential array
function BROWSERTREE:SortRecheck()
	if not self.SortDirty then return end

	table.Empty(self.ExpandedNodeArray)
	DoRecursiveVistesting(self.TargetNode and self.TargetNode or self, self.ExpandedNodeArray)

	-- This is how tall we are
	local Tall = #self.ExpandedNodeArray * TallOfOneNode
	self:SetTall(Tall)

	if self.SearchQuery ~= nil and #self.SearchQuery > 0 then
		self.SearchableNodes = {}
		for _, Node in ipairs(self.ExpandedNodeArray) do
			Node.SearchExcluded = string.find(Node.Text, self.SearchQuery) == nil
			if not Node.SearchExcluded then
				self.SearchableNodes[#self.SearchableNodes + 1] = Node
			end
		end
	else
		for _, Node in ipairs(self.ExpandedNodeArray) do
			Node.SearchExcluded = nil
		end
		self.SearchableNodes = nil
	end

	self.SortDirty = false
end

-- Gets or creates the immediate state table.
function BROWSERTREE:GetImmediateState()
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

function BROWSERTREE:StartSearch(TargetNode, LastSearch)
	self.SearchQuery    = LastSearch
	self.TargetNode     = TargetNode
	self.LastSearchNode = nil
	self.SortDirty = true
	self.LastSearchIndex = 0

	TargetNode:Expand()
end

function BROWSERTREE:UpdateSearchQuery(Text)
	self.SearchQuery = Text
	if self.LastSearchNode ~= nil then self.LastSearchNode.SearchQueryHighlighted = nil end
	self.LastSearchNode = nil
	self.SortDirty = true
	self.LastSearchIndex = 0
	print(Text)
	return Text
end

function BROWSERTREE:HighlightSearchNode(Node)
	if self.LastSearchNode ~= nil then self.LastSearchNode.SearchQueryHighlighted = nil end
	if Node ~= nil then Node.SearchQueryHighlighted = true end
	self.LastSearchNode = Node
end

function BROWSERTREE:NextSearchNode()
	if self.SearchQuery == nil then return end
	if #self.SearchQuery == 0 then return end

	self.LastSearchIndex = self.LastSearchIndex + 1
	if self.LastSearchIndex > #self.SearchableNodes then
		self.LastSearchIndex = 1
	end

	self:HighlightSearchNode(self.SearchableNodes[self.LastSearchIndex])
	return self.LastSearchNode
end

function BROWSERTREE:EndSearch()
	self.SearchQuery    = LastSearch
	self.TargetNode     = TargetNode
	if self.LastSearchNode ~= nil then self.LastSearchNode.SearchQueryHighlighted = nil end
	self.LastSearchNode = nil
	self.SortDirty = true
	self.LastSearchIndex = 0
end

-- This function flushes in the immediate-mode state from C-funcs into Lua-land
-- and performs calculations that may be needed later on in a cached state
-- The immediate state object is unique to the browser
function BROWSERTREE:FlushImmediateState()
	local ImmediateState = self:GetImmediateState()

	local Scroll         = IsValid(self.VBar) and (self.VBar:GetScroll()) or 0

	local MouseX, MouseY = self:CursorPos()
	local CanInput       = self:IsMouseInputEnabled()
	local Now            = UserInterfaceTimeFunc()

	ImmediateState.LastTime     = ImmediateState.Time or Now
	ImmediateState.Time         = Now
	ImmediateState.DeltaTime    = ImmediateState.Time - ImmediateState.LastTime

	ImmediateState.Mouse.Cursor = "arrow"
	ImmediateState.LastScroll   = ImmediateState.Scroll or Scroll
	ImmediateState.Scroll       = Scroll
	ImmediateState.DeltaScroll  = Scroll - ImmediateState.LastScroll
	ImmediateState.CanInput     = CanInput

	ImmediateState.Width        = self:GetWide()
	ImmediateState.Height       = self:GetTall()

	for I = MOUSE_LEFT, MOUSE_LAST do
		local Mouse = ImmediateState.Mouse[I]
		if not Mouse then
			Mouse = {}
			ImmediateState.Mouse[I] = Mouse
		end

		Mouse.LastDown = Mouse.Down or false
		Mouse.Down     = input.IsMouseDown(I) and CanInput
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
	local BreakInputTesting = not CanInput -- if can't input, never even do input testing
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
function BROWSERTREE:ConsiderCurrentState()
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
function BROWSERTREE:PaintCurrentState(PanelWidth, PanelHeight)
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
		if IsDepressed or Node.SearchExcluded then
			SkinTex.Panels.Dark(NX, NY, NW, NH, color_white)
		elseif Node.SearchQueryHighlighted then
			SkinTex.Panels.Highlight(NX, NY, NW, NH, color_white)
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

	ImmediateState.BlockingAlpha = math.Clamp((ImmediateState.BlockingAlpha or 0) + (ImmediateState.DeltaTime * 4 * (ImmediateState.CanInput and -1 or 1)), 0, 1)
	if ImmediateState.BlockingAlpha > 0 then
		local Alpha = math.ease.InOutQuad(ImmediateState.BlockingAlpha) * 66
		local OldClipping = DisableClipping(true)
		surface.SetDrawColor(0, 0, 0, Alpha)
		surface.DrawRect(0, 0, self.Browser:GetSize())
		DisableClipping(OldClipping)
	end
end

function BROWSERTREE:Think()
	FlushConvars()
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

function BROWSERTREE:Paint(w, h)
	DPanel.Paint(self, w, h)
	-- Renders the immediate state to the screen
	self:PaintCurrentState(w, h)
end

derma.DefineControl(LowercaseFileBrowserPrefix .. "_browser_tree", FileBrowserPrefix .. " File Browser", BROWSERTREE, "Panel")

local BROWSER = {}
AccessorFunc(BROWSER, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(BROWSER, "m_bgColor", "BackgroundColor")
Derma_Hook(BROWSER, "Paint", "Paint", "Panel")
Derma_Hook(BROWSER, "PerformLayout", "Layout", "Panel")

local setbrowserpnlsize
local function SetBrowserPnlSize(self, x, y)
	setbrowserpnlsize(self, x, y)
	self.TreeView:SetWide(x)
	self.TreeView.VBar:SetUp(y, self.TreeView:GetTall())
end

function BROWSER:Init()
	setbrowserpnlsize = self.SetSize
	self.SetSize = SetBrowserPnlSize
	self.TreeView = vgui.Create(LowercaseFileBrowserPrefix .. "_browser_tree", self)

	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetBackgroundColor(self:GetSkin().text_bright)

	self:SetViewType(VIEWTYPE_TREE)
end

-- Public facing API

function BROWSER:SetViewType(ViewType)
	self.TreeView.ViewType = ViewType or error("No viewtype provided")
	self:MarkSortDirty()
end

function BROWSER:MarkSortDirty()
	if not self.TreeView then return end
	self.TreeView.SortDirty = true
end

-- Call this to enqueue a file callback, if you need one.
-- The filepath should be unique.
function BROWSER:AwaitingFile(Filepath, Callback)
	self.WaitingQueue = self.WaitingQueue or {}
	self.WaitingQueue[Filepath] = Callback
end

-- Call this to call any file callback with that name and remove it from the callback list.
function BROWSER:IncomingFile(Filepath, ...)
	if not self.WaitingQueue then return end

	local Callback = self.WaitingQueue[Filepath]
	if not Callback then ErrorNoHalt("File Browser ['" .. FileBrowserPrefix .. "'] error: incoming file '" .. Filepath .. "' had no event handler.\n") return end

	self.WaitingQueue[Filepath] = nil
	return Callback(...)
end

function BROWSER:AddRootFolder(RootFolderType)
	RootFolderType = IRootFolder(RootFolderType or error("RootFolderType must contain a IRootFolder implementation")) -- This checks if the type implemented the interface
	local RealNode = self.TreeView:AddFolder(RootFolderType:GetFolderName())

	RealNode.Root     = RealNode
	RealNode.RootImpl = RootFolderType

	RootFolderType:Init(self, RealNode)

	return RealNode
end

function BROWSER:GetRootImpl(Node)
	return Node.Root.RootImpl or error "Cannot find IRootFolder implementation!"
end

local NotifIcons = {
	[NOTIFY_CLEANUP] = "bin",
	[NOTIFY_ERROR]   = "error",
	[NOTIFY_GENERIC] = "information",
	[NOTIFY_HINT]    = "lightbulb",
	[NOTIFY_UNDO]    = "arrow_undo",
}

function BROWSER:Notify(Message, Level, Time)
	Level = Level or NOTIFY_GENERIC
	Time  = Time or 5

	local Notif = self:PushUserPrompt()
	Notif:SetDock(TOP)

	local Text = Notif:Add("DLabel")
		Text:SetText(Message or "<nil>")
		Text:Dock(FILL)
		Text:SetContentAlignment(5)
		Text:SetDark(true)

	local Icon = Notif:Add("DImageButton")
		Icon:SetMouseInputEnabled(false) -- DImageButton provides SetStretchToFit while DImage doesn't - that's all we need here
		Icon:SetSize(20, 20)
		Icon:SetStretchToFit(false)
		Icon:SetKeepAspect(true)
		Icon:SetImage("icon16/" .. NotifIcons[Level] .. ".png")

	local OldLayout = Notif.Panel.PerformLayout
	function Notif.Panel:PerformLayout(W, H)
		OldLayout(self, W, H)
		local CW = Text:GetContentSize()
		Icon:SetPos((W / 2) - (CW / 2) - 12)
		Text:SetTextInset(12, 0)
	end
	-- bit too hacky?
	function Notif.Panel:ChildrenSize()
		return 0, 24
	end

	timer.Simple(Time, function() if IsValid(Notif.Panel) then Notif:Close() end end)
end

local function SharedFileFolderLogic(self, Node, DoDesc, NameTextPlaceholder, DescTextPlaceholder, Icon, Completed, LastName, LastDesc, SkipToDesc, BlockName)
	local Prompt = self:PushUserPrompt()
	Prompt:SetBlocking(true)
	Prompt:SetDock(BOTTOM)
	Prompt.Panel:DockPadding(4,4,4,4)

	local Name, Desc, Cancel, Save

	local function FinishSave()
		-- Require filename
		local FileName = Name:GetText()
		if FileName == nil or FileName == "" then
			self:Notify("You must specify a file/folder path.", NOTIFY_ERROR, 2)
			return
		end

		local RootImpl = self:GetRootImpl(Node)
		Completed(self, RootImpl, Node, FileName, Desc and Desc:GetText() or "")
		Prompt:Close()
	end

	-- I tried SetTabPosition; it doesn't like to work, so we're doing it ourselves

	if DoDesc then
		Name = Prompt:Add("DTextEntry")
			Name:SetAllowNonAsciiCharacters(true)
			Name:SetTabbingDisabled(false)
			Name:Dock(TOP)
			Name:SetPlaceholderText(NameTextPlaceholder)
			Name:SetZPos(1)
			if LastName then Name:SetText(LastName) end
			if BlockName then Name:SetEnabled(false) end

		local DescParent = Prompt:Add("Panel")
			DescParent:Dock(TOP)
			DescParent:DockMargin(0, 4, 0, 0)
			DescParent:SetSize(20, 20)
			DescParent:SetPaintBackgroundEnabled(false)
			DescParent:SetZPos(10000)

		Cancel = DescParent:Add("DImageButton")
			Cancel:Dock(RIGHT)
			Cancel:SetSize(20)
			Cancel:SetStretchToFit(false)
			Cancel:SetImage("icon16/cancel.png")

		Save = DescParent:Add("DImageButton")
			Save:Dock(RIGHT)
			Save:SetSize(24)
			Save:SetStretchToFit(false)
			Save:SetImage("icon16/" .. Icon .. ".png")

		Desc = DescParent:Add("DTextEntry")
			Desc:SetAllowNonAsciiCharacters(true)
			Desc:SetTabbingDisabled(false)
			Desc:Dock(FILL)
			Desc:SelectAllOnFocus()
			Desc:SetPlaceholderText(DescTextPlaceholder)
			if LastDesc then Desc:SetText(LastDesc) end
	else
		local DescParent = Prompt:Add("Panel")
			DescParent:Dock(TOP)
			DescParent:DockMargin(0, 4, 0, 0)
			DescParent:SetSize(20, 20)
			DescParent:SetPaintBackgroundEnabled(false)
			DescParent:SetZPos(10000)

		Cancel = DescParent:Add("DImageButton")
			Cancel:Dock(RIGHT)
			Cancel:SetSize(20)
			Cancel:SetStretchToFit(false)
			Cancel:SetImage("icon16/cancel.png")

		Save = DescParent:Add("DImageButton")
			Save:Dock(RIGHT)
			Save:SetSize(24)
			Save:SetStretchToFit(false)
			Save:SetImage("icon16/" .. Icon .. ".png")

		Name = DescParent:Add("DTextEntry")
			Name:SetAllowNonAsciiCharacters(true)
			Name:SetTabbingDisabled(false)
			Name:Dock(FILL)
			Name:SetPlaceholderText(NameTextPlaceholder)
			Name:SetZPos(1)
			if LastName then Name:SetText(LastName) end
	end

	function Name:OnEnter()
		self:KillFocus()
		if Desc then
			Desc:SelectAllOnFocus(true)
			Desc:OnMousePressed()
			Desc:RequestFocus()
		else
			FinishSave()
		end
	end

	if Desc then
		function Name:OnKeyCode(KeyCode)
			if KeyCode == KEY_TAB then
				return timer.Simple(0, function() if IsValid(self) then self:OnEnter() end end)
			end

			DTextEntry.OnKeyCode(self, KeyCode)
		end
	end

	function Name:OnMousePressed()
		self:OnGetFocus()
		self:SelectAllOnFocus(true)
	end

	if Desc then
		function Desc:OnEnter(_, WasTab)
			self:KillFocus()
			if WasTab then -- Wrap back to Name.
				Name:SelectAllOnFocus(true)
				Name:OnMousePressed()
				Name:RequestFocus()
			else
				FinishSave()
			end
		end
		function Desc:OnKeyCode(KeyCode)
			if KeyCode == KEY_TAB then
				return timer.Simple(0, function() if IsValid(self) then self:OnEnter(nil, true) end end)
			end

			DTextEntry.OnKeyCode(self, KeyCode)
		end
		function Desc:OnMousePressed()
			self:OnGetFocus()
			self:SelectAllOnFocus(true)
		end
	end

	function Save:DoClick()
		FinishSave()
	end
	function Cancel:DoClick()
		Prompt:Close()
	end

	if SkipToDesc then
		Desc:RequestFocus()
		Desc:OnMousePressed()
	else
		Name:RequestFocus()
		Name:OnMousePressed()
	end
end

function BROWSER:StartSave(Node)
	if not Node:IsFolder() then ErrorNoHaltWithStack("AdvDupe2: Attempted to call StartSave on a non-folder. Operation canceled.") return false end

	SharedFileFolderLogic(self, Node, true, "Dupe name", "Dupe description", "disk", function(_, RootImpl, _, FileName, Desc)
		RootImpl:UserSave(self, Node, FileName, Desc)
		self.LastFileName = FileName
		self.LastFileDesc = Desc
	end, self.LastFileName, self.LastFileDesc)
end

local LastSearch = ""
function BROWSER:StartSearch(Node)
	if not Node:IsFolder() then ErrorNoHaltWithStack("AdvDupe2: Attempted to call StartSearch on a non-folder. Operation canceled.") return false end

	self.TreeView:StartSearch(Node, LastSearch)

	local Prompt = self:PushUserPrompt()
	Prompt:SetDock(BOTTOM)
	Prompt.Panel:DockPadding(4,4,4,4)

	local Cancel = Prompt:Add("DImageButton")
		Cancel:Dock(RIGHT)
		Cancel:SetSize(20)
		Cancel:SetStretchToFit(false)
		Cancel:SetImage("icon16/cancel.png")

	local DescParent = Prompt:Add("Panel")
		DescParent:Dock(TOP)
		DescParent:DockMargin(0, 4, 0, 0)
		DescParent:SetSize(20, 32)
		DescParent:SetPaintBackgroundEnabled(false)
		DescParent:SetZPos(10000)

	local Search = DescParent:Add("DTextEntry")
		Search:SetAllowNonAsciiCharacters(true)
		Search:SetTabbingDisabled(false)
		Search:Dock(TOP)
		Search:SetPlaceholderText("Search...")
		if LastSearch then Search:SetText(LastSearch) end

	function Search.OnChange()
		local value = Search:GetText()
		LastSearch = self.TreeView:UpdateSearchQuery(value)
	end

	local _OnKeyCodeTyped = Search.OnKeyCodeTyped
	function Search.OnKeyCodeTyped(dte, code)
		if code ~= KEY_ENTER then return _OnKeyCodeTyped(dte, code) end
		local Node = self.TreeView:NextSearchNode()
		if Node then
			self:ScrollTo(Node)
		else
			self:Notify("No search query!", NOTIFY_ERROR, 3)
		end
		return true
	end

	function Cancel.DoClick(_)
		Prompt:Close()
		self.TreeView:EndSearch()
	end
end

function BROWSER:StartFolder(Node)
	if not Node:IsFolder() then ErrorNoHaltWithStack("AdvDupe2: Attempted to call StartSave on a non-folder. Operation canceled.") return false end

	SharedFileFolderLogic(self, Node, false, "Dupe name", "Dupe description", "folder_add", function(_, RootImpl, _, FileName, Desc)
		RootImpl:UserMakeFolder(self, Node, FileName, Desc)
	end)
end

function BROWSER:StartRename(Node)
	SharedFileFolderLogic(self, Node, true, "", "New filename", "page_go", function(_, RootImpl, _, FileName, Desc)
		if not RootImpl:UserRename(self, Node, Desc) then
			self:Notify("Rename failed.", NOTIFY_ERROR, 5)
		end
	end, string.GetFileFromFilename(Node.Path), nil, true, true)
end

function BROWSER:StartDelete(Node)
	local Prompt = self:PushUserPrompt()
	Prompt:SetBlocking(true)
	Prompt:SetDock(BOTTOM)
	Prompt.Panel:DockPadding(4,4,4,4)

	local DescParent = Prompt:Add("Panel")
		DescParent:Dock(TOP)
		DescParent:DockMargin(0, 4, 0, 0)
		DescParent:SetSize(20, 32)
		DescParent:SetPaintBackgroundEnabled(false)
		DescParent:SetZPos(10000)

	local Cancel = DescParent:Add("DImageButton")
		Cancel:Dock(RIGHT)
		Cancel:SetSize(20)
		Cancel:SetStretchToFit(false)
		Cancel:SetImage("icon16/cancel.png")

	local Delete = DescParent:Add("DImageButton")
		Delete:Dock(RIGHT)
		Delete:SetSize(24)
		Delete:SetStretchToFit(false)
		Delete:SetImage("icon16/bin.png")

	local Name = DescParent:Add("DLabel")
		Name:Dock(FILL)
		Name:SetDark(true)
		Name:SetText("Are you sure to want to delete\n" .. Node.Path .. "?")
		Name:SetAutoStretchVertical(true)
		Name:SetZPos(1)

	function Delete.DoClick()
		local RootImpl = self:GetRootImpl(Node)
		if RootImpl:UserDelete(self, Node) then
			self:Notify("Deleted " .. Node.Text .. ".", NOTIFY_CLEANUP, 5)
		else
			self:Notify("Delete failed.", NOTIFY_ERROR, 5)
		end
		Prompt:Close()
	end

	function Cancel:DoClick()
		Prompt:Close()
	end
end

function BROWSER:GetUserPromptStack()
	local UserPrompts = self.UserPrompts

	if not UserPrompts then
		UserPrompts = {}
		self.UserPrompts = UserPrompts
	end

	return UserPrompts
end

-- Returns the index you should use for the stack.
function BROWSER:IncrementUserPromptStackPtr()
	local StackPtr = self.UserPromptStackPtr
	if not StackPtr then StackPtr = 0 self.UserPromptStackPtr = StackPtr end

	StackPtr = StackPtr + 1
	self.UserPromptStackPtr = StackPtr

	return StackPtr
end

-- Returns the index to remove from the stack.
function BROWSER:DecrementUserPromptStackPtr()
	local StackPtr = self.UserPromptStackPtr
	if not StackPtr then StackPtr = 0 self.UserPromptStackPtr = StackPtr end

	StackPtr = StackPtr - 1
	if StackPtr < 0 then ErrorNoHaltWithStack("AdvDupe2: User prompt stack underflow???") StackPtr = 0 end
	self.UserPromptStackPtr = StackPtr

	return StackPtr + 1 -- +1 because we want to remove what was previously at that stack pointer
end

function BROWSER:GetUserPromptStackLength()
	return self.UserPromptStackPtr or 0
end

function BROWSER:PushUserPrompt()
	local UserPrompts  = self:GetUserPromptStack()
	local StackPointer = self:IncrementUserPromptStackPtr()
	local Prompt = USERPROMPT(self)
	UserPrompts[StackPointer] = Prompt
	return Prompt
end

function BROWSER:PopUserPrompt()
	local UserPrompts  = self:GetUserPromptStack()
	local StackPointer = self:DecrementUserPromptStackPtr()
	local Prompt       = UserPrompts[StackPointer]
	UserPrompts[StackPointer] = nil
	return Prompt
end

function BROWSER:PopUserPromptByValue(UserPrompt)
	if table.RemoveByValue(self:GetUserPromptStack(), UserPrompt) then
		if IsValid(UserPrompt.Panel) then UserPrompt.Panel:Remove() end
		self:DecrementUserPromptStackPtr()
	end
end

function BROWSER:ClearAllUserPrompts()
	for _, Prompt in ipairs(self:GetUserPromptStack()) do
		Prompt:Close()
	end
end

local WORLD  = Material("icon16/world.png", "smooth")
local FOLDER = Material("icon16/folder.png", "smooth")
local PAGE   = Material("icon16/page.png", "smooth")

function BROWSER:ShowSavePrompt()
	if self.BrowserWait then return end

	local BrowserWait = self:PushUserPrompt()
	self.BrowserWait = BrowserWait

	BrowserWait:SetDock(FILL)
	BrowserWait.Panel.ChildrenSize = function(notif)
		local Parent = notif:GetParent()
		local W, _ = Parent:GetSize()
		return W / 1.5, 128
	end
	BrowserWait:SetBlocking(true)
	BrowserWait.Panel:SetPaintBackground(true)

	local Text = BrowserWait.Panel:Add("DLabel")
	Text:SetText("Downloading...")
	Text:Dock(TOP)
	Text:SetTextInset(0, 6)
	Text:SetDark(true)
	Text:SetContentAlignment(8)

	function BrowserWait.Panel:Paint(w, h)
		DPanel.Paint(self, w, h)
		local AnimTime = 1.5
		local Time = (UserInterfaceTimeFunc() % AnimTime) / AnimTime
		local SinTime = math.sin(Time * math.pi)
		local Size = math.ease.OutQuad(SinTime) * 32

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(WORLD)  surface.DrawTexturedRectRotated(24, h / 2, 32, 32, 0)
		surface.SetMaterial(FOLDER) surface.DrawTexturedRectRotated(w - 24, h / 2, 32, 32, 0)
		surface.SetMaterial(PAGE)   surface.DrawTexturedRectRotated(math.Remap(Time, 0, 1, 24, w - 24), math.Remap(SinTime, 0, 1, h / 2, h / 3), Size, Size, 0)
	end
end

function BROWSER:HideSavePrompt()
	if not self.BrowserWait then return end
	self.BrowserWait:Close()
	self.BrowserWait = nil
end

-- Sets input enabled on user prompt stack and determines if user input should be enabled/disabled on the main browser
-- Returns true if input is enabled
-- This stuff is kinda weird, but doesnt run that much and seems to be pretty OK. Real docking seems to cause
-- layout issues that I would rather not deal with, especially during animation.
function BROWSER:ThinkAboutUserPrompts()
	local StackDocks     = self.StackDocks or {}
	StackDocks[TOP] = 0
	StackDocks[LEFT] = 0
	StackDocks[RIGHT] = 0
	StackDocks[BOTTOM] = 0

	local UserPrompts    = self:GetUserPromptStack()
	local Blocking       = false

	local LastBlockingPanel = false

	local RemoveValues
	for K, Prompt in ipairs(UserPrompts) do
		local Panel = Prompt:GetPanel()
		Panel:SetMouseInputEnabled(LastBlockingPanel and false or true)

		Panel:SetZPos(1000 + K)
		Blocking = Blocking or Prompt.Blocking

		if Prompt.Blocking then
			LastBlockingPanel = Panel
		else
			LastBlockingPanel = false
		end

		if not Prompt:DoThink() then
			RemoveValues = RemoveValues or {} -- Only allocate this table if we need to remove prompts
			RemoveValues[#RemoveValues + 1] = Prompt
		end
	end

	local DockPadding = 4

	for I = #UserPrompts, 1, -1 do
		local Prompt = UserPrompts[I]
		if Prompt and IsValid(Prompt.Panel) then
			local Panel = Prompt.Panel

			local X, Y = Panel:GetPos()
			local W, H = Panel:GetSize()
			local Dock = Prompt.Dock

			if Dock ~= NODOCK and Dock ~= FILL then
				if Dock == TOP or Dock == BOTTOM then
					Y = Y + StackDocks[Dock]
					StackDocks[Dock] = StackDocks[Dock] + H + DockPadding
				else
					X = X + StackDocks[Dock]
					StackDocks[Dock] = StackDocks[Dock] + W + DockPadding
				end
			end

			Panel:SetPos(X, Y)
		end
	end

	if RemoveValues then
		for _, Prompt in ipairs(RemoveValues) do
			self:PopUserPromptByValue(Prompt)
		end
	end

	return not Blocking
end

function BROWSER:ScrollTo(Node)
	self.TreeView:SortRecheck()
	local Index = -1

	for K, ENode in ipairs(self.TreeView.ExpandedNodeArray) do
		if ENode == Node then
			Index = K
			break
		end
	end

	if Index == -1 then return end

	local ScrollPos = math.Max(0, (Index * TallOfOneNode) - (self:GetTall() / 2))
	self.TreeView.VBar:SetScroll(ScrollPos)
end

function BROWSER:Think()
	local CanInput = self:ThinkAboutUserPrompts()
	self.TreeView:SetMouseInputEnabled(CanInput)
end

derma.DefineControl(LowercaseFileBrowserPrefix .. "_browser_panel", "AD2 File Browser", BROWSER, "Panel")

local PANEL = {}
AccessorFunc(PANEL, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(PANEL, "m_bgColor", "BackgroundColor")
Derma_Hook(PANEL, "Paint", "Paint", "Panel")
Derma_Hook(PANEL, "PerformLayout", "Layout", "Panel")

function PANEL:PerformLayout(w, h)
	if (self:GetWide() == self.LastX) then return end
	local x = self:GetWide()

	if (self.Search) then
		self.Search:SetWide(x)
	end

	self.Browser:SetWide(x)

	local BtnX
	local BtnPad = 6
	if self.LeftsideButtons then
		BtnX = BtnPad
		for _, Button in ipairs(self.LeftsideButtons) do
			Button:SetPos(BtnX, 4)
			BtnX = BtnX + Button:GetWide() + BtnPad
		end
	end

	if self.RightsideButtons then
		BtnX = w
		for _, Button in ipairs(self.RightsideButtons) do
			BtnX = BtnX - Button:GetWide() - BtnPad
			Button:SetPos(BtnX, 4)
		end
	end

	self.LastX = x
end

local pnlorigsetsize
local function PanelSetSize(self, x, y)
	if (not self.LaidOut) then
		pnlorigsetsize(self, x, y)

		self.Browser:SetSize(x, y - 24)
		self.Browser:SetPos(0, 24)

		if (self.Search) then
			self.Search:SetSize(x, y - 24)
			self.Search:SetPos(0, 24)
		end

		self.LaidOut = true
	else
		pnlorigsetsize(self, x, y)
	end

end

local function UpdateClientFiles(Browser)
	Browser.TreeView:Clear()
	Browser.TreeView:Expand()

	Browser:AddRootFolder(AdvDupe1Folder)
	Browser:AddRootFolder(AdvDupe2Folder)

	hook.Run(FileBrowserPrefix .. "_PostMenuFolders", Browser)
end

function PANEL:AddLeftsideDivider()
	self.LeftsideButtons = self.LeftsideButtons or {}

	local Panel = self:Add "DPanel"
	Panel:SetSize(2, 16)
	Panel.Paint = function(_, w, h) surface.SetDrawColor(0, 0, 0, 50) surface.DrawRect(0, 0, w, h) end

	self.LeftsideButtons[#self.LeftsideButtons + 1] = Panel
end

function PANEL:AddRightsideDivider()
	self.RightsideButtons = self.RightsideButtons or {}

	local Panel = self:Add "DPanel"
	Panel:SetSize(2, 16)
	Panel.Paint = function(_, w, h) surface.SetDrawColor(0, 0, 0, 50) surface.DrawRect(0, 0, w, h) end

	self.RightsideButtons[#self.RightsideButtons + 1] = Panel
end

function PANEL:AddLeftsideButton(Icon, Tooltip, Action)
	self.LeftsideButtons = self.LeftsideButtons or {}

	local Button = self:Add "DImageButton"
	Button:SetMaterial("icon16/" .. Icon .. ".png")
	Button:SizeToContents()
	Button:SetTooltip(Tooltip)
	Button.DoClick = Action

	self.LeftsideButtons[#self.LeftsideButtons + 1] = Button

	return Button
end

function PANEL:AddRightsideButton(Icon, Tooltip, Action)
	self.RightsideButtons = self.RightsideButtons or {}

	local Button = self:Add "DImageButton"
	Button:SetMaterial("icon16/" .. Icon .. ".png")
	Button:SizeToContents()
	Button:SetTooltip(Tooltip)
	Button.DoClick = Action

	self.RightsideButtons[#self.RightsideButtons + 1] = Button

	return Button
end

local VIEWTYPETREE_SELECTED = color_white
local VIEWTYPETREE_UNSELECTED = Color(143, 143, 143, 143)

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

	self.Browser = self:Add(LowercaseFileBrowserPrefix .. "_browser_panel")
	UpdateClientFiles(self.Browser)

	self.SearchAll     = self:AddLeftsideButton("folder_magnify", "Search all root folders", function() self.Browser:Notify("Not yet implemented!", NOTIFY_ERROR, 3) end)
	self:AddLeftsideDivider()
	self.SwitchToTree  = self:AddLeftsideButton("application_view_detail", "Tree view", function() self.Browser:Notify("Not yet implemented!", NOTIFY_ERROR, 3) end)
	self.SwitchToList  = self:AddLeftsideButton("application_view_list", "List view", function() self.Browser:Notify("Not yet implemented!", NOTIFY_ERROR, 3) end)
	self.SwitchToTiles = self:AddLeftsideButton("application_view_tile", "Tile view", function() self.Browser:Notify("Not yet implemented!", NOTIFY_ERROR, 3) end)

	self.SwitchToTree.Think  = function(b) b.m_Image:SetImageColor(self.Browser.TreeView.ViewType == VIEWTYPE_TREE and VIEWTYPETREE_SELECTED or VIEWTYPETREE_UNSELECTED) end
	self.SwitchToList.Think  = function(b) b.m_Image:SetImageColor(self.Browser.TreeView.ViewType == VIEWTYPE_LIST and VIEWTYPETREE_SELECTED or VIEWTYPETREE_UNSELECTED) end
	self.SwitchToTiles.Think = function(b) b.m_Image:SetImageColor(self.Browser.TreeView.ViewType == VIEWTYPE_TILES and VIEWTYPETREE_SELECTED or VIEWTYPETREE_UNSELECTED) end

	self.Refresh = self:AddRightsideButton("arrow_refresh", "Refresh Files", function(button)
		self.Browser:ClearAllUserPrompts()
		self.Settings:SetImage("icon16/cog.png")
		UpdateClientFiles(self.Browser)
	end)
	self.Help    = self:AddRightsideButton("help", "Help Section", function(btn)
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
	end)
	self:AddRightsideDivider()
	self.Settings = self:AddRightsideButton("cog", "Settings", function() self:OpenSettings() end)
end

function PANEL:OpenSettings()
	if self.SettingsPanel then
		self.SettingsPanel:Close()
		self.SettingsPanel = nil
		self.Settings:SetImage("icon16/cog.png")
		return
	end

	self.Settings:SetImage("icon16/cog_delete.png")

	local Panel = self.Browser:PushUserPrompt()
	self.SettingsPanel = Panel

	Panel:SetBlocking(true)
	Panel:SetDock(BOTTOM)

	local function CreateDivider()
		local Div = Panel:Add("DPanel")
		Div:Dock(TOP)
		Div:DockMargin(16, 4, 16, 4)
		Div:SetSize(0, 2)
		Div.Paint = function(_, w, h) surface.SetDrawColor(0, 0, 0, 90) surface.DrawRect(0, 0, w, h) end
	end
	local function CreateConvarSlider(ConVar, CName, Min, Max)
		local CV = GetConVar(ConVar)
		local Name = Panel:Add("DLabel")
		Name:Dock(TOP)
		Name:SetText(CName or CV:GetName())
		Name:SetDark(true)
		Name:SetTextInset(8, 0)
		Name:SetTooltip(CV:GetHelpText())
		local Slider = Panel:Add("DNumSlider")
		Slider:SetDark(true)
		Slider:Dock(TOP)
		Slider:SetSize(0, 14)
		Slider:SetConVar(ConVar)
		Slider:SetMinMax(Min or CV:GetMin(), Max or CV:GetMax())
		Slider.Scratch.PaintScratchWindow = function(s)
			if not s:GetActive() then return end
			if s:GetZoom() == 0 then s:SetZoom(s:IdealZoom()) end

			local w, h = 400, 200
			local x, y = s:LocalToScreen(0, h + 24)

			x = x + s:GetWide() * 0.5 - w * 0.5
			y = y - 8 - h

			if x + w + 32 > ScrW() then x = ScrW() - w - 32 end
			if y + h + 32 > ScrH() then y = ScrH() - h - 32 end
			if x < 32 then x = 32 end
			if y < 32 then y = 32 end

			if render then render.SetScissorRect(x, y, x + w, y + h, true) end
				s:DrawScreen(x, y, w, h)
			if render then render.SetScissorRect(x, y, w, h, false) end
		end
	end
	local function CreateConvarEntry(ConVar, CName)
		local CV = GetConVar(ConVar)
		local Name = Panel:Add("DLabel")
		Name:Dock(TOP)
		Name:SetText(CName or CV:GetName())
		Name:SetDark(true)
		Name:SetTextInset(8, 0)
		Name:SetTooltip(CV:GetHelpText())
		local Entry = Panel:Add("DTextEntry")
		Entry:Dock(TOP)
		Entry:SetSize(0, 20)
		Entry:DockMargin(8, 0, 8, 0)
		Entry:SetConVar(ConVar)
		return Entry
	end
	local function CreateConvarIconEntry(ConVar, CName)
		local Entry = CreateConvarEntry(ConVar, CName)
		local CV    = GetConVar(ConVar)

		local IconSelector = Entry:Add("DImageButton")
		IconSelector:SetSize(16, 16)
		IconSelector:DockMargin(2, 2, 2, 2)
		IconSelector:Dock(RIGHT)
		IconSelector:SetImage(CV:GetString())

		IconSelector.DoClick = function()
			local Frame = vgui.Create("DFrame")
			Frame:MakePopup()
			Frame:SetSize(480, 360)
			Frame:Center()

			local Icons = Frame:Add("DIconBrowser")
			Icons:Dock(FILL)
			Icons:SelectIcon(CV:GetString())
			Icons.OnChange = function()
				CV:SetString(Icons:GetSelectedIcon())
				IconSelector:SetImage(Icons:GetSelectedIcon())
			end
		end
	end

	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_promptopentime", "Prompt Open Animation Time (seconds)", 0, 2)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_promptclosetime", "Prompt Close Animation Time (seconds)", 0, 2)
	CreateDivider()
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_maxtimetodoubleclick", "Max Deltatime for Double Clicks (seconds)", 0, 2)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodetall", "Node Height (pixels)", 0, 256)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodepadding", "Node Height Padding (pixels)", 0, 256)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodedepthwidth", "Node Depth Width (pixels)", 0, 256)
	CreateDivider()
	CreateConvarEntry(LowercaseFileBrowserPrefix .. "_menu_nodefont", "Node Font")
	CreateDivider()
	CreateConvarIconEntry(LowercaseFileBrowserPrefix .. "_menu_nodeicon_folderempty", "Node Empty Folder Icon")
	CreateConvarIconEntry(LowercaseFileBrowserPrefix .. "_menu_nodeicon_folder", "Node Folder Icon")
	CreateConvarIconEntry(LowercaseFileBrowserPrefix .. "_menu_nodeicon_file", "Node File Icon")
	CreateDivider()
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodeexpander_size", "Node Expander Size (pixels)", 0, 256)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodeicon_size", "Node Icon Size (pixels)", 0, 256)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodepadding_toexpander", "Left -> Expander Padding (pixels)", 0, 256)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodepadding_expandertoicon", "Expander -> Icon Padding (pixels)", 0, 256)
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_nodepadding_icontotext", "Icon -> Text Padding (pixels)", 0, 256)
end

function PANEL:Slide(expand)
	-- Stub. Need to entirely remove this.
	ErrorNoHalt("AdvDupe2:Slide is no longer implemented")
end

function PANEL:GetFullPath(node)
	return GetFullPath(node)
end

function PANEL:GetNodePath(node)
	return GetNodePath(node)
end

vgui.Register(LowercaseFileBrowserPrefix .. "_browser", PANEL, "Panel")