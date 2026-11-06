return function(FileBrowser)
	local VIEWTYPE_TREE         = FileBrowser.VIEWTYPE_TREE
	local VIEWTYPE_LIST         = FileBrowser.VIEWTYPE_LIST
	local VIEWTYPE_TILES        = FileBrowser.VIEWTYPE_TILES
	local SORTTYPE_NAME         = FileBrowser.SORTTYPE_NAME
	local SORTTYPE_TIME         = FileBrowser.SORTTYPE_TIME
	local SORTTYPE_SIZE         = FileBrowser.SORTTYPE_SIZE
	local UserInterfaceTimeFunc = FileBrowser.UserInterfaceTimeFunc
	local GetNodeBounds         = FileBrowser.GetNodeBounds
	local GetExpanderBounds     = FileBrowser.GetExpanderBounds
	local GetIconBounds         = FileBrowser.GetIconBounds
	local GetTextPosition       = FileBrowser.GetTextPosition
	local GetListColumns        = FileBrowser.GetListColumns
	local GetListTextX          = FileBrowser.GetListTextX
	local TruncateText          = FileBrowser.TruncateText
	local GetNumericalFilename  = FileBrowser.GetNumericalFilename
	local NODE                  = FileBrowser.NODE

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
		local Settings = self.Settings
		if self.m_pSelectedItem == Node and UserInterfaceTimeFunc() - self.LastClick <= Settings.MaxTimeToDoubleClick then -- Check for double click
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
		local Settings = self.Settings
		return math.max(1, math.floor((self:GetWide() - self.VBar:GetWide()) / Settings.TileWidth))
	end

	function BROWSERTREE:GetContentHeight()
		local Settings = self.Settings
		local Count = #self.ExpandedNodeArray

		if self.ViewType == VIEWTYPE_TILES then
			return math.ceil(Count / self:GetTileColumns()) * Settings.TileHeight
		end

		return Count * Settings.TallOfOneNode
	end

	function BROWSERTREE:GetIndexBounds(Index, Scroll, Width, Depth)
		local Settings = self.Settings
		if self.ViewType == VIEWTYPE_TILES then
			local Columns   = self:GetTileColumns()
			local CellWidth = (Width - self.VBar:GetWide()) / Columns
			local Column    = (Index - 1) % Columns
			local Row       = math.floor((Index - 1) / Columns)

			return Column * CellWidth, (Row * Settings.TileHeight) - Scroll, CellWidth, Settings.TileHeight
		end

		return GetNodeBounds(Settings, Scroll, Index, Width, Depth)
	end

	function BROWSERTREE:GetVisibleRange(Scroll, ViewHeight)
		local Settings = self.Settings
		local Count = #self.ExpandedNodeArray

		if self.ViewType == VIEWTYPE_TILES then
			local Columns  = self:GetTileColumns()
			local FirstRow = math.floor(Scroll / Settings.TileHeight)
			local LastRow  = math.floor((Scroll + ViewHeight) / Settings.TileHeight)

			return (FirstRow * Columns) + 1, math.min((LastRow + 1) * Columns, Count)
		end

		return math.max(math.floor(Scroll / Settings.TallOfOneNode) + 1, 1), math.min(math.floor((Scroll + ViewHeight) / Settings.TallOfOneNode) + 1, Count)
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
		local Settings = self.Settings
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
					ImmediateState.IsExpanderHovered = IsTree and Node:IsFolder() and ImmediateState:IsMouseInRect(GetExpanderBounds(Settings, X, Y, W, H, nil, Node.Depth))

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

	local function GetNodeIcon(Settings, Node)
		if Node:IsFolder() then
			return Node:Count() > 0 and Settings.IconFolderContains or Settings.IconFolderEmpty
		end

		return Settings.IconFile
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
		local Settings = self.Settings
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
					surface.SetMaterial(GetNodeIcon(Settings, Node))
					surface.DrawTexturedRect(NX + ((NW - Settings.TileIconSize) / 2), NY + 8, Settings.TileIconSize, Settings.TileIconSize)

					draw.SimpleText(TruncateText(Node.Text or "", Settings.NodeFont, NW - 8), Settings.NodeFont, NX + (NW / 2), NY + 14 + Settings.TileIconSize, TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				elseif ViewType == VIEWTYPE_LIST then
					self:PaintNodeBackground(SkinTex, Node, IsHovered, IsDepressed, NX, NY, NW, NH, true)

					local TextY = NY + (NH / 2)
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(GetNodeIcon(Settings, Node))
					surface.DrawTexturedRect(NX + Settings.LeftmostToExpanderPadding, TextY - (Settings.IconSize / 2), Settings.IconSize, Settings.IconSize)

					local TextX = NX + GetListTextX(Settings)
					draw.SimpleText(TruncateText(Node.Text or "", Settings.NodeFont, NameRight - TextX - 8), Settings.NodeFont, TextX, TextY, TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(Node:GetTimeString(), Settings.NodeFont, TimeRight, TextY, TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					draw.SimpleText(Node:GetSizeString(), Settings.NodeFont, SizeRight, TextY, TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				else
					local IsExpanderHovered   = IsHovered and ImmediateState.IsExpanderHovered
					local IsExpanderDepressed = IsDepressed and ImmediateState.IsExpanderDepressed

					local IX, IY, IW, IH      = GetIconBounds(Settings, NX, NY, NW, NH, nil, Node.Depth)
					local EX, EY, EW, EH      = GetExpanderBounds(Settings, NX, NY, NW, NH, IsExpanderDepressed and -2 or IsExpanderHovered and 2 or 0, Node.Depth)
					local TextX, TextY        = GetTextPosition(Settings, NX, NY, NW, NH, Node.Depth)

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

					if Settings.DrawTimeAlways ~= -1 then
						if Settings.DrawTimeAlways == 1 or self.SortType == SORTTYPE_TIME then
							draw.SimpleText(Node:GetTimeString(), Settings.NodeFontSmall, ContentWidth - 4, TextY, TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
						end
					end

					-- Paint icon
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(GetNodeIcon(Settings, Node))
					surface.DrawTexturedRect(IX, IY, IW, IH)

					-- Paint text
					draw.SimpleText(Node.Text or "<nil value>", Settings.NodeFont, TextX, TextY, TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
		local Settings = self.Settings
		Settings:Flush()
		if self.LastTileHeight ~= Settings.TileHeight or self.LastNodeHeight ~= Settings.TallOfOneNode then
			self.LastTileHeight, self.LastNodeHeight = Settings.TileHeight, Settings.TallOfOneNode
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

	FileBrowser.TreeTable = vgui.RegisterTable(BROWSERTREE, "Panel")

	FileBrowser.IsAttached = IsAttached
end
