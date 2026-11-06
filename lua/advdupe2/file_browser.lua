-- Enums
-- These are internal really, so i don't think these need to be exposed?
local NODETYPE_FOLDER          = 1
local NODETYPE_FILE            = 2
-- I may implement more of these later, just defining them now
local VIEWTYPE_TREE  = 0
local VIEWTYPE_LIST  = 1
local VIEWTYPE_TILES = 2

local SORTTYPE_NAME = 0
local SORTTYPE_TIME = 1
local SORTTYPE_SIZE = 2

-- This lets us rip this stuff out if we need to.
local TargetRootTable            = AdvDupe2
local FileBrowserPrefix          = "AdvDupe2"
local LowercaseFileBrowserPrefix = string.lower(FileBrowserPrefix)

-- Just in case this needs to be changed later

local MaxTimeToDoubleClick, NodeTall, NodePadding, TallOfOneNode, NodeDepthWidth, NodeFont, NodeFontSmall
local ExpanderSize,  IconSize, LeftmostToExpanderPadding, ExpanderToIconPadding, IconToTextPadding
local DrawTimeAlways, DateFormat
local TileIconSize, TileWidth, TileHeight

local ExpanderXOffset, IconXOffset, TextXOffset
local TimeToOpenPrompts_cv, TimeToClosePrompts_cv, ViewType_cv

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
	ViewType_cv            =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_viewtype", "0", true, false,
														"The file browser view. 0 = tree, 1 = list, 2 = tiles.", 0, 2)


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
	local NodeFontSmall_cv               =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodefontsmall", "DefaultSmall", true, false,
														"The surface.CreateFont-registered font the file browser uses for smaller fonts.")



	local NodeIconFolderEmpty_cv    =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_folderempty", "icon16/folder.png", true, false,
														"The materials/ localized path for an empty folder.")
	local NodeIconFolderContains_cv =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_folder", "icon16/folder_page.png", true, false,
														"The materials/ localized path for a folder with contents.")
	local NodeIconFile_cv           =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodeicon_file", "icon16/page.png", true, false,
														"The materials/ localized path for a file.")

	local DrawTimeAlways_cv          =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_nodedrawtimealways", "0", true, false,
														"When 0: the time is only drawn when sorting by time.\nWhen 1: the time will always draw\nWhen -1: the time will never draw.")
	local DateFormat_cv              =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_dateformat", "%Y/%m/%d %H:%M", true, false,
														"The format passed into os.date.")
	local TileIconSize_cv            =   CreateClientConVar(LowercaseFileBrowserPrefix .. "_menu_tileiconsize", "32", true, false,
														"The size, in pixels, of a folder or file icon in tile view.", 8, 256)

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
		NodeFontSmall		 = NodeFontSmall_cv:GetString()

		ExpanderSize              = ExpanderSize_cv:GetFloat()
		IconSize                  = IconSize_cv:GetFloat()
		LeftmostToExpanderPadding = LeftmostToExpanderPadding_cv:GetFloat()
		ExpanderToIconPadding     = ExpanderToIconPadding_cv:GetFloat()
		IconToTextPadding         = IconToTextPadding_cv:GetFloat()

		ExpanderXOffset = LeftmostToExpanderPadding
		IconXOffset     = ExpanderXOffset + ExpanderSize + ExpanderToIconPadding
		TextXOffset     = IconXOffset + IconSize + IconToTextPadding

		DrawTimeAlways = DrawTimeAlways_cv:GetInt()
		DateFormat     = DateFormat_cv:GetString()

		TileIconSize = math.Clamp(TileIconSize_cv:GetFloat(), 8, 256)
		TileWidth    = math.max(TileIconSize + 48, 72)
		TileHeight   = TileIconSize + 36

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

local ListTimeWidth, ListSizeWidth = 116, 72
local ListHeaderTall, NavBarTall   = 20, 24

local function GetListColumns(Width)
	local SizeRight = Width - 6
	local TimeRight = SizeRight - ListSizeWidth
	local NameRight = TimeRight - ListTimeWidth
	return NameRight, TimeRight, SizeRight
end

local function GetListTextX()
	return LeftmostToExpanderPadding + IconSize + IconToTextPadding
end

local TruncatedText, TruncatedCount = {}, 0
local function TruncateText(Text, Font, MaxWidth)
	local Key    = Font .. "\0" .. math.floor(MaxWidth) .. "\0" .. Text
	local Cached = TruncatedText[Key]
	if Cached then return Cached end

	surface.SetFont(Font)
	local Result = Text
	if surface.GetTextSize(Text) > MaxWidth then
		local Starts = {}
		for Position in string.gmatch(Text, "()" .. utf8.charpattern) do
			Starts[#Starts + 1] = Position
		end

		Result = "..."
		for Count = #Starts - 1, 1, -1 do
			local Candidate = string.sub(Text, 1, Starts[Count + 1] - 1) .. "..."
			if surface.GetTextSize(Candidate) <= MaxWidth then
				Result = Candidate
				break
			end
		end
	end

	if TruncatedCount > 4096 then
		TruncatedText, TruncatedCount = {}, 0
	end
	TruncatedText[Key] = Result
	TruncatedCount = TruncatedCount + 1
	return Result
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

local NODE_MT = {}
local NODE    = setmetatable({}, NODE_MT)
do
	local LoadDataFolderInternal

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

	function NODE:GetTime()
		if not self.Path then return 0 end
		if self.Time then return self.Time end

		local Time = file.Time(self.Path, "DATA")
		self.Time = Time or 0 -- I don't think it will return nil but I don't want to spam file.Time requests
		return Time
	end

	function NODE:GetTimeString()
		if self.TimeStr then return self.TimeStr end
		local Time = self:GetTime()
		if Time == 0 then return "" end
		local TimeStr = os.date(DateFormat, Time)
		self.TimeStr = TimeStr
		return TimeStr
	end

	function NODE:GetSize()
		if not self.Path or self:IsFolder() then return 0 end
		if self.Size then return self.Size end

		self.Size = file.Size(self.Path, "DATA") or 0
		return self.Size
	end

	function NODE:GetSizeString()
		if self:IsFolder() then return "" end
		if self.SizeStr then return self.SizeStr end

		self.SizeStr = string.NiceSize(self:GetSize())
		return self.SizeStr
	end

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

	function NODE:ExpandRecursive()
		self:SetExpanded(true)
		for _, Folder in ipairs(self.Folders) do Folder:ExpandRecursive() end
	end

	function NODE:CollapseRecursive()
		self:SetExpanded(false)
		for _, Folder in ipairs(self.Folders) do Folder:CollapseRecursive() end
	end

	function NODE:SetDataPath(Path)
		local Name   = string.GetFileFromFilename(Path)
		self.Path    = Path
		self.Text    = self:IsFile() and string.StripExtension(Name) or Name
		self.Time    = nil
		self.TimeStr = nil
		self.Size    = nil
		self.SizeStr = nil
	end

	function NODE:AddDataFile(Path)
		local Node = self:AddFile()
		Node:SetDataPath(Path)

		return Node
	end

	function NODE:AddDataFolder(Path)
		local Node = self:AddFolder()
		Node:SetDataPath(Path)
		Node.FirstObserved = function(DirNode) -- note FirstObserved will be destroyed after first call
			LoadDataFolderInternal(DirNode, Path .. "/")
		end

		return Node
	end

	function NODE:LoadAll()
		if self.FirstObserved then
			self:FirstObserved()
			self.FirstObserved = nil
		end

		for _, Folder in ipairs(self.Folders) do Folder:LoadAll() end
	end

	function NODE:FindFileByPath(Path)
		for _, File in ipairs(self.Files) do
			if File.Path == Path then return File end
		end
	end

	-- Expects a directory path ending in a forward slash.
	function LoadDataFolderInternal(Node, Path)
		local Files, Directories = file.Find(Path .. "*", "DATA", "nameasc")
		if not Files or not Directories then return end

		for _, File in ipairs(Files) do
			Node:AddDataFile(Path .. File)
		end

		for _, Directory in ipairs(Directories) do
			Node:AddDataFolder(Path .. Directory)
		end
	end

	function NODE:LoadDataFolder(Path)
		self:Clear()
		LoadDataFolderInternal(self, Path)
	end

	function NODE:PerformResort(SortFunction)
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
		if not self.KeepOrder then
			table.sort(Sorted, SortFunction)
		end
	end

	-- Returns an enumerator<Node>
	function NODE:GetSortedChildNodes(SortFunction)
		self:PerformResort(SortFunction)
		return ipairs(self.Sorted)
	end

	function NODE.InjectIntoBrowser(TreeView, Browser)
		for FuncName, Func in pairs(NODE) do
			TreeView[FuncName] = Func
		end

		NODE.Init(TreeView, NODETYPE_FOLDER, Browser)
	end
end

-- This interface describes the logic behind a root folder.

local IRootFolder_MT = {}
local IRootFolder    = setmetatable({}, IRootFolder_MT)

do
	TargetRootTable.IRootFolder = IRootFolder -- If other addons want to post-verify their IRootFolder implementations like we do

	-- todo; debug.getinfo and determine argument counts to further sanity check?
	IRootFolder.Init             = function(Impl, Browser, Node) end
	IRootFolder.GetFolderName    = function(Impl) end
	IRootFolder.GetPlaceholderText = function(Impl, Field) end
	IRootFolder.GetNameFilter    = function(Impl) end
	-- These define node operations
	-- These are RAW operations, as in the underlying Browser might do some prompts first
	-- But for example, calling IRootFolder:UserDelete() is expected to actually delete the node
	-- (and the browser will create the prompt)
	IRootFolder.UserLoad         = function(Impl, Browser, Node) end
	IRootFolder.UserPreview      = function(Impl, Browser, Node) end
	IRootFolder.UserSave         = function(Impl, Browser, Node, Filename, Description) end
	IRootFolder.UserRename       = function(Impl, Browser, Node, RenameTo) end
	IRootFolder.UserMove         = function(Impl, Browser, Node, TargetFolder) end
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
				ErrorNoHaltWithStack(FileBrowserPrefix .. ": IRootFolder implementation failed to implement " .. FuncName .. ", this may not work as intended...")
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
		if self.OnClose and not self.Closing then self:OnClose() end

		self.Blocking    = false
		self.Closing     = true
		self.StartClose  = UserInterfaceTimeFunc()
		self.WillCloseAt = self.StartClose + TimeToClosePrompts_cv:GetFloat()
	end
end

local DataFolderRoot_MT = {}
local DataFolderRoot    = setmetatable({}, DataFolderRoot_MT)

do
	TargetRootTable.DataFolderRoot = DataFolderRoot

	function DataFolderRoot_MT:__call(Name, BasePath)
		if Name == nil then return error("Cannot create a nameless data folder root") end
		if BasePath == nil then return error("Cannot create a data folder root without a base path") end

		return setmetatable({
			Name       = Name,
			BasePath   = BasePath,
			NameFilter = "[^%w_ ]",
			-- Key-weak LUT's for size/modtimes.
			-- They're key-weak so if a node gets deleted it isn't hung up by GC thinking
			-- we care about the reference still
			SizeCache = setmetatable({}, {__mode = 'k'}),
			TimeCache = setmetatable({}, {__mode = 'k'})
		}, {__index = DataFolderRoot})
	end

	local function DeleteDataFolder(Path)
		local Files, Directories = file.Find(Path .. "/*", "DATA")

		for _, File in ipairs(Files or {}) do file.Delete(Path .. "/" .. File) end
		for _, Directory in ipairs(Directories or {}) do DeleteDataFolder(Path .. "/" .. Directory) end

		file.Delete(Path)
	end

	local function GetFreeDataPath(Directory, Name, Extension)
		local Suffix = Extension and ("." .. Extension) or ""
		local Path   = Directory .. Name .. Suffix
		if not file.Exists(Path, "DATA") then return Path end

		for I = 1, 256 do
			Path = string.format("%s%s_%03d%s", Directory, Name, I, Suffix)
			if not file.Exists(Path, "DATA") then return Path end
		end
	end

	function DataFolderRoot:GetFolderName() return self.Name end
	function DataFolderRoot:GetPlaceholderText(Field) end
	function DataFolderRoot:GetNameFilter() return self.NameFilter end

	function DataFolderRoot:CanDeleteNode(Node)
		return not Node:IsRoot()
	end

	function DataFolderRoot:Init(Browser, Node)
		Node.Path = self.BasePath
		Node:LoadDataFolder(self.BasePath .. "/")
	end

	function DataFolderRoot:UserLoad(Browser, Node) end
	function DataFolderRoot:UserPreview(Browser, Node) end
	function DataFolderRoot:UserSave(Browser, Node, Filename, Description) end

	function DataFolderRoot:UserRename(Browser, Node, RenameTo)
		if not Node:IsFile() then return false end
		if RenameTo == Node.Text then return true end

		local Extension = string.GetExtensionFromFilename(Node.Path)
		local NewPath   = GetFreeDataPath(string.GetPathFromFilename(Node.Path), RenameTo, Extension)

		if not NewPath or not file.Rename(Node.Path, NewPath) then return false end

		Node:SetDataPath(NewPath)
		Node.ParentNode:MarkSortDirty()
		Browser:ScrollTo(Node)
		return true
	end

	function DataFolderRoot:UserMove(Browser, Node, TargetFolder)
		if not Node:IsFile() or not TargetFolder:IsFolder() then return false end

		local Extension = string.GetExtensionFromFilename(Node.Path)
		local Name      = string.StripExtension(string.GetFileFromFilename(Node.Path))
		local NewPath   = GetFreeDataPath(TargetFolder.Path .. "/", Name, Extension)

		if not NewPath or not file.Rename(Node.Path, NewPath) then return false end

		Node:Remove()
		local NewNode = TargetFolder:AddDataFile(NewPath)
		TargetFolder:Expand()
		Browser:ScrollTo(NewNode)
		return true
	end

	function DataFolderRoot:UserMenu(Browser, Node, Menu)
		if Node:IsFile() then
			Menu:AddOption("Open",    function() self:UserLoad(Browser, Node)  end, "icon16/page_go.png")
			Menu:AddOption("Preview", function() self:UserPreview(Browser, Node) end, "icon16/information.png")
			Menu:AddSpacer()
			Menu:AddOption("Rename...", function() Browser:StartRename(Node) end, "icon16/textfield_rename.png")
			Menu:AddOption("Move...",   function() Browser:StartMove(Node)   end, "icon16/arrow_right.png")
			if self:CanDeleteNode(Node) then
				Menu:AddOption("Delete", function() Browser:StartDelete(Node) end, "icon16/bin_closed.png")
			end
		else
			Menu:AddOption("Save",       function() Browser:StartSave(Node)   end, "icon16/disk.png")
			Menu:AddOption("New Folder", function() Browser:StartFolder(Node) end, "icon16/folder_add.png")
			Menu:AddSpacer()
			Menu:AddOption("Search",     function() Browser:StartSearch(Node) end, "icon16/magnifier.png")
			if self:CanDeleteNode(Node) then
				Menu:AddOption("Delete", function() Browser:StartDelete(Node) end, "icon16/bin_closed.png")
			end
		end
	end

	function DataFolderRoot:UserDelete(Browser, Node)
		if not self:CanDeleteNode(Node) then return false end

		if Node:IsFolder() then
			DeleteDataFolder(Node.Path)
		else
			file.Delete(Node.Path)
		end

		local Success = not file.Exists(Node.Path, "DATA")
		if Success then
			Node:Remove()
		end
		return Success
	end

	function DataFolderRoot:UserMakeFolder(Browser, Node, Foldername)
		local DataPath = Node.Path .. "/" .. Foldername
		if file.Exists(DataPath, "DATA") then return false, "Folder name already exists." end

		file.CreateDir(DataPath)

		local NewNode = Node:AddDataFolder(DataPath)
		Node:Expand()
		NewNode:Expand()
		Browser:ScrollTo(NewNode)
		return true
	end

	function DataFolderRoot:UserGetModTime(Browser, Node)
		local Time = self.TimeCache[Node]
		if Time then return Time end

		Time = file.Time(Node.Path, "DATA")
		self.TimeCache[Node] = Time
		return Time
	end

	function DataFolderRoot:UserGetSize(Browser, Node)
		if Node:IsFolder() then return -1 end

		local Size = self.SizeCache[Node]
		if Size then return Size end

		Size = file.Size(Node.Path, "DATA")
		self.SizeCache[Node] = Size
		return Size
	end
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
	self.KeepOrder         = true
	self.SortDirty         = true
	self.ExpandedNodeArray = {}
	self.CurrentFolder     = self
	self.BackHistory       = {}
	self.ForwardHistory    = {}

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
			if self.ViewType == VIEWTYPE_TREE then
				Node:ToggleExpanded()
			else
				self.Browser:NavigateTo(Node)
			end
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

	if self:IsSearching() then
		Menu:AddOption("Open",    function() RootImpl:UserLoad(self.Browser, Node)    end, "icon16/page_go.png")
		Menu:AddOption("Preview", function() RootImpl:UserPreview(self.Browser, Node) end, "icon16/information.png")
	else
		RootImpl:UserMenu(self.Browser, Node, Menu)

		if self.ViewType == VIEWTYPE_TREE then
			Menu:AddSpacer()
			Menu:AddOption("Collapse Folder", function()
				if Node.ParentNode ~= self then Node.ParentNode:CollapseRecursive() end
			end, "icon16/arrow_in.png")
			Menu:AddOption("Collapse Root", function() Node.Root:CollapseRecursive() end, "icon16/arrow_up.png")
		end
	end

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

-- annoying this cant be a parameter but whatever
local AscendingSwitch

local function SortNodesByName(A, B)
	local IsFileA, IsFileB = A:IsFile(), B:IsFile()

	if not IsFileA and IsFileB then return true end
	if IsFileA and not IsFileB then return false end

	local NameA, NameB = GetNumericalFilename(A.Text), GetNumericalFilename(B.Text)

	for I = 1, math.max(#NameA, #NameB) do
		local AC, BC = NameA[I], NameB[I]

		if AC == nil then return true end
		if BC == nil then return false end

		if AC ~= BC then
			if AscendingSwitch then
				return AC < BC
			else
				return AC > BC
			end
		end
	end
end

local function SortNodesByTime(A, B)
	local IsFileA, IsFileB = A:IsFile(), B:IsFile()

	if not IsFileA and IsFileB then return true end
	if IsFileA and not IsFileB then return false end

	local TA, TB = A:GetTime(), B:GetTime()
	if TA ~= TB then
		if AscendingSwitch then
			return TA < TB
		else
			return TA > TB
		end
	end
end

local function SortNodesBySize(A, B)
	local IsFileA, IsFileB = A:IsFile(), B:IsFile()

	if not IsFileA and IsFileB then return true end
	if IsFileA and not IsFileB then return false end

	local SA, SB = A:GetSize(), B:GetSize()
	if SA ~= SB then
		if AscendingSwitch then
			return SA < SB
		else
			return SA > SB
		end
	end

	return SortNodesByName(A, B)
end

local DoRecursiveVistesting function DoRecursiveVistesting(Parent, ExpandedNodeArray, Depth, SortFunction)
	Depth = Depth or 0
	for _, Child in Parent:GetSortedChildNodes(SortFunction) do
		Child.Depth = Depth
		ExpandedNodeArray[#ExpandedNodeArray + 1] = Child
		if Child.Expanded then
			DoRecursiveVistesting(Child, ExpandedNodeArray, Depth + 1, SortFunction)
		end
	end
end

function BROWSERTREE:GetSortFunction()
	local SortType = self.SortType

	if SortType == SORTTYPE_NAME then
		return SortNodesByName
	elseif SortType == SORTTYPE_TIME then
		return SortNodesByTime
	elseif SortType == SORTTYPE_SIZE then
		return SortNodesBySize
	else
		return SortNodesByName
	end
end

local function IsAttached(Tree, Node)
	while Node ~= Tree do
		local Parent = Node and Node.ParentNode
		if not Parent or not table.HasValue(Parent.Folders, Node) then return false end
		Node = Parent
	end

	return true
end

-- This function collapses the current node state into a single sequential array
function BROWSERTREE:SortRecheck()
	if not self.SortDirty then return end

	table.Empty(self.ExpandedNodeArray)
	AscendingSwitch = self.Ascending
	local SortFunction = self:GetSortFunction()

	if self.SearchResults then
		table.sort(self.SearchResults, SortFunction)
		for _, Node in ipairs(self.SearchResults) do
			Node.Depth = 0
			self.ExpandedNodeArray[#self.ExpandedNodeArray + 1] = Node
		end
	elseif self.ViewType == VIEWTYPE_TREE then
		DoRecursiveVistesting(self, self.ExpandedNodeArray, nil, SortFunction)
	else
		while not IsAttached(self, self.CurrentFolder) do
			self.CurrentFolder = self.CurrentFolder.ParentNode or self
		end

		for _, Child in self.CurrentFolder:GetSortedChildNodes(SortFunction) do
			Child.Depth = 0
			self.ExpandedNodeArray[#self.ExpandedNodeArray + 1] = Child
		end
	end

	-- This is how tall we are
	self:SetTall(math.max(self:GetContentHeight(), self:GetParent():GetTall()))

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

local function CollectSearchResults(Node, Needle, Results)
	for _, File in ipairs(Node.Files) do
		if string.find(string.lower(File.Text), Needle, 1, true) then
			Results[#Results + 1] = File
		end
	end

	for _, Folder in ipairs(Node.Folders) do
		CollectSearchResults(Folder, Needle, Results)
	end
end

function BROWSERTREE:GetNodeIndex(Node)
	for Index, ENode in ipairs(self.ExpandedNodeArray) do
		if ENode == Node then return Index end
	end
end

function BROWSERTREE:GetTileColumns()
	return math.max(1, math.floor((self:GetWide() - self.VBar:GetWide()) / TileWidth))
end

function BROWSERTREE:GetContentHeight()
	local Count = #self.ExpandedNodeArray

	if self.ViewType == VIEWTYPE_TILES then
		return math.ceil(Count / self:GetTileColumns()) * TileHeight
	end

	return Count * TallOfOneNode
end

function BROWSERTREE:GetIndexBounds(Index, Scroll, Width, Depth)
	if self.ViewType == VIEWTYPE_TILES then
		local Columns   = self:GetTileColumns()
		local CellWidth = (Width - self.VBar:GetWide()) / Columns
		local Column    = (Index - 1) % Columns
		local Row       = math.floor((Index - 1) / Columns)

		return Column * CellWidth, (Row * TileHeight) - Scroll, CellWidth, TileHeight
	end

	return GetNodeBounds(Scroll, Index, Width, Depth)
end

function BROWSERTREE:GetVisibleRange(Scroll, ViewHeight)
	local Count = #self.ExpandedNodeArray

	if self.ViewType == VIEWTYPE_TILES then
		local Columns  = self:GetTileColumns()
		local FirstRow = math.floor(Scroll / TileHeight)
		local LastRow  = math.floor((Scroll + ViewHeight) / TileHeight)

		return (FirstRow * Columns) + 1, math.min((LastRow + 1) * Columns, Count)
	end

	return math.max(math.floor(Scroll / TallOfOneNode) + 1, 1), math.min(math.floor((Scroll + ViewHeight) / TallOfOneNode) + 1, Count)
end

function BROWSERTREE:GetIndexY(Index)
	local _, Y = self:GetIndexBounds(Index, 0, self:GetWide(), 0)
	return Y
end

function BROWSERTREE:IsSearching()
	return self.SearchResults ~= nil
end

function BROWSERTREE:StartSearch(TargetNode, Query)
	TargetNode:LoadAll()

	local Results = {}
	CollectSearchResults(TargetNode, string.lower(Query), Results)

	if not self.SearchResults then
		self.ScrollBeforeSearch = self.VBar:GetScroll()
	end

	self.SearchResults = Results
	self.SortDirty     = true
	self.VBar:SetScroll(0)

	return #Results
end

function BROWSERTREE:EndSearch()
	if not self.SearchResults then return end

	self.SearchResults = nil
	self.SortDirty     = true
	self:SortRecheck()
	self.VBar:SetScroll(self.ScrollBeforeSearch or 0)
	self.ScrollBeforeSearch = nil
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
	ImmediateState.StartIndex, ImmediateState.EndIndex = self:GetVisibleRange(Scroll, self:GetParent():GetTall())

	-- Vis testing parameters
	ImmediateState.TotalVisibleNodes = (ImmediateState.EndIndex - ImmediateState.StartIndex)
	-- We test against this array subspan for mouse events
	local BreakInputTesting = not CanInput -- if can't input, never even do input testing
	local IsTree            = self.ViewType == VIEWTYPE_TREE and not self:IsSearching()
	ImmediateState.Hovered           = false
	ImmediateState.IsExpanderHovered = false
	for AbsIndex = ImmediateState.StartIndex, ImmediateState.EndIndex do
		local Node = self.ExpandedNodeArray[AbsIndex]

		if not BreakInputTesting then
			local X, Y, W, H  = self:GetIndexBounds(AbsIndex, ImmediateState.Scroll, ImmediateState.Width, Node.Depth)
			local MouseInRect = ImmediateState:IsMouseInRect(X, Y, W, H) and ImmediateState.PanelHovered
			if MouseInRect then
				ImmediateState.Hovered           = Node
				ImmediateState.IsExpanderHovered = IsTree and Node:IsFolder() and ImmediateState:IsMouseInRect(GetExpanderBounds(X, Y, W, H, nil, Node.Depth))

				if ImmediateState.Mouse.Clicked then
					ImmediateState.Depressed           = Node
					ImmediateState.IsExpanderDepressed = ImmediateState.IsExpanderHovered
				end

				if ImmediateState.Mouse.Released then
					ImmediateState.ReleasedNode = ImmediateState.Depressed
					ImmediateState.IsExpanderReleased = ImmediateState.IsExpanderHovered
				end

				BreakInputTesting = true
			end
		end
	end

	ImmediateState.EmptyClicked = CanInput and ImmediateState.PanelHovered and not ImmediateState.Hovered and ImmediateState.Mouse.Clicked or nil

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

	local EmptyClicked = ImmediateState.EmptyClicked
	if EmptyClicked and self.ViewType ~= VIEWTYPE_TREE and not self:IsSearching() then
		local Folder = self.CurrentFolder ~= self and self.CurrentFolder or nil
		if EmptyClicked == MOUSE_LEFT then
			self:SetSelected(Folder)
		elseif EmptyClicked == MOUSE_RIGHT and Folder then
			self:DoNodeRightClick(Folder)
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

local function GetNodeIcon(Node)
	if Node:IsFolder() then
		return Node:Count() > 0 and ICON_FOLDER_CONTAINS or ICON_FOLDER_EMPTY
	end

	return ICON_FILE
end

function BROWSERTREE:PaintNodeBackground(SkinTex, Node, IsHovered, IsDepressed, X, Y, W, H, Always)
	if IsDepressed then
		SkinTex.Panels.Dark(X, Y, W, H, color_white)
	elseif Node.Selected and self.FolderPick and self.FolderPick(Node) then
		SkinTex.Panels.Highlight(X, Y, W, H, color_white)
	elseif Node.Selected or IsHovered then
		SkinTex.Panels.Bright(X, Y, W, H, color_white)
	elseif Always then
		SkinTex.Panels.Normal(X, Y, W, H, color_white)
	end
end

-- This function paints the current immediate state to the DPanel.
function BROWSERTREE:PaintCurrentState(PanelWidth, PanelHeight)
	local Skin           = self:GetSkin()
	local SkinTex        = Skin.tex
	local TextColor      = Skin.colTextEntryText or color_black

	local ImmediateState = self.ImmediateState
	local ScrollOffset   = ImmediateState.Scroll
	local Width          = ImmediateState.Width

	local ViewType       = self.ViewType
	local ContentWidth   = PanelWidth - (self.VBar:IsVisible() and self.VBar:GetWide() or 0)
	local NameRight, TimeRight, SizeRight = GetListColumns(ContentWidth)

	for AbsIndex = ImmediateState.StartIndex, ImmediateState.EndIndex do
		local Node = self.ExpandedNodeArray[AbsIndex]
		if Node then
			local IsHovered      = ImmediateState.Hovered   == Node
			local IsDepressed    = ImmediateState.Depressed == Node
			local NX, NY, NW, NH = self:GetIndexBounds(AbsIndex, ScrollOffset, Width, Node.Depth)

			if ViewType == VIEWTYPE_TILES then
				self:PaintNodeBackground(SkinTex, Node, IsHovered, IsDepressed, NX + 2, NY + 2, NW - 4, NH - 4)

				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(GetNodeIcon(Node))
				surface.DrawTexturedRect(NX + ((NW - TileIconSize) / 2), NY + 8, TileIconSize, TileIconSize)

				draw.SimpleText(TruncateText(Node.Text or "", NodeFont, NW - 8), NodeFont, NX + (NW / 2), NY + 14 + TileIconSize, TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			elseif ViewType == VIEWTYPE_LIST then
				self:PaintNodeBackground(SkinTex, Node, IsHovered, IsDepressed, NX, NY, NW, NH, true)

				local TextY = NY + (NH / 2)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(GetNodeIcon(Node))
				surface.DrawTexturedRect(NX + LeftmostToExpanderPadding, TextY - (IconSize / 2), IconSize, IconSize)

				local TextX = NX + GetListTextX()
				draw.SimpleText(TruncateText(Node.Text or "", NodeFont, NameRight - TextX - 8), NodeFont, TextX, TextY, TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(Node:GetTimeString(), NodeFont, TimeRight, TextY, TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				draw.SimpleText(Node:GetSizeString(), NodeFont, SizeRight, TextY, TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			else
				local IsExpanderHovered   = IsHovered and ImmediateState.IsExpanderHovered
				local IsExpanderDepressed = IsDepressed and ImmediateState.IsExpanderDepressed

				local IX, IY, IW, IH      = GetIconBounds(NX, NY, NW, NH, nil, Node.Depth)
				local EX, EY, EW, EH      = GetExpanderBounds(NX, NY, NW, NH, IsExpanderDepressed and -2 or IsExpanderHovered and 2 or 0, Node.Depth)
				local TextX, TextY        = GetTextPosition(NX, NY, NW, NH, Node.Depth)

				-- Paint background
				self:PaintNodeBackground(SkinTex, Node, IsHovered, IsDepressed, NX, NY, NW, NH, true)

				-- Paint expander
				if Node:IsFolder() and Node:Count() > 0 then
					if not Node.Expanded then
						SkinTex.TreePlus(EX, EY, EW, EH)
					else
						SkinTex.TreeMinus(EX, EY, EW, EH)
					end
				end

				if DrawTimeAlways ~= -1 then
					if DrawTimeAlways == 1 or self.SortType == SORTTYPE_TIME then
						draw.SimpleText(Node:GetTimeString(), NodeFontSmall, ContentWidth - 4, TextY, TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					end
				end

				-- Paint icon
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(GetNodeIcon(Node))
				surface.DrawTexturedRect(IX, IY, IW, IH)

				-- Paint text
				draw.SimpleText(Node.Text or "<nil value>", NodeFont, TextX, TextY, TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
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
	if self.LastTileHeight ~= TileHeight or self.LastNodeHeight ~= TallOfOneNode then
		self.LastTileHeight, self.LastNodeHeight = TileHeight, TallOfOneNode
		self.SortDirty = true
	end
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
	self:MarkSortDirty()
end

function BROWSER:Init()
	setbrowserpnlsize = self.SetSize
	self.SetSize = SetBrowserPnlSize
	self.TreeView = vgui.Create(LowercaseFileBrowserPrefix .. "_browser_tree", self)

	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetBackgroundColor(self:GetSkin().text_bright)

	self:SetViewType(math.Clamp(ViewType_cv:GetInt(), VIEWTYPE_TREE, VIEWTYPE_TILES))
	self:SetSortType(SORTTYPE_NAME)
	self:SetAscending(true)
end

-- Public facing API

function BROWSER:SetViewType(ViewType)
	ViewType = ViewType or error("No viewtype provided")

	local Tree     = self.TreeView
	local Previous = Tree.ViewType
	if Previous == ViewType then return end

	Tree.ViewType = ViewType
	ViewType_cv:SetInt(ViewType)
	self:MarkSortDirty()

	if ViewType ~= VIEWTYPE_TREE and (Previous == nil or Previous == VIEWTYPE_TREE) then
		local Selected = Tree:GetSelectedItem()
		self:ResetNavigation(Selected and Selected.ParentNode)
	end

	local Selected = Tree:GetSelectedItem()
	if Selected and TallOfOneNode then
		self:ScrollTo(Selected)
	else
		Tree.VBar:SetScroll(0)
	end
end

function BROWSER:GetViewType()
	return self.TreeView.ViewType
end

local function FindFolderByPath(Node, Path)
	for _, Folder in ipairs(Node.Folders) do
		if Folder.Path == Path then return Folder end

		if Folder.Path and string.StartsWith(Path, Folder.Path .. "/") then
			if Folder.FirstObserved then
				Folder:FirstObserved()
				Folder.FirstObserved = nil
			end

			return FindFolderByPath(Folder, Path)
		end
	end
end

function BROWSER:FindFolderByPath(Path)
	return FindFolderByPath(self.TreeView, Path)
end

function BROWSER:GetCurrentFolder()
	return self.TreeView.CurrentFolder
end

function BROWSER:ResetNavigation(Folder)
	local Tree = self.TreeView
	table.Empty(Tree.BackHistory)
	table.Empty(Tree.ForwardHistory)

	if not Folder or not Folder:IsFolder() then
		Folder = #Tree.Folders == 1 and Tree.Folders[1] or Tree
	end

	Tree.CurrentFolder = Folder
	self:MarkSortDirty()
end

function BROWSER:NavigateTo(Folder, KeepHistory)
	local Tree = self.TreeView
	Folder = Folder or Tree
	if not Folder:IsFolder() or Folder == Tree.CurrentFolder then return end

	self:EndSearch()

	if Folder.FirstObserved then
		Folder:FirstObserved()
		Folder.FirstObserved = nil
	end

	if not KeepHistory then
		Tree.BackHistory[#Tree.BackHistory + 1] = Tree.CurrentFolder
		table.Empty(Tree.ForwardHistory)
	end

	Tree.CurrentFolder = Folder
	self:MarkSortDirty()
	Tree.VBar:SetScroll(0)
end

local function PopAttached(Tree, Stack)
	while #Stack > 0 do
		local Folder = table.remove(Stack)
		if IsAttached(Tree, Folder) then return Folder end
	end
end

function BROWSER:CanNavigateBack()    return #self.TreeView.BackHistory > 0    end
function BROWSER:CanNavigateForward() return #self.TreeView.ForwardHistory > 0 end
function BROWSER:CanNavigateUp()      return self.TreeView.CurrentFolder ~= self.TreeView end

function BROWSER:NavigateBack()
	local Tree   = self.TreeView
	local Folder = PopAttached(Tree, Tree.BackHistory)
	if not Folder then return end

	Tree.ForwardHistory[#Tree.ForwardHistory + 1] = Tree.CurrentFolder
	self:NavigateTo(Folder, true)
end

function BROWSER:NavigateForward()
	local Tree   = self.TreeView
	local Folder = PopAttached(Tree, Tree.ForwardHistory)
	if not Folder then return end

	Tree.BackHistory[#Tree.BackHistory + 1] = Tree.CurrentFolder
	self:NavigateTo(Folder, true)
end

function BROWSER:NavigateUp()
	local Tree = self.TreeView
	if Tree.CurrentFolder == Tree then return end

	self:NavigateTo(Tree.CurrentFolder.ParentNode)
end

function BROWSER:KeepSelectedInPlace(Change)
	local Tree     = self.TreeView
	local Selected = Tree:GetSelectedItem()
	if not Selected then return Change() end

	Tree:SortRecheck()
	local OldIndex = Tree:GetNodeIndex(Selected)

	Change()
	if not OldIndex then return end

	Tree:SortRecheck()
	local NewIndex = Tree:GetNodeIndex(Selected)
	if not NewIndex then return end

	Tree.VBar:SetScroll(Tree.VBar:GetScroll() + (Tree:GetIndexY(NewIndex) - Tree:GetIndexY(OldIndex)))
end

function BROWSER:SetSortType(SortType)
	self:KeepSelectedInPlace(function()
		self.TreeView.SortType = SortType or error("No sorttype provided")
		self:MarkSortDirty()
	end)
end

function BROWSER:SetAscending(Ascending)
	self:KeepSelectedInPlace(function()
		self.TreeView.Ascending = Ascending == true
		self:MarkSortDirty()
	end)
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

	print("[" .. FileBrowserPrefix .. "] " .. tostring(Message))

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

local History = {}

local function AddHistory(Text)
	Text = string.lower(Text or "")
	if Text == "" or table.HasValue(History, Text) then return end

	History[#History + 1] = Text
	table.sort(History)
end

local function SetupNameEntry(Entry, NameFilter)
	local MenuKey      = string.lower(input.LookupBinding("menu") or "q")
	local PreviousText = Entry:GetText()
	local FirstChange  = true

	function Entry:OnChange()
		local Text = self:GetText()

		if FirstChange then
			FirstChange = false
			if string.lower(Text) == MenuKey then
				self:SetText(PreviousText)
				self:SelectAllText()
				return
			end
		end

		if NameFilter then
			local Filtered, Count = string.gsub(Text, NameFilter, "")
			if Count > 0 then
				self:SetText(Filtered)
				self:SetCaretPos(#Filtered)
			end
		end
	end

	function Entry:GetAutoComplete(Text)
		if Text == "" then return end
		Text = string.lower(Text)

		local Options = {}
		for _, Name in ipairs(History) do
			if Name ~= Text and string.sub(Name, 1, #Text) == Text then
				Options[#Options + 1] = Name
				if #Options >= 8 then break end
			end
		end

		return Options
	end
end

local function FollowSelection(Label, Tree, GetText)
	local LastText

	function Label:Think()
		DLabel.Think(self)

		local Text = GetText(Tree:GetSelectedItem())
		if Text ~= LastText then
			LastText = Text
			self:SetText(Text)
		end
	end
end

local function SharedFileFolderLogic(self, Node, DoDesc, NameTextPlaceholder, DescTextPlaceholder, Icon, Completed, LastName, LastDesc, NameFilter, PickFolder)
	local Prompt = self:PushUserPrompt()
	Prompt:SetBlocking(not PickFolder)
	Prompt:SetDock(BOTTOM)
	Prompt.Panel:DockPadding(4,4,4,4)

	if PickFolder then
		local function IsValidTarget(Target) return Target ~= nil and Target:IsFolder() end
		self:SetFolderPick(Prompt, IsValidTarget)

		local Where = Prompt:Add("DLabel")
			Where:Dock(TOP)
			Where:SetDark(true)
			Where:SetTall(18)

		FollowSelection(Where, self.TreeView, function(Target)
			if IsValidTarget(Target) then return "Save to " .. Target.Path end
			return "Select a folder to save to."
		end)
	end

	local Name, Desc, Cancel, Save

	local function FinishSave()
		-- Require filename
		local FileName = Name:GetText()
		if FileName == nil or FileName == "" then
			self:Notify("You must specify a file/folder path.", NOTIFY_ERROR, 2)
			return
		end

		local Target = Node
		if PickFolder then
			Target = self.TreeView:GetSelectedItem()
			if not Target or not Target:IsFolder() then
				self:Notify("You must select a folder.", NOTIFY_ERROR, 2)
				return
			end
		end

		local RootImpl = self:GetRootImpl(Target)
		if Completed(self, RootImpl, Target, FileName, Desc and Desc:GetText() or "") == false then return end

		AddHistory(FileName)
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

	SetupNameEntry(Name, NameFilter)

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

	Name:RequestFocus()
	Name:OnMousePressed()
end

function BROWSER:GetPlaceholderText(Node, Field, Default)
	return self:GetRootImpl(Node):GetPlaceholderText(Field) or Default
end

function BROWSER:StartSave(Node)
	if not Node:IsFolder() then ErrorNoHaltWithStack(FileBrowserPrefix .. ": Attempted to call StartSave on a non-folder. Operation canceled.") return false end

	local NamePlaceholder = self:GetPlaceholderText(Node, "SaveName", "File name")
	local DescPlaceholder = self:GetPlaceholderText(Node, "SaveDescription", "Description")
	local NameFilter      = self:GetRootImpl(Node):GetNameFilter()

	SharedFileFolderLogic(self, Node, true, NamePlaceholder, DescPlaceholder, "disk", function(_, RootImpl, _, FileName, Desc)
		RootImpl:UserSave(self, Node, FileName, Desc)
		self.LastFileName = FileName
		self.LastFileDesc = Desc
	end, self.LastFileName, self.LastFileDesc, NameFilter)
end

function BROWSER:IsSearching()
	return self.TreeView:IsSearching()
end

function BROWSER:EndSearch()
	if self.SearchPrompt then
		self.SearchPrompt:Close()
		self.SearchPrompt = nil
	end

	self.TreeView:EndSearch()
end

local function CreatePromptRow(Prompt)
	local Row = Prompt:Add("Panel")
		Row:Dock(TOP)
		Row:DockMargin(0, 4, 0, 0)
		Row:SetSize(20, 20)
		Row:SetPaintBackgroundEnabled(false)
		Row:SetZPos(10000)

	return Row
end

local function CreatePromptButton(Row, Icon, Size)
	local Button = Row:Add("DImageButton")
		Button:Dock(RIGHT)
		Button:SetSize(Size or 20)
		Button:SetStretchToFit(false)
		Button:SetImage("icon16/" .. Icon .. ".png")

	return Button
end

function BROWSER:ShowSearchResults(Count, Query)
	local Prompt = self:PushUserPrompt()
	Prompt:SetDock(BOTTOM)
	Prompt.Panel:DockPadding(4,4,4,4)
	self.SearchPrompt = Prompt

	local Row = CreatePromptRow(Prompt)

	local Return = CreatePromptButton(Row, "arrow_undo")
		Return:SetTooltip("Return to Browser")

	local Info = Row:Add("DLabel")
		Info:Dock(FILL)
		Info:SetDark(true)
		Info:SetText(Count .. " files found searching for \"" .. Query .. "\"")

	function Return.DoClick()
		self:EndSearch()
	end
end

local LastSearch = ""
function BROWSER:StartSearch(Node)
	if not Node:IsFolder() then ErrorNoHaltWithStack(FileBrowserPrefix .. ": Attempted to call StartSearch on a non-folder. Operation canceled.") return false end

	self:EndSearch()

	local Prompt = self:PushUserPrompt()
	Prompt:SetDock(BOTTOM)
	Prompt.Panel:DockPadding(4,4,4,4)
	self.SearchPrompt = Prompt

	local Row    = CreatePromptRow(Prompt)
	local Cancel = CreatePromptButton(Row, "cancel")
	local Find   = CreatePromptButton(Row, "magnifier", 24)
		Find:SetTooltip("Search Files")

	local Search = Row:Add("DTextEntry")
		Search:SetAllowNonAsciiCharacters(true)
		Search:Dock(FILL)
		Search:SetPlaceholderText("Search...")
		Search:SetText(LastSearch)

	SetupNameEntry(Search)

	local function RunSearch()
		local Query = Search:GetText()
		LastSearch = Query
		AddHistory(Query)

		Prompt:Close()
		self.SearchPrompt = nil
		self:ShowSearchResults(self.TreeView:StartSearch(Node, Query), Query)
	end

	function Search:OnEnter()
		RunSearch()
	end

	function Search:OnMousePressed()
		self:OnGetFocus()
		self:SelectAllOnFocus(true)
	end

	function Find.DoClick()
		RunSearch()
	end

	function Cancel.DoClick()
		self:EndSearch()
	end

	Search:RequestFocus()
	Search:OnMousePressed()
end

function BROWSER:StartFolder(Node)
	if not Node:IsFolder() then ErrorNoHaltWithStack(FileBrowserPrefix .. ": Attempted to call StartFolder on a non-folder. Operation canceled.") return false end

	local NamePlaceholder = self:GetPlaceholderText(Node, "FolderName", "Folder name")
	local NameFilter      = self:GetRootImpl(Node):GetNameFilter()

	SharedFileFolderLogic(self, Node, false, NamePlaceholder, nil, "folder_add", function(_, RootImpl, _, FileName)
		local Success, Reason = RootImpl:UserMakeFolder(self, Node, FileName)
		if Success == false then
			self:Notify(Reason or "Could not create the folder.", NOTIFY_ERROR, 3)
			return false
		end
	end, nil, nil, NameFilter)
end

function BROWSER:StartRename(Node)
	local NameFilter = self:GetRootImpl(Node):GetNameFilter()

	SharedFileFolderLogic(self, Node, false, "New name", nil, "page_edit", function(_, RootImpl, _, FileName)
		if not RootImpl:UserRename(self, Node, FileName) then
			self:Notify("Rename failed.", NOTIFY_ERROR, 5)
			return false
		end

		self:Notify("File renamed to " .. Node.Text .. ".", NOTIFY_GENERIC, 3)
	end, Node.Text, nil, NameFilter)
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
		Name:SetText("Are you sure you want to delete\n" .. Node.Path .. "?")
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

function BROWSER:SetFolderPick(Prompt, Validate)
	local Tree = self.TreeView
	Tree.FolderPick = Validate

	Prompt.OnClose = function()
		if Tree.FolderPick == Validate then Tree.FolderPick = nil end
	end
end

function BROWSER:StartPickFolder(NamePlaceholder, DescPlaceholder, Icon, Callback, NameFilter)
	SharedFileFolderLogic(self, nil, true, NamePlaceholder, DescPlaceholder, Icon, function(_, _, Folder, FileName, Desc)
		Callback(Folder, FileName, Desc)
	end, nil, nil, NameFilter, true)
end

function BROWSER:StartMove(Node)
	if not Node:IsFile() then ErrorNoHaltWithStack(FileBrowserPrefix .. ": Attempted to call StartMove on a non-file. Operation canceled.") return false end

	local Prompt = self:PushUserPrompt()
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

	local Move = DescParent:Add("DImageButton")
		Move:Dock(RIGHT)
		Move:SetSize(24)
		Move:SetStretchToFit(false)
		Move:SetImage("icon16/page_paste.png")

	local function IsValidTarget(Target)
		return Target ~= nil and Target:IsFolder() and Target.Root == Node.Root and Target ~= Node.ParentNode
	end
	self:SetFolderPick(Prompt, IsValidTarget)

	local Name = DescParent:Add("DLabel")
		Name:Dock(FILL)
		Name:SetDark(true)
		Name:SetAutoStretchVertical(true)
		Name:SetZPos(1)

	FollowSelection(Name, self.TreeView, function(Target)
		if IsValidTarget(Target) then return "Move \"" .. Node.Text .. "\" to\n" .. Target.Path end
		return "Select the folder you want to move\n" .. Node.Text .. " to."
	end)

	function Move.DoClick()
		local Target = self.TreeView:GetSelectedItem()
		if not Target or Target == Node then
			self:Notify("Select a folder to move the file to.", NOTIFY_ERROR, 3)
			return
		end

		if not Target:IsFolder() then
			self:Notify("You must select a folder as a destination.", NOTIFY_ERROR, 3)
			return
		end

		if Target.Root ~= Node.Root or Target == Node.ParentNode then
			self:Notify("Cannot move files between these directories.", NOTIFY_ERROR, 3)
			return
		end

		if not self:GetRootImpl(Node):UserMove(self, Node, Target) then
			self:Notify("Move failed.", NOTIFY_ERROR, 5)
			return
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
	if StackPtr < 0 then ErrorNoHaltWithStack(FileBrowserPrefix .. ": User prompt stack underflow???") StackPtr = 0 end
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
	local Index = self.TreeView:GetNodeIndex(Node)
	if not Index then return end

	local ScrollPos = math.Max(0, self.TreeView:GetIndexY(Index) - (self:GetTall() / 2))
	self.TreeView.VBar:SetScroll(ScrollPos)
end

function BROWSER:Think()
	local CanInput = self:ThinkAboutUserPrompts()
	self.TreeView:SetMouseInputEnabled(CanInput)
end

derma.DefineControl(LowercaseFileBrowserPrefix .. "_browser_panel", FileBrowserPrefix .. " File Browser", BROWSER, "Panel")

local PANEL = {}
AccessorFunc(PANEL, "m_bBackground", "PaintBackground", FORCE_BOOL)
AccessorFunc(PANEL, "m_bgColor", "BackgroundColor")
Derma_Hook(PANEL, "Paint", "Paint", "Panel")
Derma_Hook(PANEL, "PerformLayout", "Layout", "Panel")

function PANEL:PerformLayout(w, h)
	local ViewType = self.Browser:GetViewType()
	local Top      = 24

	local ShowNavBar = ViewType ~= VIEWTYPE_TREE
	self.NavBar:SetVisible(ShowNavBar)
	if ShowNavBar then
		self.NavBar:SetPos(0, Top)
		self.NavBar:SetSize(w, NavBarTall)
		Top = Top + NavBarTall
	end

	local ShowHeader = ViewType == VIEWTYPE_LIST
	self.ListHeader:SetVisible(ShowHeader)
	if ShowHeader then
		self.ListHeader:SetPos(0, Top)
		self.ListHeader:SetSize(w, ListHeaderTall)
		Top = Top + ListHeaderTall
	end

	self.Browser:SetPos(0, Top)
	self.Browser:SetSize(w, math.max(h - Top, 0))

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
end

local function UpdateClientFiles(Browser)
	local Tree     = Browser.TreeView
	local OpenPath = Tree.CurrentFolder ~= Tree and Tree.CurrentFolder.Path or nil

	Browser:EndSearch()
	Tree:Clear()
	Tree:Expand()

	hook.Run(FileBrowserPrefix .. "_PostMenuFolders", Browser)

	Browser:ResetNavigation(OpenPath and Browser:FindFolderByPath(OpenPath))
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

function PANEL:AddLeftsideButton(Icon, Tooltip, Action, Index)
	self.LeftsideButtons = self.LeftsideButtons or {}

	local Button = self:Add "DImageButton"
	Button:SetMaterial("icon16/" .. Icon .. ".png")
	Button:SizeToContents()
	Button:SetTooltip(Tooltip)
	Button:SetTooltipDelay(0)
	Button.DoClick = Action

	table.insert(self.LeftsideButtons, Index or #self.LeftsideButtons + 1, Button)
	self:InvalidateLayout()

	return Button
end

function PANEL:AddRightsideButton(Icon, Tooltip, Action, Index)
	self.RightsideButtons = self.RightsideButtons or {}

	local Button = self:Add "DImageButton"
	Button:SetMaterial("icon16/" .. Icon .. ".png")
	Button:SizeToContents()
	Button:SetTooltip(Tooltip)
	Button:SetTooltipDelay(0)
	Button.DoClick = Action

	table.insert(self.RightsideButtons, Index or #self.RightsideButtons + 1, Button)
	self:InvalidateLayout()

	return Button
end

local COLOR_SELECTED = color_white
local COLOR_UNSELECTED = Color(143, 143, 143, 143)

local ICON_SORT_UP   = Material("icon16/bullet_arrow_up.png")
local ICON_SORT_DOWN = Material("icon16/bullet_arrow_down.png")

function PANEL:CreateNavBar()
	local Browser = self.Browser
	local Tree    = Browser.TreeView

	local Bar = self:Add("Panel")
	self.NavBar = Bar

	local function AddNavButton(Icon, Tooltip, Action, IsEnabled)
		local Button = Bar:Add("DImageButton")
		Button:SetImage("icon16/" .. Icon .. ".png")
		Button:SetStretchToFit(false)
		Button:SetSize(20, 20)
		Button:SetTooltip(Tooltip)
		Button:SetTooltipDelay(0)
		Button.DoClick = Action
		Button.Think = function(b) b.m_Image:SetImageColor(IsEnabled() and COLOR_SELECTED or COLOR_UNSELECTED) end
		return Button
	end

	Bar.Buttons = {
		AddNavButton("arrow_left",  "Back",    function() Browser:NavigateBack()    end, function() return Browser:CanNavigateBack()    end),
		AddNavButton("arrow_right", "Forward", function() Browser:NavigateForward() end, function() return Browser:CanNavigateForward() end),
		AddNavButton("arrow_up",    "Up",      function() Browser:NavigateUp()      end, function() return Browser:CanNavigateUp()      end),
	}

	local Path = Bar:Add("Panel")
	Bar.Path   = Path
	Path.Items = {}

	function Path:Paint(w, h)
		self:GetSkin().tex.Panels.Normal(0, 0, w, h, color_white)
	end

	local function PaintSegment(Segment, w, h)
		if Segment:IsHovered() then
			Segment:GetSkin().tex.Panels.Bright(0, 0, w, h, color_white)
		end
	end

	local function AddLabel(Text)
		local Label = Path:Add("DLabel")
		Label:SetFont(NodeFont)
		Label:SetText(Text)
		Label:SetDark(true)
		Label:SetContentAlignment(5)
		Label:SizeToContentsX(12)
		return Label
	end

	Path.Ellipsis = AddLabel("...")

	local function AddSegment(Node)
		local Segment
		if Node == Tree then
			Segment = Path:Add("DImageButton")
			Segment:SetImage("icon16/house.png")
			Segment:SetStretchToFit(false)
			Segment:SetWide(24)
			Segment:SetTooltip("All folders")
			Segment:SetTooltipDelay(0)
		else
			Segment = AddLabel(Node.Text or "")
			Segment:SetMouseInputEnabled(true)
		end

		Segment.Paint   = PaintSegment
		Segment.DoClick = function() Browser:NavigateTo(Node) end
		Path.Items[#Path.Items + 1] = Segment
	end

	function Path:Rebuild(Current)
		for _, Item in ipairs(self.Items) do Item:Remove() end
		table.Empty(self.Items)

		local Chain = {}
		local Node  = Current
		while Node and Node ~= Tree do
			table.insert(Chain, 1, Node)
			Node = Node.ParentNode
		end

		AddSegment(Tree)
		for _, Folder in ipairs(Chain) do
			Path.Items[#Path.Items + 1] = AddLabel(">")
			AddSegment(Folder)
		end

		self.CurrentFolder = Current
		self:InvalidateLayout()
	end

	function Path:Think()
		if self.CurrentFolder ~= Tree.CurrentFolder then
			self:Rebuild(Tree.CurrentFolder)
		end
	end

	function Path:PerformLayout(w, h)
		local Items = self.Items
		if #Items == 0 then return end

		local Total = 0
		for _, Item in ipairs(Items) do Total = Total + Item:GetWide() end

		local First = 2
		if Total > w then
			local Used = Items[1]:GetWide() + self.Ellipsis:GetWide()
			First = #Items + 1
			while First > 2 and Used + Items[First - 1]:GetWide() <= w do
				First = First - 1
				Used  = Used + Items[First]:GetWide()
			end
		end

		local X = 0
		local function Place(Item)
			Item:SetVisible(true)
			Item:SetPos(X, 0)
			Item:SetTall(h)
			X = X + Item:GetWide()
		end

		Place(Items[1])
		self.Ellipsis:SetVisible(First > 2)
		if First > 2 then Place(self.Ellipsis) end

		for I = 2, #Items do
			if I >= First then
				Place(Items[I])
			else
				Items[I]:SetVisible(false)
			end
		end
	end

	function Bar:PerformLayout(w, h)
		local X = 4
		for _, Button in ipairs(self.Buttons) do
			Button:SetPos(X, (h - 20) / 2)
			X = X + 22
		end

		self.Path:SetPos(X + 2, 2)
		self.Path:SetSize(math.max(w - X - 8, 0), h - 4)
	end
end

function PANEL:CreateListHeader()
	local Browser = self.Browser
	local Tree    = Browser.TreeView

	local Header = self:Add("Panel")
	Header:SetMouseInputEnabled(true)
	self.ListHeader = Header

	local Columns = {
		{Text = "Name",     SortType = SORTTYPE_NAME, Align = TEXT_ALIGN_LEFT},
		{Text = "Modified", SortType = SORTTYPE_TIME, Align = TEXT_ALIGN_RIGHT},
		{Text = "Size",     SortType = SORTTYPE_SIZE, Align = TEXT_ALIGN_RIGHT},
	}

	local function UpdateColumnBounds()
		local Width = Header:GetWide() - (Tree.VBar:IsVisible() and Tree.VBar:GetWide() or 0)
		local NameRight, TimeRight, SizeRight = GetListColumns(Width)

		Columns[1].Left, Columns[1].Right, Columns[1].TextX = 0,         NameRight, GetListTextX()
		Columns[2].Left, Columns[2].Right, Columns[2].TextX = NameRight, TimeRight, TimeRight
		Columns[3].Left, Columns[3].Right, Columns[3].TextX = TimeRight, Width,     SizeRight
	end

	local function GetHoveredColumn()
		if not Header:IsHovered() then return end

		local MouseX = Header:CursorPos()
		for _, Column in ipairs(Columns) do
			if MouseX >= Column.Left and MouseX < Column.Right then return Column end
		end
	end

	function Header:Paint(w, h)
		local Skin      = self:GetSkin()
		local TextColor = Skin.colTextEntryText or color_black

		UpdateColumnBounds()
		Skin.tex.Panels.Normal(0, 0, w, h, color_white)

		local Hovered = GetHoveredColumn()
		for _, Column in ipairs(Columns) do
			if Column == Hovered then
				Skin.tex.Panels.Bright(Column.Left, 0, Column.Right - Column.Left, h, color_white)
			end

			draw.SimpleText(Column.Text, NodeFont, Column.TextX, h / 2, TextColor, Column.Align, TEXT_ALIGN_CENTER)

			if Tree.SortType == Column.SortType then
				local TextWidth = surface.GetTextSize(Column.Text)
				local ArrowX    = Column.Align == TEXT_ALIGN_LEFT and (Column.TextX + TextWidth + 2) or (Column.TextX - TextWidth - 18)

				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(Tree.Ascending and ICON_SORT_UP or ICON_SORT_DOWN)
				surface.DrawTexturedRect(ArrowX, (h / 2) - 8, 16, 16)
			end
		end

		surface.SetDrawColor(0, 0, 0, 50)
		surface.DrawRect(0, h - 1, w, 1)
	end

	function Header:OnMousePressed(Code)
		if Code ~= MOUSE_LEFT then return end

		UpdateColumnBounds()
		local Column = GetHoveredColumn()
		if not Column then return end

		if Tree.SortType == Column.SortType then
			Browser:SetAscending(not Tree.Ascending)
		else
			Browser:SetSortType(Column.SortType)
		end
	end
end

function PANEL:Think()
	local ViewType = self.Browser:GetViewType()
	if ViewType ~= self.LastViewType then
		self.LastViewType = ViewType
		self:InvalidateLayout()
	end
end

function PANEL:Init()
	FlushConvars()

	self:SetPaintBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetBackgroundColor(self:GetSkin().bg_color_bright)

	self.Browser = self:Add(LowercaseFileBrowserPrefix .. "_browser_panel")
	self:CreateNavBar()
	self:CreateListHeader()
	UpdateClientFiles(self.Browser)

	self.SearchAll     = self:AddLeftsideButton("folder_magnify", "Search all root folders", function()
		self.Browser:StartSearch(self.Browser.TreeView)
	end)
	do
		self:AddLeftsideDivider()
		self.SwitchToTree  = self:AddLeftsideButton("application_side_tree", "Tree view", function() self.Browser:SetViewType(VIEWTYPE_TREE) end)
		self.SwitchToList  = self:AddLeftsideButton("application_view_detail", "List view", function() self.Browser:SetViewType(VIEWTYPE_LIST) end)
		self.SwitchToTiles = self:AddLeftsideButton("application_view_tile", "Tile view", function() self.Browser:SetViewType(VIEWTYPE_TILES) end)

		self.SwitchToTree.Think  = function(b) b.m_Image:SetImageColor(self.Browser:GetViewType() == VIEWTYPE_TREE and COLOR_SELECTED or COLOR_UNSELECTED) end
		self.SwitchToList.Think  = function(b) b.m_Image:SetImageColor(self.Browser:GetViewType() == VIEWTYPE_LIST and COLOR_SELECTED or COLOR_UNSELECTED) end
		self.SwitchToTiles.Think = function(b) b.m_Image:SetImageColor(self.Browser:GetViewType() == VIEWTYPE_TILES and COLOR_SELECTED or COLOR_UNSELECTED) end
	end
	do
		self:AddLeftsideDivider()
		self.SwitchToName  = self:AddLeftsideButton("text_replace", "Sort by Name", function() self.Browser:SetSortType(SORTTYPE_NAME) end)
		self.SwitchToTime  = self:AddLeftsideButton("time", "Sort by Time", function() self.Browser:SetSortType(SORTTYPE_TIME) end)

		self.SwitchAscending  = self:AddLeftsideButton("arrow_up", "Sort Ascending", function() self.Browser:SetAscending(true) end)
		self.SwitchDescending  = self:AddLeftsideButton("arrow_down", "Sort Descending", function() self.Browser:SetAscending(false) end)

		self.SwitchAscending.Think  = function(b) b.m_Image:SetImageColor(self.Browser.TreeView.Ascending and COLOR_SELECTED or COLOR_UNSELECTED) end
		self.SwitchDescending.Think  = function(b) b.m_Image:SetImageColor(not self.Browser.TreeView.Ascending and COLOR_SELECTED or COLOR_UNSELECTED) end

		self.SwitchToName.Think  = function(b) b.m_Image:SetImageColor(self.Browser.TreeView.SortType == SORTTYPE_NAME and COLOR_SELECTED or COLOR_UNSELECTED) end
		self.SwitchToTime.Think  = function(b) b.m_Image:SetImageColor(self.Browser.TreeView.SortType == SORTTYPE_TIME and COLOR_SELECTED or COLOR_UNSELECTED) end
	end
	self.Refresh = self:AddRightsideButton("arrow_refresh", "Refresh Files", function(button)
		self.Browser:ClearAllUserPrompts()
		self.SettingsPanel = nil
		self.Settings:SetImage("icon16/cog.png")
		UpdateClientFiles(self.Browser)
	end)
	self:AddRightsideDivider()
	self.Settings = self:AddRightsideButton("cog", "Settings", function() self:OpenSettings() end)

	hook.Run(FileBrowserPrefix .. "_BrowserCreated", self)
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
	CreateDivider()
	CreateConvarSlider(LowercaseFileBrowserPrefix .. "_menu_tileiconsize", "Tile Icon Size (pixels)", 8, 128)
end

vgui.Register(LowercaseFileBrowserPrefix .. "_browser", PANEL, "Panel")