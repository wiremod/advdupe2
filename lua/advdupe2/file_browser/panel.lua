return function(FileBrowser)
	local VIEWTYPE_TREE  = FileBrowser.VIEWTYPE_TREE
	local VIEWTYPE_LIST  = FileBrowser.VIEWTYPE_LIST
	local VIEWTYPE_TILES = FileBrowser.VIEWTYPE_TILES
	local SORTTYPE_NAME  = FileBrowser.SORTTYPE_NAME
	local SORTTYPE_TIME  = FileBrowser.SORTTYPE_TIME
	local SORTTYPE_SIZE  = FileBrowser.SORTTYPE_SIZE
	local ListHeaderTall = FileBrowser.ListHeaderTall
	local NavBarTall     = FileBrowser.NavBarTall
	local GetListColumns = FileBrowser.GetListColumns
	local GetListTextX   = FileBrowser.GetListTextX
	local GetSkinTextColor = FileBrowser.GetSkinTextColor
	local DrawSkinPanel    = FileBrowser.DrawSkinPanel
	local DrawSkinState    = FileBrowser.DrawSkinState
	local GetStateTextColor = FileBrowser.GetStateTextColor

	local PANEL = {}
	AccessorFunc(PANEL, "m_bBackground", "PaintBackground", FORCE_BOOL)
	AccessorFunc(PANEL, "m_bgColor", "BackgroundColor")
	Derma_Hook(PANEL, "Paint", "Paint", "Panel")
	Derma_Hook(PANEL, "PerformLayout", "Layout", "Panel")

	function PANEL:PerformLayout(w, h)
		if not self.Browser then return end

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

		for _, RootFolder in ipairs(Browser.Settings.RootFolders) do
			Browser:AddRootFolder(RootFolder)
		end

		Browser:ResetNavigation(OpenPath and Browser:FindFolderByPath(OpenPath))
	end

	function PANEL:AddLeftsideDivider()
		self.LeftsideButtons = self.LeftsideButtons or {}

		local Panel = self:Add "DPanel"
		Panel:SetSize(2, 16)
		Panel.Paint = function(Divider, w, h) surface.SetDrawColor(GetSkinTextColor(Divider:GetSkin(), 50)) surface.DrawRect(0, 0, w, h) end

		self.LeftsideButtons[#self.LeftsideButtons + 1] = Panel
	end

	function PANEL:AddRightsideDivider()
		self.RightsideButtons = self.RightsideButtons or {}

		local Panel = self:Add "DPanel"
		Panel:SetSize(2, 16)
		Panel.Paint = function(Divider, w, h) surface.SetDrawColor(GetSkinTextColor(Divider:GetSkin(), 50)) surface.DrawRect(0, 0, w, h) end

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
		local Settings = self.Settings
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
			local Skin = self:GetSkin()
			DrawSkinPanel(Skin, "Normal", 0, 0, w, h)

			local TextColor = GetStateTextColor(Skin, "Normal")
			for _, Item in ipairs(self.Items) do
				if Item.ClassName == "DLabel" and not Item:IsHovered() then Item:SetTextColor(TextColor) end
			end
			self.Ellipsis:SetTextColor(TextColor)
		end

		local function PaintSegment(Segment, w, h)
			if Segment:IsHovered() then
				local TextColor = DrawSkinState(Segment:GetSkin(), "Hovered", 0, 0, w, h)
				if Segment.ClassName == "DLabel" then Segment:SetTextColor(TextColor) end
			end
		end

		local function AddLabel(Text)
			local Label = Path:Add("DLabel")
			Label:SetFont(Settings.NodeFont)
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
		local Settings = self.Settings
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

			Columns[1].Left, Columns[1].Right, Columns[1].TextX = 0,         NameRight, GetListTextX(Settings)
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
			local Skin = self:GetSkin()

			UpdateColumnBounds()
			DrawSkinPanel(Skin, "Normal", 0, 0, w, h)

			local Hovered = GetHoveredColumn()
			for _, Column in ipairs(Columns) do
				local TextColor = GetStateTextColor(Skin, "Normal")
				if Column == Hovered then
					TextColor = DrawSkinState(Skin, "Hovered", Column.Left, 0, Column.Right - Column.Left, h)
				end

				draw.SimpleText(Column.Text, Settings.NodeFont, Column.TextX, h / 2, TextColor, Column.Align, TEXT_ALIGN_CENTER)

				if Tree.SortType == Column.SortType then
					local TextWidth = surface.GetTextSize(Column.Text)
					local ArrowX    = Column.Align == TEXT_ALIGN_LEFT and (Column.TextX + TextWidth + 2) or (Column.TextX - TextWidth - 18)

					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(Tree.Ascending and ICON_SORT_UP or ICON_SORT_DOWN)
					surface.DrawTexturedRect(ArrowX, (h / 2) - 8, 16, 16)
				end
			end

			surface.SetDrawColor(GetSkinTextColor(Skin, 50))
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
		if not self.Browser then return end

		local ViewType = self.Browser:GetViewType()
		if ViewType ~= self.LastViewType then
			self.LastViewType = ViewType
			self:InvalidateLayout()
		end
	end

	function PANEL:Init()
		self:SetPaintBackground(true)
		self:SetPaintBackgroundEnabled(false)
		self:SetBackgroundColor(self:GetSkin().bg_color_bright)
	end

	function PANEL:Setup(Settings)
		self.Settings = Settings or error("No settings provided")
		Settings:Flush()

		self.Browser = vgui.CreateFromTable(FileBrowser.BrowserTable, self)
		self.Browser:Setup(Settings)
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
			self.SettingsButton:SetImage("icon16/cog.png")
			UpdateClientFiles(self.Browser)
		end)
		self:AddRightsideDivider()
		self.SettingsButton = self:AddRightsideButton("cog", "Settings", function() self:OpenSettings() end)

		for _, Callback in ipairs(Settings.CreatedCallbacks) do
			Callback(self)
		end
	end

	function PANEL:OpenSettings()
		local Settings = self.Settings
		if self.SettingsPanel then
			self.SettingsPanel:Close()
			self.SettingsPanel = nil
			self.SettingsButton:SetImage("icon16/cog.png")
			return
		end

		self.SettingsButton:SetImage("icon16/cog_delete.png")

		local Panel = self.Browser:PushUserPrompt()
		self.SettingsPanel = Panel

		Panel:SetBlocking(true)
		Panel:SetDock(BOTTOM)

		local function CreateDivider()
			local Div = Panel:Add("DPanel")
			Div:Dock(TOP)
			Div:DockMargin(16, 4, 16, 4)
			Div:SetSize(0, 2)
			Div.Paint = function(Divider, w, h) surface.SetDrawColor(GetSkinTextColor(Divider:GetSkin(), 90)) surface.DrawRect(0, 0, w, h) end
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

		CreateConvarSlider(Settings:GetConVarName("PromptOpenTime"), "Prompt Open Animation Time (seconds)", 0, 2)
		CreateConvarSlider(Settings:GetConVarName("PromptCloseTime"), "Prompt Close Animation Time (seconds)", 0, 2)
		CreateDivider()
		CreateConvarSlider(Settings:GetConVarName("MaxTimeToDoubleClick"), "Max Deltatime for Double Clicks (seconds)", 0, 2)
		CreateConvarSlider(Settings:GetConVarName("NodeTall"), "Node Height (pixels)", 0, 256)
		CreateConvarSlider(Settings:GetConVarName("NodePadding"), "Node Height Padding (pixels)", 0, 256)
		CreateConvarSlider(Settings:GetConVarName("NodeDepthWidth"), "Node Depth Width (pixels)", 0, 256)
		CreateDivider()
		CreateConvarEntry(Settings:GetConVarName("NodeFont"), "Node Font")
		CreateDivider()
		CreateConvarIconEntry(Settings:GetConVarName("IconFolderEmpty"), "Node Empty Folder Icon")
		CreateConvarIconEntry(Settings:GetConVarName("IconFolderContains"), "Node Folder Icon")
		CreateConvarIconEntry(Settings:GetConVarName("IconFile"), "Node File Icon")
		CreateDivider()
		CreateConvarSlider(Settings:GetConVarName("ExpanderSize"), "Node Expander Size (pixels)", 0, 256)
		CreateConvarSlider(Settings:GetConVarName("IconSize"), "Node Icon Size (pixels)", 0, 256)
		CreateConvarSlider(Settings:GetConVarName("LeftmostToExpanderPadding"), "Left -> Expander Padding (pixels)", 0, 256)
		CreateConvarSlider(Settings:GetConVarName("ExpanderToIconPadding"), "Expander -> Icon Padding (pixels)", 0, 256)
		CreateConvarSlider(Settings:GetConVarName("IconToTextPadding"), "Icon -> Text Padding (pixels)", 0, 256)
		CreateDivider()
		CreateConvarSlider(Settings:GetConVarName("TileIconSize"), "Tile Icon Size (pixels)", 8, 128)
	end

	FileBrowser.PanelTable = vgui.RegisterTable(PANEL, "Panel")

	function FileBrowser.Create(Settings, Parent)
		local Panel = vgui.CreateFromTable(FileBrowser.PanelTable, Parent)
		Panel:Setup(Settings)
		return Panel
	end
end
